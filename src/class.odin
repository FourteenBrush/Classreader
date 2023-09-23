package main

import "core:fmt"
import "core:reflect"
import "core:intrinsics"

ClassFile :: struct {
    minor_version: u16,
    major_version: u16,
    constant_pool_count: u16,
    // The constant pool reserves the first entry as absent, we don't
    // So any accesses of the constant pool should offset the index by -1
    constant_pool: []ConstantPoolInfo,
    access_flags: u16,
    this_class: u16,
    super_class: u16,
    interfaces_count: u16,
    interfaces: []u16,
    fields_count: u16,
    fields: []FieldInfo,
    methods_count: u16,
    methods: []MethodInfo,
    attributes_count: u16,
    attributes: []AttributeInfo,
}

classfile_init :: proc(
    classfile: ^ClassFile,
    minor_version, major_version: u16,
    constant_pool_count: u16,
    access_flags: u16,
    this_class, super_class: u16,
    interfaces_count: u16,
    fields_count: u16,
    methods_count: u16,
    attributes_count: u16,
) {
    classfile.minor_version  = minor_version
    classfile.major_version = major_version
    classfile.constant_pool_count = constant_pool_count
    // class file mentions the amount of cp entries + 1 for the absent one
    classfile.constant_pool = make([]ConstantPoolInfo, constant_pool_count)
    classfile.access_flags = access_flags
    classfile.this_class = this_class
    classfile.super_class = super_class
    classfile.interfaces_count = interfaces_count
    classfile.interfaces = make([]u16, interfaces_count)
    classfile.fields_count = fields_count
    classfile.fields = make([]FieldInfo, fields_count)
    classfile.methods_count = methods_count
    classfile.methods = make([]MethodInfo, methods_count)
    classfile.attributes_count = attributes_count
    classfile.attributes = make([]AttributeInfo, attributes_count)
}

classfile_destroy :: proc(using classfile: ^ClassFile) {
    delete(constant_pool)
    delete(interfaces)
    delete(fields)
    delete(methods)
    delete(attributes)
}

classfile_dump :: proc(using classfile: ^ClassFile) {
    class_name_bytes := constant_pool[this_class].info.(ConstantUtf8Info).bytes
    class_name := string(class_name_bytes)
    fmt.printf("class name: %v\n", class_name)

    fmt.printf("minor version: %v\n", minor_version)
    fmt.printf("major version: %v\n", major_version)
    fmt.printf("access flags: 0x%x (", access_flags)
    dump_access_flags(access_flags)
    fmt.println(')')

    max_idx_width := count_digits(constant_pool_count)
    fmt.println("Constant pool:")

    for i in 0..<constant_pool_count - 1 {
        MIN_PADDING :: 2 // minimum amount of spaces in front of #num

        using entry := &constant_pool[i]
        padding := MIN_PADDING + max_idx_width - count_digits(i + 1) + 1
        fmt.printf("%*s%i = %s       ", padding, "#", i + 1, tag)
        cp_entry_dump(classfile, entry)
    }
}

@private
dump_access_flags :: proc(flags: u16) { 
    if flags & u16(ClassAccessFlag.AccPublic) != 0 {
        fmt.print("ACC_PUBLIC")
    }
    // TODO
}

cp_entry_dump :: proc(using classfile: ^ClassFile, cp_info: ^ConstantPoolInfo) {
    switch &cp_info in cp_info.info {
        case ConstantUtf8Info:
            fmt.println(string(cp_info.bytes))
        case ConstantIntegerInfo:
            // TODO: interpret correctly as float or int
            fmt.printf("%i (unable to interpret as int or float)\n", cp_info.bytes)
        case ConstantDoubleInfo:
            double_val := (cp_info.high_bytes << 32) | cp_info.low_bytes
            fmt.println(double_val)
        case ConstantClassInfo:
            class_name := cp_get_string(classfile, cp_info.name_index)
            fmt.println(class_name)
        case ConstantStringInfo:
            str := cp_get_string(classfile, cp_info.string_index)
            fmt.println(str)
        case ConstantFieldRefInfo:
            dump_field_ref(classfile, cp_info)
        case ConstantNameAndTypeInfo:
            name := cp_get_string(classfile, cp_info.name_index)
            descriptor := cp_get_string(classfile, cp_info.descriptor_index)
            fmt.printf("%s:%s\n", name, descriptor)
        case ConstantMethodHandleInfo:
            switch cp_info.reference_kind {
                case .GetField, .GetStatic, .PutField, .PutStatic:
                    field_ref := cp_get(ConstantFieldRefInfo, classfile, cp_info.reference_index)
                    dump_field_ref(classfile, field_ref) 
                case .InvokeVirtual, .InvokeStatic, .InvokeSpecial, .NewInvokeSpecial:
                    method_ref := cp_get(ConstantMethodRefInfo, classfile, cp_info.reference_index)
                    dump_field_ref(classfile, method_ref)
                case .InvokeInterface:
                    interface_method_ref := cp_get(ConstantInterfaceMethodRefInfo, classfile, cp_info.reference_index)
                    dump_field_ref(classfile, interface_method_ref)
            }
        case ConstantMethodTypeInfo:
            descriptor := cp_get_string(classfile, cp_info.descriptor_index)
            fmt.println(descriptor)
    }
}

// TODO: rename, method_ref is an alias for field_ref
@private
dump_field_ref :: proc(using classfile: ^ClassFile, using field_ref: ConstantFieldRefInfo) {
    class_name_idx := cp_get(ConstantClassInfo, classfile, class_index).name_index
    class_name := cp_get_string(classfile, class_name_idx) // error

    name_and_type := cp_get(ConstantNameAndTypeInfo, classfile, name_and_type_index)
    field_or_method_name := cp_get_string(classfile, name_and_type.name_index)
    fmt.printf("%s.%s\n", class_name, field_or_method_name)
}

@private
count_digits :: proc(x: u16) -> u8 {
    if x == 0 do return 1

    x := x
    count := byte(0)

    for x != 0 {
        x /= 10
        count += 1
    }
    return count
}

@private
cp_get_string :: proc(using classfile: ^ClassFile, idx: u16) -> string {
    return string(constant_pool[idx - 1].info.(ConstantUtf8Info).bytes)
}

cp_get :: proc($T: typeid, using classfile: ^ClassFile, idx: u16) -> T
where intrinsics.type_is_variant_of(CPInfo, T) {
     val, ok := constant_pool[idx - 1].info.(T)
     //fmt.assertf(ok, "mismatched cp_entry type: expected %T, got %T\n", typeid_of(T), typeid_of(type_of(val)))
     return val
}

ClassAccessFlag :: enum u16 {
    AccPublic = 0x0001,
    AccFinal = 0x0010,
    AccSuper = 0x0020,
    AccInterface = 0x0200,
    AccAbstract = 0x0400,
    AccSynthetic = 0x1000,
    AccAnnotation = 0x2000,
    AccEnum = 0x4000,
}

FieldInfo :: struct {
    access_flags: u16,
    name_index: u16,
    descriptor_index: u16,
    attributes_count: u16,
    attributes: []AttributeInfo,
}

FieldAccessFlag :: enum u16 {
    Public = 0x0001,
    Private = 0x0002,
    Protected = 0x0004,
    Static = 0x0008,
    Final = 0x0010,
    Volatile = 0x0040,
    Transient = 0x0080,
    Synthetic = 0x1000,
    Enum = 0x4000,
}

MethodInfo :: struct {
    access_flags: u16,
    name_index: u16,
    descriptor_index: u16,
    attributes_count: u16,
    attributes: []AttributeInfo,
}

MethodAccessFlag :: enum u16 {
    Public = 0x0001,
    Private = 0x0002,
    Protected = 0x0004,
    Static = 0x0008,
    Final = 0x0010,
    Synchronized = 0x0020,
    Bridge = 0x0040,
    Varargs = 0x0080,
    Native = 0x0100,
    Abstract = 0x0400,
    Strict = 0x0800,
    Synthetic = 0x1000,
}

// Used by a ClassFile, FieldInfo, MethodInfo, and CodeAttribute
AttributeInfo :: struct {
    attribute_name_index: u16,
    attribute_length: u16,
    info: []u8,
}
