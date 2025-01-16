package reader

import "core:fmt"
import "core:strings"
import "base:intrinsics"

// A code representation of a compiled Java class or interface.
// To obtain an instance, call reader.read_classfile().
ClassFile :: struct {
    minor_version: u16,
    major_version: u16,
    // Amount of actual entries.
    constant_pool_count: u16,
    // The constant pool reserves the first entry as absent, we don't.
    // So any accesses of the constant pool should offset the index by -1.
    // Indices valid from 0 to constant_pool_count - 2.
    // Interaction with the constant pool should happen with the appropriate cp_get() procedure.
    constant_pool: []ConstantPoolEntry,
    // Denotes access permissions to and properties of this class or interface.
    access_flags: ClassAccessFlags,
    // Points to a ConstantClassInfo entry, representing this class.
    this_class: Ptr(ConstantClassInfo),
    // Points to zero if there are no superclasses (only java.lang.Object)
    // or points to a ConstantClassInfo, representing the super class.
    super_class: Ptr(ConstantClassInfo),
    // List of indices, pointing to ConstantClassInfo entries,
    // representing direct superinterfaces.
    interfaces: []Ptr(ConstantClassInfo),
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
    // - Runtime(In)VisibleAnnotations
    // - Runtime(In)VisibleTypeAnnotations
    // - BootstrapMethods
    // - Module
    // - ModulePackages
    // - ModuleMainClass
    // - NestHost
    // - NestMembers
    // - Record
    // - PermittedSubclasses
    attributes: []AttributeInfo,
}

// ClassFile destructor.
classfile_destroy :: proc(classfile: ClassFile, allocator := context.allocator) {
    context.allocator = allocator
    for field in classfile.fields do attributes_destroy(field.attributes)
    for method in classfile.methods do attributes_destroy(method.attributes)
    attributes_destroy(classfile.attributes) 

    delete(classfile.constant_pool)
    delete(classfile.fields)
    delete(classfile.methods)
}

// Returns the name of the given class, as how it is found in the constantpool.
classfile_get_class_name :: proc(classfile: ClassFile) -> string {
    class := cp_get(classfile, classfile.this_class)
    return cp_get_str(classfile, class.name_idx)
}

// Returns the name of the super class, or "java/lang/Object" 
// if there was no explicit superclass.
classfile_get_super_class_name :: proc(classfile: ClassFile) -> string {
    if classfile.super_class.idx == 0 do return "java/lang/Object"
    class := cp_get(classfile, classfile.super_class)
    return cp_get_str(classfile, class.name_idx)
}

// Attempts to find a FieldInfo with the given field name.
classfile_find_field :: proc(classfile: ClassFile, name: string) -> Maybe(FieldInfo) {
    for field in classfile.fields {
        field_name := cp_get_str(classfile, field.name_idx)
        if field_name == name do return field
    }
    return nil
}

// Attempts to find a MethodInfo with the given method name.
classfile_find_method :: proc(classfile: ClassFile, name: string) -> Maybe(MethodInfo) {
    for method in classfile.methods {
        method_name := cp_get_str(classfile, method.name_idx)
        if method_name == name do return method
    } 
    return nil
}

// TODO: also apply on other attribute containers
// Finds the first occurence of the given attribute type.
classfile_find_attribute :: proc(classfile: ClassFile, $T: typeid) -> Maybe(T)
where intrinsics.type_is_variant_of(AttributeInfo, T) {
    for attribute in classfile.attributes {
        return attribute.(T) or_continue
    }
    return nil
}

find_attribute :: proc(container: $C, $T: typeid) -> Maybe(T)
where intrinsics.type_is_variant_of(AttributeInfo, T) {
    for attribute in container.attributes {
        if type_of(attribute) == T do return attribute
    }
    return nil
}

cp_find :: proc(
    classfile: ClassFile,
    $E: typeid,
    predicate: proc(ClassFile, E) -> bool,
) -> Maybe(E) where intrinsics.type_is_variant_of(CPInfo, E) {
    for entry in classfile.constant_pool {
        entry := entry.info.(E) or_continue
        if predicate(classfile, entry) {
            return entry
        }
    }
    return nil
}

// Returns a string stored within the constantpool.
// Panics if the entry at that index is not a ConstantUtf8Info.
cp_get_str :: proc(classfile: ClassFile, ptr: Ptr(ConstantUtf8Info), loc := #caller_location) -> string {
    return string(cp_get(classfile, ptr, loc).bytes)
}

// Returns the constantpool entry stored at the given index.
// Panics if idx is invalid or the expected and actual type differ.
cp_get :: proc(classfile: ClassFile, ptr: Ptr($E), loc := #caller_location) -> E
where intrinsics.type_is_variant_of(CPInfo, E) {
    return classfile.constant_pool[ptr.idx - 1].info.(E)
}

// An alternative to cp_get(), with safe semantics.
// TODO: never gets used
cp_get_safe :: proc(classfile: ClassFile, ptr: Ptr($E)) -> (E, Error)
where intrinsics.type_is_variant_of(CPInfo, E) {
    if ptr.idx == 1 || ptr.idx > classfile.constant_pool_count + 1 {
        return {}, .InvalidCPIndex
    }
    #no_bounds_check entry, ok := classfile.constant_pool[ptr.idx - 1].info.(E)
    if !ok do return entry, .WrongCPType
    return entry, .None
}

// TODO: take in configuration options, e.g. verbosity
// Dumps a ClassFile to the stdout.
classfile_dump :: proc(classfile: ClassFile) {
    fmt.println("Class name:", classfile_get_class_name(classfile))

    version_str := major_version_to_str(classfile.major_version)
    fmt.printfln(
        "Version: minor=%v, major=%v (%v)",
        classfile.minor_version, classfile.major_version, version_str,
    )
    fmt.printf("Access flags: 0x%4x ", classfile.access_flags)
    access_flags_dump(classfile.access_flags)
    // TODO: always prints 0?
    fmt.printfln(
        "Interfaces: %d, fields: %d, methods: %d, attributes: %d\n",
        len(classfile.interfaces), len(classfile.fields), len(classfile.methods), len(classfile.attributes),
    )

    if len(classfile.fields) > 0 {
        for field in classfile.fields {
            field_info_dump(field, classfile)
        }
        fmt.println()
    }

    constantpool_dump(classfile)

    if len(classfile.attributes) > 0 {
        fmt.println("Attributes:")
        for attrib in classfile.attributes {
            fmt.println(" ", attribute_to_str(attrib))
        }
    }
}

constantpool_dump :: proc(classfile: ClassFile) {
    max_idx_width := count_digits(classfile.constant_pool_count)
    fmt.println("Constant pool:")

    i := u16(1) 
    for entry in classfile.constant_pool {
        defer i += 1
        if entry.info == nil do continue // skip unusable entry

        min_lpadding :: 2 // minimum amount of spaces in front of #num
        padding := min_lpadding + max_idx_width - count_digits(i) + 1

        longest_tag_len :: len("InterfaceMethodRef") // FIXME: don't hardcode
        description_padding :: longest_tag_len + 1

        fmt.printf("%*[0]s%d = %-*[4]s", padding, "#", i, entry.tag, description_padding)
        cp_entry_dump(classfile, entry)
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
    case: panic("TODO: support java 21+ class file versions")
    }
}

// Dumps a certain AccessFlags type.
@(private)
access_flags_dump :: proc(flags: $E/bit_set[$F; u16]) 
    where E == ClassAccessFlags || E == FieldAccessFlags || E == MethodAccessFlags {
    first := true

    for flag in flags {
        str := access_flag_to_str(flag)

        if first {
            fmt.print('(', str, sep="")
            first = false
        } else {
            fmt.print(',', str)
        }
    }
    fmt.println(')')
}

FLOAT_NEG_INFINITY :: 0xff800000
FLOAT_POS_INFINITY :: 0x7f800000

// Dumps a constantpool entry's data to the stdout.
cp_entry_dump :: proc(classfile: ClassFile, cp_info: ConstantPoolEntry) {
    switch cp_info in cp_info.info {
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
        ref := cp_get(classfile, cp_info.reference_idx)
        ref_dump(classfile, ref)
    case ConstantMethodTypeInfo:
        descriptor := cp_get_str(classfile, cp_info.descriptor_idx)
        fmt.println(descriptor)
    case ConstantDynamicInfo:
        name_and_type := cp_get(classfile, cp_info.name_and_type_idx)
        method_name := cp_get_str(classfile, name_and_type.name_idx)
        method_descriptor := cp_get_str(classfile, name_and_type.descriptor_idx)
        fmt.printfln(
            "#%v:%v:%v", 
            cp_info.bootstrap_method_attr_idx, method_name, method_descriptor,
        )
    case ConstantInvokeDynamicInfo:
        name_and_type := cp_get(classfile, cp_info.name_and_type_idx)
        method_name := cp_get_str(classfile, name_and_type.name_idx)
        method_descriptor := cp_get_str(classfile, name_and_type.descriptor_idx)
        fmt.printfln(
            "#%v:%v:%v", 
            cp_info.bootstrap_method_attr_idx, method_name, method_descriptor,
        )
    case ConstantModuleInfo:
        module_name := cp_get_str(classfile, cp_info.name_idx)
        fmt.println(module_name)
    case ConstantPackageInfo: 
        package_name := cp_get_str(classfile, cp_info.name_idx)
        fmt.println(package_name)
    }
}

@(private)
ref_dump :: proc(classfile: ClassFile, field_ref: ConstantFieldRefInfo) {
    class_name_idx := cp_get(classfile, field_ref.class_idx).name_idx
    class_name := cp_get_str(classfile, class_name_idx)
    name_and_type := cp_get(classfile, field_ref.name_and_type_idx)
    field_or_method_name := cp_get_str(classfile, name_and_type.name_idx)
    
    fmt.println(class_name, field_or_method_name, sep=".")
}

@(private)
count_digits :: proc(x: u16) -> (count: u8) {
    if x == 0 do return 1

    x := x

    for x != 0 {
        x /= 10
        count += 1
    }
    return count
}

@(private)
LOG2 :: intrinsics.constant_log2

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
    Module     = 0x8000,
}

ClassAccessFlags :: bit_set[ClassAccessFlagBit; u16]

// Log 2's of ClassAccessFlag, for use within a bit_set.
ClassAccessFlagBit :: enum u16 {
    Public     = LOG2(ClassAccessFlag.Public),
    Final      = LOG2(ClassAccessFlag.Final),
    Super      = LOG2(ClassAccessFlag.Super),
    Interface  = LOG2(ClassAccessFlag.Interface),
    Abstract   = LOG2(ClassAccessFlag.Abstract),
    Synthetic  = LOG2(ClassAccessFlag.Synthetic),
    Annotation = LOG2(ClassAccessFlag.Annotation),
    Enum       = LOG2(ClassAccessFlag.Enum),
    Module     = LOG2(ClassAccessFlag.Module),
}

// Returns the uppercase representation of the respective flag passed.
access_flag_to_str :: proc(flag: $F) -> string {
    when F == ClassAccessFlagBit  do return class_access_flag_to_str[flag]; else
    when F == FieldAccessFlagBit  do return field_access_flag_to_str[flag]; else
    when F == MethodAccessFlagBit do return method_access_flag_to_str[flag]
    else do #panic("invalid type passed to " + #procedure)
}

@(private, rodata)
class_access_flag_to_str := #sparse[ClassAccessFlagBit]string {
    .Public     = "ACC_PUBLIC",
    .Final      = "ACC_FINAL",
    .Super      = "ACC_SUPER",
    .Interface  = "ACC_INTERFACE",
    .Abstract   = "ACC_ABSTRACT",
    .Synthetic  = "ACC_SYNTHETIC",
    .Annotation = "ACC_ANNOTATION",
    .Enum       = "ACC_ENUM",
    .Module     = "ACC_MODULE",
}

@(private, rodata)
field_access_flag_to_str := #sparse[FieldAccessFlagBit]string {
    .Public    = "ACC_PUBLIC",
    .Private   = "ACC_PRIVATE",
    .Protected = "ACC_PROTECTED",
    .Static    = "ACC_STATIC",
    .Final     = "ACC_FINAL",
    .Volatile  = "ACC_VOLATILE",
    .Transient = "ACC_TRANSIENT",
    .Synthetic = "ACC_SYNTHETIC",
    .Enum      = "ACC_ENUM",
}

@(private, rodata)
method_access_flag_to_str := #sparse[MethodAccessFlagBit]string {
    .Public       = "ACC_PUBLIC",
    .Private      = "ACC_PRIVATE",
    .Protected    = "ACC_PROTECTED",
    .Static       = "ACC_STATIC",
    .Final        = "ACC_FINAL",
    .Synchronized = "ACC_SYNCHRONIZED",
    .Bridge       = "ACC_BRIDGE",
    .Varargs      = "ACC_VARARGS",
    .Native       = "ACC_NATIVE",
    .Abstract     = "ACC_ABSTRACT",
    .Strict       = "ACC_STRICT",
    .Synthetic    = "ACC_SYNTHETIC",
}

// A class field representation.
FieldInfo :: struct {
    // Denotes access permissions to and properties of this field.
    access_flags: FieldAccessFlags,
    // Points to a ConstantUtf8Info representing the unqualified field name.
    name_idx: Ptr(ConstantUtf8Info),
    // Points to a ConstantUtf8Info representing a field descriptor.
    descriptor_idx: Ptr(ConstantUtf8Info),
    // Valid attributes for a field are:
    // - ConstantValue
    // - Synthetic
    // - Signature
    // - Deprecated
    // - Runtime(In)VisibleAnnotations
    // - Runtime(In)VisibleTypeAnnotations
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
    Public    = LOG2(FieldAccessFlag.Public),
    Private   = LOG2(FieldAccessFlag.Private),
    Protected = LOG2(FieldAccessFlag.Protected),
    Static    = LOG2(FieldAccessFlag.Static),
    Final     = LOG2(FieldAccessFlag.Final),
    Volatile  = LOG2(FieldAccessFlag.Volatile),
    Transient = LOG2(FieldAccessFlag.Transient),
    Synthetic = LOG2(FieldAccessFlag.Synthetic),
    Enum      = LOG2(FieldAccessFlag.Enum),
}

field_info_dump :: proc(field: FieldInfo, classfile: ClassFile) {
    if .Private in field.access_flags do fmt.print("private ")
    else if .Protected in field.access_flags do fmt.print("protected ")
    else if .Public in field.access_flags do fmt.print("public ")

    if .Static in field.access_flags do fmt.print("static ")
    if .Final in field.access_flags do fmt.print("final ")

    descriptor := cp_get_str(classfile, field.descriptor_idx)
    name := cp_get_str(classfile, field.name_idx)

    fmt.print(field_descriptor_to_str(descriptor, context.temp_allocator), name)
    fmt.println(";\n  descriptor:", descriptor)
    fmt.printf("  flags: (0x%4x) ", field.access_flags)
    access_flags_dump(field.access_flags)
}

// Returns a human readable version of a field descriptor.
// Assumes a valid field descriptor has been passed.
// Examples:
//  B -> byte
//  Ljava/lang/Thread; -> java.lang.Thread
field_descriptor_to_str :: proc(desc: string, allocator := context.allocator) -> string {
    switch desc {
    case "B": return "byte"
    case "Z": return "boolean"
    case "C": return "char"
    case "S": return "short"
    case "I": return "int"
    case "F": return "float"
    case "D": return "double"
    case "J": return "long"
    case:
        switch desc[0] {
        case '[':
            // array, determine depth
            depth := 1
            for desc[depth] == '[' do depth += 1
            base_type := field_descriptor_to_str(desc[depth:])
            arr := strings.repeat("[]", depth, allocator)
            return fmt.tprint(base_type, arr, sep="")
        case 'L':
            return descriptor_get_object_type(desc, allocator)
        }
    }
    unreachable()
}

// Returns the object type of an object descriptor, as how it would
// appear in the source code, e.g. java.awt.AWTEventMulticaster instead of
// Ljava/awt/AWTEventMulticaster;.
descriptor_get_object_type :: proc(desc: string, allocator := context.allocator) -> string {
    // remove L and ; and replace all / with .
    #no_bounds_check desc := desc[1:len(desc) - 1]
    object_type, _ := strings.replace_all(desc, "/", ".", allocator)
    return object_type
}

// A method representation, includes constructors and static initializers.
MethodInfo :: struct {
    // Denotes access permissions to and properties of this method.
    access_flags: MethodAccessFlags,
    // Points to a ConstantUtf8Info, representing either the unqualified method name
    // or one of the special method names <init> or <clinit>.
    name_idx: Ptr(ConstantUtf8Info),
    // Points to a ConstantUtf8Info, representing a method descriptor.
    descriptor_idx: Ptr(ConstantUtf8Info),
    // Valid attributes for a method are:
    // - Code
    // - Exceptions
    // - Synthetic
    // - Signature
    // - Deprecated
    // - Runtime(In)VisibleAnnotations
    // - Runtime(In)VisibleTypeAnnotations
    // - Runtime(In)VisibleParameterAnnotations
    // - AnnotationDefault
    // - MethodParameters
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
    Public       = LOG2(MethodAccessFlag.Public),
    Private      = LOG2(MethodAccessFlag.Private),
    Protected    = LOG2(MethodAccessFlag.Protected),
    Static       = LOG2(MethodAccessFlag.Static),
    Final        = LOG2(MethodAccessFlag.Final),
    Synchronized = LOG2(MethodAccessFlag.Synchronized),
    Bridge       = LOG2(MethodAccessFlag.Bridge),
    Varargs      = LOG2(MethodAccessFlag.Varargs),
    Native       = LOG2(MethodAccessFlag.Native),
    Abstract     = LOG2(MethodAccessFlag.Abstract),
    Strict       = LOG2(MethodAccessFlag.Strict),
    Synthetic    = LOG2(MethodAccessFlag.Synthetic),
}

method_info_dump :: proc(using method: MethodInfo, classfile: ClassFile) {
    if .Private in access_flags do fmt.print("private ")
    else if .Protected in access_flags do fmt.print("protected ")
    else if .Public in access_flags do fmt.println("public ")

    if .Static in access_flags do fmt.print("static ")
    if .Final in access_flags do fmt.print("final ")

    descriptor := cp_get_str(classfile, descriptor_idx)
    name := cp_get_str(classfile, name_idx)

    // TODO: proper printing
    fmt.print(field_descriptor_to_str(descriptor, context.temp_allocator), name)
}
