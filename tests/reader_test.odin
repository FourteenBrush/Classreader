package test

import cr "../src/reader"
import "core:os"
import "core:testing"

@(test)
test_reading2 :: proc(t: ^testing.T) {
    using cr
    contents := os.read_entire_file("tests/res/Test.class") or_else panic("file not found")
    defer delete(contents)

    reader := reader_new(contents)
    classfile, err := read_classfile(&reader)
    defer classfile_destroy(classfile)
    testing.expect_value(t, err, Error.None)

    // this class
    this_class := cp_get(classfile, classfile.this_class)
    class_name := cp_get_str(classfile, this_class.name_idx)
    testing.expect_value(t, class_name, "Test")
    testing.expect_value(t, classfile.access_flags, ClassAccessFlags{.Public, .Super})

    // super class
    super_class := cp_get(classfile, classfile.super_class)
    testing.expect_value(t, classfile_get_super_class_name(classfile), "java/lang/Object")

    // find constructor reference Object.<init>
    init := classfile_find_method(classfile, "<init>")
    testing.expect(t, init != nil, "no Object.<init> MethodInfo found")
    // TODO: validate Object.<init> once

    // if we get a SourceFile attribute, ensure it has the correct class name
    if source_file, present := classfile_find_attribute(classfile, SourceFile).?; present {
        class_name = cp_get_str(classfile, source_file.sourcefile_idx) 
        testing.expect_value(t, class_name, "Test.java")
    }

    // fields
    test_field(t, classfile, "i", "I", "Test", {.Final})
}

/*
@(test)
test_reading1 :: proc(t: ^testing.T) {
	content, ok := os.read_entire_file("tests/res/Test.class")
	defer delete(content)
	if !ok {testing.fail(t);return}

	reader := cr.reader_new(content)
	classfile, err := cr.read_classfile(&reader)
	defer cr.classfile_destroy(classfile)
	if err != .None {testing.error(t, err);testing.fail(t);return}

	cr.classfile_dump(classfile)

	// class and super class name
	testing.expect(t, cr.classfile_get_class_name(classfile) == "Test")
	testing.expect_value(t, classfile.access_flags, cr.ClassAccessFlags{.Public, .Super})
	testing.expect_value(t, cr.classfile_get_super_class_name(classfile), "java/lang/Object")

	// constantpool references to classes
	this_class, err1 := cr.cp_get_safe(cr.ConstantClassInfo, classfile, classfile.this_class)
	testing.expect_value(t, err1, cr.Error.None)

	utf8, err2 := cr.cp_get_safe(cr.ConstantUtf8Info, classfile, this_class.name_idx)
	testing.expect_value(t, err2, cr.Error.None)
	desc := string(utf8.bytes)
	testing.expect_value(t, desc, "Test")

	// if we get a SourceFile attribute, ensure it has the "Test" value
	source_file := cr.classfile_find_attribute(classfile, cr.SourceFile)
	if source_file != nil {
		filename := cr.cp_get_str(classfile, source_file.?.sourcefile_idx)
		testing.expect_value(t, filename, "Test.java")
	}

	// constructors
	// MethodRef java/lang/Object.<init>
	test_method(t, classfile, "<init>", "(Ljava/lang/String;)V", "java/lang/Object")

	test_field(t, classfile, "i", "I", "Test")
	test_field(t, classfile, "s", "Ljava/lang/String;", "Test")

	// s has a default value of 2
	constant_value := cr.cp_find(
		classfile,
		cr.ConstantIntegerInfo,
		proc(classfile: cr.ClassFile, val: cr.ConstantIntegerInfo) -> bool {
			return val.bytes == 2
		},
	)
}
*/

// Workaround for non capturing closures
@(private)
TestArgs :: struct {
	name, descriptor, declaring_class: string,
}

@private
test_method_presence :: proc(
    t: ^testing.T,
    classfile: cr.ClassFile,
    name: string,
) {
    using cr
    // validate MethodInfo
    method, present := classfile_find_method(classfile, name).?
    testing.expectf(t, present, "no MethodInfo found for method %v", name)

    descriptor := cp_get_str(classfile, method.descriptor_idx)
}

// TODO: rewrite this

@(private)
test_method :: proc(
	t: ^testing.T,
	classfile: cr.ClassFile,
	name, descriptor, declaring_class: string,
) {
	method, found := cr.classfile_find_method(classfile, name).?
	testing.expectf(t, found, "no MethodInfo found for method %v", name)

	actual_descriptor := cr.cp_get_str(classfile, method.descriptor_idx)
	testing.expect_value(t, actual_descriptor, descriptor)

	context.user_ptr = &TestArgs{name, descriptor, declaring_class}

	// now validate the constant pool
	// NOTE: Methodref's only occur when method are actually REFERENCED
	// TODO
	/*
	cp_method := cr.cp_find(classfile, cr.ConstantMethodRefInfo, proc(classfile: cr.ClassFile, ref: cr.ConstantMethodRefInfo) -> bool {
		using args := cast(^TestArgs)context.user_ptr

		class := cr.cp_get(cr.ConstantClassInfo, classfile, ref.class_idx)
		classname := cr.cp_get_str(classfile, class.name_idx)
		if classname != declaring_class do return false

		name_and_type := cr.cp_get(cr.ConstantNameAndTypeInfo, classfile, ref.name_and_type_idx)
		methodname := cr.cp_get_str(classfile, name_and_type.name_idx)
		if methodname != name do return false

		actual_descriptor := cr.cp_get_str(classfile, name_and_type.descriptor_idx)
		if actual_descriptor != descriptor do return false

		return false
	})

	testing.expect(t, cp_method != nil, "expected to find a java/lang/Object.<init> methodref")
    */
}

// Validates the ClassFile concerning a certain field.
// IMPORTANT NOTE: to find ConstantFieldRefInfo entries, methods must actually be REFERENCED.
// The simplest way to do this is by creating a main method that calls those.
@(private)
test_field :: proc(
    t: ^testing.T,
    classfile: cr.ClassFile,
    expected_name, expected_descriptor, surrounding_class: string,
    access_flags: cr.FieldAccessFlags,
) {
    using cr
    field, present := classfile_find_field(classfile, expected_name).?
    testing.expectf(t, present, "no FieldInfo found for field %v", expected_name)

    name := cp_get_str(classfile, field.name_idx)
    testing.expect_value(t, expected_name, name)

    descriptor := cp_get_str(classfile, field.descriptor_idx)
    testing.expect_value(t, descriptor, expected_descriptor)

    expected_name := expected_name
    context.user_ptr = &expected_name

    field_ref, ref_present := cp_find(
        classfile, ConstantFieldRefInfo,
        proc(classfile: ClassFile, field: ConstantFieldRefInfo) -> bool {
            name_and_type := cp_get(classfile, field.name_and_type_idx)
            field_name := cp_get_str(classfile, name_and_type.name_idx)
            desired_name := (^string)(context.user_ptr)^
            if field_name != desired_name do return false

            return true
        },
    ).?
    testing.expectf(t, ref_present, "no ConstantFieldRefInfo found for field %v", expected_name)

    declaring_class := cp_get(classfile, field_ref.class_idx)
    class_name := cp_get_str(classfile, declaring_class.name_idx)
    testing.expect_value(t, class_name, surrounding_class)

    name_and_type := cp_get(classfile, field_ref.name_and_type_idx)
    name = cp_get_str(classfile, name_and_type.name_idx)
    descriptor = cp_get_str(classfile, name_and_type.descriptor_idx)

    // name and descriptor must be the same ones used in the FieldInfo
    testing.expect_value(t, name, expected_name)
    testing.expect_value(t, descriptor, expected_descriptor)
}
