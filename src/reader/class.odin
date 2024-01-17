package reader

import "core:fmt"
import "core:slice"
import "core:reflect"
import "core:intrinsics"

// A code representation of a compiled Java class or interface.
// To obtain an instance, call reader.read_classfile().
ClassFile :: struct {
    minor_version: u16,
    major_version: u16,
    constant_pool_count: u16,
    // The constant pool reserves the first entry as absent, we don't
    // So any accesses of the constant pool should offset the index by -1 (see cp_get())
    // Indices valid from 0 to constant_pool_count - 2
    // see cp_get()
    constant_pool: []ConstantPoolEntry,
    // Denotes access permissions to and properties of this class or interface.
    access_flags: ClassAccessFlags,
    // Points to a ConstantClassInfo entry, representing this class.
    this_class: u16,
    // Zero if there are no superclasses (use java.lang.Object instead)
    // or an index to a ConstantClassInfo entry, representing the super class.
    super_class: u16,
    // List of indices, pointing to ConstantClassInfo entries,
    // representing interfaces that are a direct superinterface.
    interfaces: []u16,
    fields: []FieldInfo,
    methods: []MethodInfo,
    // Valid attributes for a ClassFile are:
    // - InnerClasses
    // - EnclosingMethod
    // - Synthetic
    // - Signature
    // - SourceFile
    // - SourceDebugExtension
    // - Deprecated
    // - Runtime(In)VisibleAttributes
    // - BootstrapMethods
    attributes: []AttributeInfo,
}

// ClassFile destructor.
classfile_destroy :: proc(using classfile: ClassFile, allocator := context.allocator) {
    // recursively apply provided allocator
    context.allocator = allocator
    for &field in fields do attributes_destroy(field.attributes)
    for &method in methods do attributes_destroy(method.attributes)
    attributes_destroy(attributes) 

    delete(constant_pool)
    delete(fields)
    delete(methods)
}

// Returns the name of the given class, as how it is found in the constantpool.
classfile_get_class_name :: proc(using classfile: ClassFile) -> string {
    class := cp_get(ConstantClassInfo, classfile, this_class)
    return cp_get_str(classfile, class.name_idx)
}

// Returns the name of the super class, or "java/lang/Object" 
// if there was no explicit superclass.
classfile_get_super_class_name :: proc(using classfile: ClassFile) -> string {
    if super_class == 0 do return "java/lang/Object"
    class := cp_get(ConstantClassInfo, classfile, super_class)
    return cp_get_str(classfile, class.name_idx)
}

// Attempts to find a FieldInfo with the given field name.
classfile_find_field :: proc(using classfile: ClassFile, name: string) -> Maybe(FieldInfo) {
    for &field in fields {
        field_name := cp_get_str(classfile, field.name_idx)
        if field_name == name do return field
    }
    return nil
}

// Attempts to find a MethodInfo with the given method name.
classfile_find_method :: proc(using classfile: ClassFile, name: string) -> Maybe(MethodInfo) {
    for &method in methods {
        method_name := cp_get_str(classfile, method.name_idx)
        desc := cp_get_str(classfile, method.descriptor_idx)
        fmt.println("encountered method", method_name, desc)
        if method_name == name do return method
    } 
    return nil
}

// TODO: also apply on other attribute containers
// Finds the first occurence of the given attribute type.
classfile_find_attribute :: proc(using classfile: ClassFile, $T: typeid) -> Maybe(T)
where intrinsics.type_is_variant_of(AttributeInfo, T) {
    idx, found := slice.linear_search_proc(attributes, proc(attrib: AttributeInfo) -> bool {
        return type_of(attrib) == T
    }) 
    return attributes[idx].(T) if found else nil
}

find_attribute :: proc(container: $C, $T: typeid) -> Maybe(T)
where intrinsics.type_is_variant_of(AttributeInfo, T) {
    // TODO
    return container.attributes[0]
}

cp_find :: proc(
    using classfile: ClassFile,
    $E: typeid,
    predicate: proc(ClassFile, E) -> bool,
) -> Maybe(E) where intrinsics.type_is_variant_of(CPInfo, E) {
    for &entry in constant_pool {
        entry, ok := entry.info.(E)
        if ok && predicate(classfile, entry) {
            return entry
        }
    }
    return nil
}

// Returns a string stored within the constantpool.
// Panics if the entry at that index is not a ConstantUtf8Info.
cp_get_str :: proc(using classfile: ClassFile, idx: u16) -> string {
    return string(cp_get(ConstantUtf8Info, classfile, idx).bytes)
}

// Returns the constantpool entry stored at the given index.
// Panics if the expected and actual type differ.
cp_get :: proc($T: typeid, using classfile: ClassFile, idx: u16) -> T
where intrinsics.type_is_variant_of(CPInfo, T) {
    return constant_pool[idx - 1].info.(T)
}

// An alternative to cp_get(), with safe semantics.
cp_get_safe :: proc($T: typeid, using classfile: ClassFile, idx: u16) -> (T, bool)
where intrinsics.type_is_variant_of(CPInfo, T) {
    return constant_pool[idx - 1].info.(T)
}

// Dumps a ClassFile to the stdout.
classfile_dump :: proc(using classfile: ClassFile) {
    fmt.println("Class name:", classfile_get_class_name(classfile))

    version_str := major_version_to_str(major_version)
    fmt.printf("Version: minor=%v, major=%v (%v)\n", minor_version, major_version, version_str)
    fmt.printf("Access flags: 0x%4x ", access_flags)
    class_access_flags_dump(access_flags)

    max_idx_width := count_digits(constant_pool_count)
    i := u16(1)
    fmt.println("Constant pool:")

    for entry in constant_pool {
        if entry.info == nil { i += 1; continue } // skip unusable entry

        MIN_PADDING :: 2 // minimum amount of spaces in front of #num
        // TODO: determine the max length of the tags first rather than hardcoding an arbitrary one
        MAX_TAG_LEN :: len("InterfaceMethodRef") // longest tag

        padding := MIN_PADDING + max_idx_width - count_digits(i) + 1
        tag_len := len(reflect.enum_string(entry.tag))
        description_padding := MAX_TAG_LEN - tag_len + 1

        fmt.printf("%*s%i = %s%*s", padding, "#", i, entry.tag, description_padding, "")
        cp_entry_dump(classfile, entry)
        i += 1
    }

    fmt.println("Attributes:")

    for attrib in attributes {
        name := attribute_to_str(attrib)
        fmt.println(" ", name)
    }
}

// Returns an understandable representation of the major version. E.g. 65 -> Java SE 21.
major_version_to_str :: proc(major: u16) -> string {
    // http://en.wikipedia.org/wiki/Java_class_file#General_layout
    switch major {
        case 65: return "Java SE 21"
        case 64: return "Java SE 20"
        case 63: return "Java SE 19"
        case 62: return "Java SE 18"
        case 61: return "Java SE 17"
        case 60: return "Java SE 16"
        case 59: return "Java SE 15"
        case 58: return "Java SE 14"
        case 57: return "Java SE 13"
        case 56: return "Java SE 12"
        case 55: return "Java SE 11"
        case 54: return "Java SE 10"
        case 53: return "Java SE 9"
        case 52: return "Java SE 8"
        case 51: return "Java SE 7"
        case 50: return "Java SE 6.0"
        case 49: return "Java SE 5.0"
        case 48: return "JDK 1.4"
        case 47: return "JDK 1.3"
        case 46: return "JDK 1.2"
        case 45: return "JDK 1.1"
        // FIXME: probably want to apply verification before this gets reached
        case: return "<unknown Version>"
    }
}

@private
class_access_flags_dump :: proc(flags: ClassAccessFlags) {
    first := true

    for flag in ClassAccessFlagBit {
        if flag not_in flags do continue
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

FLOAT_NEG_INFINITY :: 0xff800000
FLOAT_POS_INFINITY :: 0x7f800000

// Dumps a constantpool entry's data to the stdout.
cp_entry_dump :: proc(classfile: ClassFile, cp_info: ConstantPoolEntry) {
    switch &cp_info in cp_info.info {
        case ConstantUtf8Info:
            fmt.println(string(cp_info.bytes))
        case ConstantIntegerInfo:
            fmt.println(cp_info.bytes)
        case ConstantFloatInfo:
            switch cp_info.bytes {
                case FLOAT_POS_INFINITY: fmt.println("infinity")
                case FLOAT_NEG_INFINITY: fmt.println("-infinity")
                case 0x7f800001..=0x7fffffff,
                     0xff800001..=0xffffffff:
                    fmt.println("NaN")
                case:
                    val := transmute(f32)cp_info.bytes
                    fmt.println(val)
            }
        case ConstantLongInfo:
            long_val := i64(cp_info.high_bytes) << 32 + i64(cp_info.low_bytes)
            fmt.println(long_val)
        case ConstantDoubleInfo:
            int_val := u64(cp_info.high_bytes) << 32 + u64(cp_info.low_bytes)
            val := transmute(f64)int_val
            fmt.println(val)
        case ConstantClassInfo:
            class_name := cp_get_str(classfile, cp_info.name_idx)
            fmt.println(class_name)
        case ConstantStringInfo:
            str := cp_get_str(classfile, cp_info.string_idx)
            fmt.println(str)
        case ConstantFieldRefInfo:
            ref_dump(classfile, cp_info)
        case ConstantNameAndTypeInfo:
            name := cp_get_str(classfile, cp_info.name_idx)
            descriptor := cp_get_str(classfile, cp_info.descriptor_idx)
            fmt.println(name, descriptor, sep=":")
        case ConstantMethodHandleInfo:
            // note that ConstantFieldRefInfo has multiple aliases, see constantpool file
            ref := cp_get(ConstantFieldRefInfo, classfile, cp_info.reference_idx)
            ref_dump(classfile, ref)
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

@private
ref_dump :: proc(using classfile: ClassFile, using field_ref: ConstantFieldRefInfo) {
    class_name_idx := cp_get(ConstantClassInfo, classfile, class_idx).name_idx
    class_name := cp_get_str(classfile, class_name_idx)
    name_and_type := cp_get(ConstantNameAndTypeInfo, classfile, name_and_type_idx)
    field_or_method_name := cp_get_str(classfile, name_and_type.name_idx)
    
    fmt.println(class_name, field_or_method_name, sep=".")
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

// Access flags for a ClassFile structure.
ClassAccessFlag :: enum u16 {
    Public     = 0x0001,
    Final      = 0x0010,
    Super      = 0x0020,
    Interface  = 0x0200,
    Abstract   = 0x0400,
    Synthetic  = 0x1000,
    Annotation = 0x2000,
    Enum       = 0x4000,
}

ClassAccessFlags :: bit_set[ClassAccessFlagBit; u16]

// Log 2's of ClassAccessFlag, for use within a bit_set.
ClassAccessFlagBit :: enum u16 {
    Public     = 0,
    Final      = 4,
    Super      = 5,
    Interface  = 9,
    Abstract   = 10,
    Synthetic  = 12,
    Annotation = 13,
    Enum       = 14,
}

// Returns the uppercase string representation of a ClassAccessFlagBit.
access_flag_to_str :: proc(flag: ClassAccessFlagBit) -> string {
    switch (flag) {
        case .Public:     return "ACC_PUBLIC"
        case .Final:      return "ACC_FINAL"
        case .Super:      return "ACC_SUPER"
        case .Interface:  return "ACC_INTERFACE"
        case .Abstract:   return "ACC_ABSTRACT"
        case .Synthetic:  return "ACC_SYNTHETIC"
        case .Annotation: return "ACC_ANNOTATION"
        case .Enum:       return "ACC_ENUM"
        // in case someone would pass ClassessFlags(9999) or something
        case: panic("invalid args passed to access_flag_to_str")
    }
}

// A field descriptor.
FieldInfo :: struct {
    // Denotes access permissions to and properties of this field.
    access_flags: FieldAccessFlags,
    // Points to a ConstantUtf8Info representing the unqualified field name.
    name_idx: u16,
    // Points to a ConstantUtf8Info representing a field descriptor.
    descriptor_idx: u16,
    // Valid attributes for a field descriptor are:
    // - ConstantValue
    // - Synthetic
    // - Signature
    // - Deprecated
    // - Runtime(In)VisibleAnnotations
    attributes: []AttributeInfo,
}

// Access flags for a FieldInfo structure.
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

FieldAccessFlags :: bit_set[FieldAccessFlagBit; u16]

// Log 2's of FieldAccessFlag, for use within a bit_set.
FieldAccessFlagBit :: enum u16 {
    Public    = 0,
    Private   = 1,
    Protected = 2,
    Static    = 3,
    Final     = 4,
    Volatile  = 6,
    Transient = 7,
    Synthetic = 12,
    Enum      = 14,
}

// A method descriptor.
MethodInfo :: struct {
    // Denotes access permissions to and properties of this method.
    access_flags: MethodAccessFlags,
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
    // - Runtime(In)VisibleAnnotations
    // - Runtime(In)VisibleParameterAnnotations
    // - AnnotationDefault
    attributes: []AttributeInfo,
}

// Access flags for a MethodInfo structure.
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
    // Stricfp
    Strict       = 0x0800,
    Synthetic    = 0x1000,
}

MethodAccessFlags :: bit_set[MethodAccessFlagBit; u16]

// Log 2's of MethodAccessFlag, for use within a bit_set.
MethodAccessFlagBit :: enum u16 {
    Public       = 1,
    Private      = 2,
    Protected    = 3,
    Static       = 4,
    Final        = 5,
    Synchronized = 6,
    Bridge       = 7,
    Varargs      = 8,
    Native       = 9,
    Abstract     = 11,
    Strict       = 12,
    Synthetic    = 13,
}
