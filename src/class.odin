package classreader

import "core:fmt"
import "core:intrinsics"

// A code representation of a in-memory classfile.
// To obtain an instance, call reader_read_classfile().
ClassFile :: struct {
    minor_version: u16,
    major_version: u16,
    constant_pool_count: u16,
    // The constant pool reserves the first entry as absent, we don't
    // So any accesses of the constant pool should offset the index by -1
    // Indices valid from 0 to constant_pool_count - 2
    constant_pool: []ConstantPoolEntry,
    access_flags: u16,
    this_class: u16,
    super_class: u16,
    interfaces: []u16,
    fields: []FieldInfo,
    methods: []MethodInfo,
    attributes: []AttributeInfo,
}

// ClassFile destructor.
classfile_destroy :: proc(using classfile: ^ClassFile) {
    defer delete(constant_pool)
    defer delete(fields)
    defer delete(methods)

    for &field in fields do attributes_destroy(field.attributes)
    for &method in methods do attributes_destroy(method.attributes)

    attributes_destroy(attributes)
}

// Dumps a whole classfile structure to the stdout.
classfile_dump :: proc(using classfile: ClassFile) {
    class := cp_get(ConstantClassInfo, classfile, this_class)
    class_name := cp_get_str(classfile, class.name_idx)
    fmt.println("class name:", class_name)

    fmt.println("minor version:", minor_version)
    fmt.println("major version:", major_version)
    fmt.printf("access flags: 0x%x ", access_flags)
    dump_access_flags(access_flags)

    max_idx_width := count_digits(constant_pool_count)
    fmt.println("Constant pool:")

    for i := u16(0); i < constant_pool_count - 1; i += 1 {
        MIN_PADDING :: 2 // minimum amount of spaces in front of #num
        MAX_TAG_LEN :: len("InterfaceMethodRef") // longest tag

        using entry := constant_pool[i]
        padding := MIN_PADDING + max_idx_width - count_digits(i + 1) + 1
        tag_len := len(fmt.tprint(tag))
        // #9 = Utf8      some text 
        // TODO: determine the max length of the tags first rather than hardcoding an arbitrary one
        // also clean this up
        fmt.printf("%*s%i = %s%*s", padding, "#", i + 1, tag, MAX_TAG_LEN - tag_len + 1, "")
        cp_entry_dump(classfile, entry)
        if tag == .Long || tag == .Double {
            i += 1 // skip the unusable entry
        }
    }

    fmt.println("Attributes:")
    for &attrib in attributes {
        name := cp_get_str(classfile, attrib.name_idx)
        fmt.println(name)
    }
}

@private
dump_access_flags :: proc(flags: u16) {
    first := true

    for flag in ClassAccessFlag {
        if flags & u16(flag) == 0 do continue
        str := access_flag_to_str(flag)

        if first {
            fmt.print('(', str, sep="")
        } else {
            fmt.print(',', str)
        }
        first = false
    }
    fmt.println(')')
}

// Dumps a constantpool entry's data to the stdout.
cp_entry_dump :: proc(using classfile: ClassFile, cp_info: ConstantPoolEntry) {
    switch &cp_info in cp_info.info {
        case DummyInfo:
            // do nothing, not intended to be printed
        case ConstantUtf8Info:
            fmt.println(string(cp_info.bytes))
        case ConstantIntegerInfo:
            // TODO: interpret correctly as float or int
            fmt.printf("%i (unable to interpret as int or float)\n", cp_info.bytes)
        case ConstantDoubleInfo:
            val := u64(cp_info.high_bytes) << 32 + u64(cp_info.low_bytes)
            fmt.println(val)
        case ConstantClassInfo:
            class_name := cp_get_str(classfile, cp_info.name_idx)
            fmt.println(class_name)
        case ConstantStringInfo:
            str := cp_get_str(classfile, cp_info.string_idx)
            fmt.println(str)
        case ConstantFieldRefInfo:
            dump_field_ref(classfile, cp_info)
        case ConstantNameAndTypeInfo:
            name := cp_get_str(classfile, cp_info.name_idx)
            descriptor := cp_get_str(classfile, cp_info.descriptor_idx)
            fmt.println(name, descriptor, sep=":")
        case ConstantMethodHandleInfo:
            // TODO: these are all aliases, why bother specializing?
            // Just interpret the cp_info.tag
            switch cp_info.reference_kind {
                case .GetField, .GetStatic, .PutField, .PutStatic:
                    field_ref := cp_get(ConstantFieldRefInfo, classfile, cp_info.reference_idx)
                    dump_field_ref(classfile, field_ref) 
                case .InvokeVirtual, .InvokeStatic, .InvokeSpecial, .NewInvokeSpecial:
                    method_ref := cp_get(ConstantMethodRefInfo, classfile, cp_info.reference_idx)
                    dump_field_ref(classfile, method_ref)
                case .InvokeInterface:
                    interface_method_ref := cp_get(ConstantInterfaceMethodRefInfo, classfile, cp_info.reference_idx)
                    dump_field_ref(classfile, interface_method_ref)
            }
        case ConstantMethodTypeInfo:
            descriptor := cp_get_str(classfile, cp_info.descriptor_idx)
            fmt.println(descriptor)
        case ConstantInvokeDynamicInfo:
            using name_and_type := cp_get(ConstantNameAndTypeInfo, classfile, cp_info.name_and_type_idx)
            method_name := cp_get_str(classfile, name_idx)
            method_descriptor := cp_get_str(classfile, descriptor_idx)
            fmt.printf("#%v:%v:%v\n", cp_info.bootstrap_method_attr_idx, method_name, method_descriptor)
    }
}

// TODO: rename, method_ref is an alias for field_ref
@private
dump_field_ref :: proc(using classfile: ClassFile, using field_ref: ConstantFieldRefInfo) {
    class_name_idx := cp_get(ConstantClassInfo, classfile, class_idx).name_idx
    name_and_type := cp_get(ConstantNameAndTypeInfo, classfile, name_and_type_idx)
    field_or_method_name := cp_get_str(classfile, name_and_type.name_idx)
    class_name := cp_get_str(classfile, class_name_idx)
    
    fmt.printf("%s.%s\n", class_name, field_or_method_name)
}

@private
count_digits :: proc(x: u16) -> (count: u8) {
    if x == 0 do return 1

    x := x

    for x != 0 {
        x /= 10
        count += 1
    }
    return count
}

// Returns a string stored within the constantpool.
// Assuming that the entry at that index is a ConstantUtf8Info.
cp_get_str :: proc(using classfile: ClassFile, idx: u16) -> string {
    return string(cp_get(ConstantUtf8Info, classfile, idx).bytes)
}

// Returns the constantpool entry stored at the given index.
cp_get :: proc($T: typeid, using classfile: ClassFile, idx: u16) -> T
where intrinsics.type_is_variant_of(CPInfo, T) {
    return constant_pool[idx - 1].info.(T)
}

ClassAccessFlag :: enum u16 {
    AccPublic     = 0x0001,
    AccFinal      = 0x0010,
    AccSuper      = 0x0020,
    AccInterface  = 0x0200,
    AccAbstract   = 0x0400,
    AccSynthetic  = 0x1000,
    AccAnnotation = 0x2000,
    AccEnum       = 0x4000,
}

access_flag_to_str :: proc(flag: ClassAccessFlag) -> string {
    switch (flag) {
        case .AccPublic:     return "ACC_PUBLIC"
        case .AccFinal:      return "ACC_FINAL"
        case .AccSuper:      return "ACC_SUPER"
        case .AccInterface:  return "ACC_INTERFACE"
        case .AccAbstract:   return "ACC_ABSTRACT"
        case .AccSynthetic:  return "ACC_SYNTHETIC"
        case .AccAnnotation: return "ACC_ANNOTATION"
        case .AccEnum:       return "ACC_ENUM"
    }
    // in case someone would pass ClassAccessFlags(9999) or something
    panic("invalid args passed to access_flag_to_str")
}

// A method descriptor.
FieldInfo :: struct {
    // A mask of FieldAccessFlag flags, denoting
    // access permissions to and properties of this field.
    access_flags: u16,
    // Points to a ConstantUtf8Info representing the unqualified field name.
    name_idx: u16,
    // Points to a ConstantUtf8Info representing a field descriptor.
    descriptor_idx: u16,
    // Valid attributes for a field descriptor are:
    // - ConstantValue
    // - Synthetic
    // - Signature
    // - Deprecated
    // - RuntimeVisibleAnnotations
    // - RuntimeInvisibleAnnotations
    attributes: []AttributeInfo,
}

FieldAccessFlag :: enum u16 {
    Public    = 0x0001,
    Private   = 0x0002,
    Protected = 0x0004,
    Static    = 0x0008,
    Final     = 0x0010,
    Volatile  = 0x0040,
    Transient = 0x0080,
    Synthetic = 0x1000,
    Enum      = 0x4000,
}

// A method descriptor.
MethodInfo :: struct {
    // A mask of MethodAccessFlag flags, denoting
    // access permissions to and properties of this method.
    access_flags: u16,
    // Points to a ConstantUtf8Info, representing either the unqualified method name
    // or one of the special method names <init> or <clinit>.
    name_idx: u16,
    // Points to a ConstantUtf8Info, representing a method descriptor.
    descriptor_idx: u16,
    // Valid attributes for a method descriptor are:
    // - Code
    // - Exceptions
    // - Synthetic
    // - Signature
    // - Deprecated
    // - RuntimeVisibleAnnotations
    // - RuntimeInvisibleAnnotations
    // - RuntimeVisibleParameterAnnotations
    // - RuntimeInvisibleParameterAnnotations
    // - AnnotationDefault
    attributes: []AttributeInfo,
}

MethodAccessFlag :: enum u16 {
    Public       = 0x0001,
    Private      = 0x0002,
    Protected    = 0x0004,
    Static       = 0x0008,
    Final        = 0x0010,
    Synchronized = 0x0020,
    // A bridge method generated by the compiler.
    Bridge       = 0x0040,
    Varargs      = 0x0080,
    Native       = 0x0100,
    Abstract     = 0x0400,
    // stricfp
    Strict       = 0x0800,
    Synthetic    = 0x1000,
}
