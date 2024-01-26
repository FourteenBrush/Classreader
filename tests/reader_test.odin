package test

import cr "../src/reader"
import "core:c/libc"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:testing"

expectf :: proc(
	t: ^testing.T,
	ok: bool,
	format: string,
	args: ..any,
	loc := #caller_location,
) -> bool {
	if !ok {
		testing.errorf(t, format, args)
	}
	return ok
}

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
	this_class, ok1 := cr.cp_get_safe(cr.ConstantClassInfo, classfile, classfile.this_class)
	testing.expect(t, ok1)

	utf8, ok2 := cr.cp_get_safe(cr.ConstantUtf8Info, classfile, this_class.name_idx)
	testing.expect(t, ok2)
	desc := string(utf8.bytes)
	testing.expect_value(t, desc, "Test")

	// if we get a SourceFile attribute, ensure it has the "Test" value
	source_file := cr.classfile_find_attribute(classfile, cr.SourceFile)
	if source_file != nil {
		filename := cr.cp_get_str(classfile, source_file.?.sourcefile_idx)
		testing.expect_value(t, filename, "Test")
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

// Workaround for non capturing closures
@(private)
TestArgs :: struct {
	t: ^testing.T,
	name, descriptor, declaring_class: string,
}

// TODO: rewrite this

@(private)
test_method :: proc(
	t: ^testing.T,
	classfile: cr.ClassFile,
	name, descriptor, declaring_class: string,
) {
	method, found := cr.classfile_find_method(classfile, name).?
	expectf(t, found, "no MethodInfo found for method %v", name)

	actual_descriptor := cr.cp_get_str(classfile, method.descriptor_idx)
	testing.expect_value(t, actual_descriptor, descriptor)

	context.user_ptr = &TestArgs{t, name, descriptor, declaring_class}

	// now validate the constant pool
	// NOTE: Methodref's only occur when method are actually REFERENCED
	// TODO
	/*
    cp_method := cr.cp_find(
        classfile, cr.ConstantMethodRefInfo,
        proc(classfile: cr.ClassFile, ref: cr.ConstantMethodRefInfo) -> bool {
            using args := cast(^TestArgs) context.user_ptr

            class := cr.cp_get(cr.ConstantClassInfo, classfile, ref.class_idx)
            classname := cr.cp_get_str(classfile, class.name_idx)
            //if classname != declaring_class do return false

            name_and_type := cr.cp_get(cr.ConstantNameAndTypeInfo, classfile, ref.name_and_type_idx)
            methodname := cr.cp_get_str(classfile, name_and_type.name_idx)
            //if methodname != name do return false

            actual_descriptor := cr.cp_get_str(classfile, name_and_type.descriptor_idx)
            //if actual_descriptor != descriptor do return false

            fmt.println(classname, methodname, actual_descriptor)
            return false
        },
    )

    testing.expect(t, cp_method != nil, "expected to find a java/lang/Object.<init> methodref")
    */
}

@(private)
test_field :: proc(
	t: ^testing.T,
	classfile: cr.ClassFile,
	name, descriptor, declaring_class: string,
) {
	field, found := cr.classfile_find_field(classfile, name).?
	expectf(t, found, "no FieldInfo found for field %v", name)

	actual_descriptor := cr.cp_get_str(classfile, field.descriptor_idx)
	testing.expect_value(t, actual_descriptor, descriptor)

	context.user_ptr = &TestArgs{t, name, descriptor, declaring_class}

	// now validate the constant pool
	cp_field := cr.cp_find(
	classfile,
	cr.ConstantFieldRefInfo,
	proc(classfile: cr.ClassFile, ref: cr.ConstantFieldRefInfo) -> bool {
		using args := cast(^TestArgs)context.user_ptr

		// declaring class name
		class := cr.cp_get(cr.ConstantClassInfo, classfile, ref.class_idx)
		classname := cr.cp_get_str(classfile, class.name_idx)
		if classname != declaring_class do return false

		// field name
		name_and_type := cr.cp_get(cr.ConstantNameAndTypeInfo, classfile, ref.name_and_type_idx)
		fieldname := cr.cp_get_str(classfile, name_and_type.name_idx)
		if fieldname != name do return false

		// field descriptor
		actual_descriptor := cr.cp_get_str(classfile, name_and_type.descriptor_idx)
		if actual_descriptor != descriptor do return false
		return true
	},
	)

	testing.expect(t, cp_field != nil, "FieldInfo without corresponding ConstantFieldRef")
}
