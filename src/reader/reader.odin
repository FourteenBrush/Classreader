package reader

import "core:mem"
import "base:intrinsics"
import "core:encoding/endian"

MAGIC :: 0xCAFEBABE
MIN_MAJOR :: 45
MAX_MAJOR :: 65

ClassFileReader :: struct {
    bytes: []u8,
    pos: int,
}

// Creates a new ClassFileReader, reading the given bytes.
// These bytes must be deallocated by the caller.
reader_new :: proc(bytes: []u8) -> ClassFileReader {
    return ClassFileReader { bytes, 0 }
}

// Attempts to a read a classfile, returning the error if failed.
// IMPORTANT NOTE: the resulting ClassFile's lifetime is bound to the bytes 
// it got from the reader. This might become subject to change, 
// to only clone necessary byte slices instead.
// The returned classfile explicitly needs to be freed using classfile_destroy()
// even if an error was returned.
read_classfile :: proc(
    reader: ^ClassFileReader, 
    allocator := context.allocator,
) -> (
    classfile: ClassFile,
    err: Error,
) {
    magic := read_u32(reader) or_return
    if magic != MAGIC do return classfile, .InvalidHeader

    classfile.minor_version = read_u16(reader) or_return
    classfile.major_version = read_u16(reader) or_return
    if classfile.major_version < MIN_MAJOR || classfile.major_version > MAX_MAJOR {
        return classfile, .InvalidMajorVersion
    }
    classfile.constant_pool_count = read_u16(reader) or_return
    classfile.constant_pool = read_constant_pool(reader, classfile.constant_pool_count, allocator) or_return

    classfile.access_flags = read_flags(reader, ClassAccessFlags) or_return
    classfile.this_class = read_idx(ConstantClassInfo, reader) or_return
    classfile.super_class = read_idx(ConstantClassInfo, reader) or_return

    classfile.interfaces = read_indices(ConstantClassInfo, reader) or_return
    classfile.fields = read_fields(reader, classfile, allocator) or_return
    classfile.methods = read_methods(reader, classfile, allocator) or_return
    classfile.attributes = read_attributes(reader, classfile, allocator) or_return
    return
}

// An error returned while reading a ClassFile.
Error :: enum {
    // No error
    None,
    // Some generic IO error
    IO,
    // Provided allocator returned a mem.Allocator_Error
    AllocatorError,
    // Magic number was not present in the file header
    InvalidHeader,
    // Major version is not recognized.
    InvalidMajorVersion,
    // Expected more bytes
    UnexpectedEof,
    // Constant pool index is invalid.
    // Used within cp_get_safe()
    InvalidCPIndex,
    // Constant pool index points to an entry with the wrong type.
    // Used within cp_get_safe()
    WrongCPType,
    // Unknown VerificationTypeInfo tag
    UnknownVerificationTypeInfoTag,
    // Unknown ElementValue tag
    UnknownElementValueTag,
    // Using a reserved StackMapFrame type
    ReservedFrameType,
    // Unknown StackMapFrame type
    UnknownFrameType,
    // Missing attribute in some attribute holder
    MissingAttribute,
    // target_type of a TypeAnnotation was invalid
    InvalidTargetType,
    // path_kind of a TypePathEntry was invalid
    InvalidPathKind,
    // A type with an access_flags field (class, field, etc.) has invalid flag bits set
    InvalidAccessFlags,
    // Unknown opcode in the bytecode of a Code attribute
    UnknownOpcode,
}

@(private, require_results)
read_constant_pool :: proc(
    reader: ^ClassFileReader, 
    #any_int count: int, 
    allocator := context.allocator,
) -> (
    constant_pool: []ConstantPoolEntry, 
    err: Error,
) {
    constant_pool = make_safe([]ConstantPoolEntry, count - 1, allocator) or_return // omit first entry

    for i := 0; i < count - 1; i += 1 {
        tag := ConstantType(read_u8(reader) or_return)
        entry := read_constant_pool_entry(reader, tag) or_return

        constant_pool[i] = ConstantPoolEntry { tag, entry }
        if tag == .Double || tag == .Long {
            // unusable entry
            // ConstantType(0) does not exist, but doesn't matter because it's never printed
            constant_pool[i + 1] = ConstantPoolEntry { ConstantType(0), nil }
            i += 1
        }
    }
    return constant_pool, .None
}

@(private, require_results)
read_constant_pool_entry :: proc(
    reader: ^ClassFileReader,
    tag: ConstantType,
) -> (
    entry: CPInfo, 
    err: Error,
) {
    switch tag {
    case .Utf8:
        length := read_u16(reader) or_return
        bytes := read_nbytes(reader, length) or_return
        entry = ConstantUtf8Info { bytes }
    case .Integer:
        bytes := read_u32(reader) or_return
        entry = ConstantIntegerInfo { bytes }
    case .Float:
        bytes := read_u32(reader) or_return
        entry = ConstantFloatInfo { bytes }
    case .Long:
        high_bytes := read_u32(reader) or_return
        low_bytes := read_u32(reader) or_return
        entry = ConstantLongInfo { high_bytes, low_bytes }
    case .Double:
        high_bytes := read_u32(reader) or_return
        low_bytes := read_u32(reader) or_return
        entry = ConstantDoubleInfo { high_bytes, low_bytes }
    case .Class:
        name_idx := read_idx(ConstantUtf8Info, reader) or_return
        entry = ConstantClassInfo { name_idx }
    case .String:
        string_idx := read_idx(ConstantUtf8Info, reader) or_return
        entry = ConstantStringInfo { string_idx }
    case .FieldRef, .MethodRef, .InterfaceMethodRef:
        class_idx := read_idx(ConstantClassInfo, reader) or_return
        name_and_type_idx := read_idx(ConstantNameAndTypeInfo, reader) or_return
        entry = ConstantFieldRefInfo { class_idx, name_and_type_idx }
    case .NameAndType:
        name_idx := read_idx(ConstantUtf8Info, reader) or_return
        descriptor_idx := read_idx(ConstantUtf8Info, reader) or_return
        entry = ConstantNameAndTypeInfo { name_idx, descriptor_idx }
    case .MethodHandle:
        reference_kind := ReferenceKind(read_u8(reader) or_return)
        reference_idx := read_idx(ConstantMethodRefInfo, reader) or_return
        entry = ConstantMethodHandleInfo { reference_kind, reference_idx }
    case .MethodType:
        descriptor_idx := read_idx(ConstantUtf8Info, reader) or_return
        entry = ConstantMethodTypeInfo { descriptor_idx }
    case .Dynamic:
        bootstrap_method_attr_idx := read_u16(reader) or_return
        name_and_type_idx := read_idx(ConstantNameAndTypeInfo, reader) or_return
        entry = ConstantDynamicInfo { 
            bootstrap_method_attr_idx, 
            name_and_type_idx,
        }
    case .InvokeDynamic:
        bootstrap_method_attr_idx := read_u16(reader) or_return
        name_and_type_idx := read_idx(ConstantNameAndTypeInfo, reader) or_return
        entry = ConstantInvokeDynamicInfo { 
            bootstrap_method_attr_idx, 
            name_and_type_idx,
        }
    case .Module:
        name_idx := read_idx(ConstantUtf8Info, reader) or_return
        entry = ConstantModuleInfo { name_idx }
    case .Package:
        name_idx := read_idx(ConstantUtf8Info, reader) or_return
        entry = ConstantPackageInfo { name_idx }
    }
    return entry, .None
}

@(private, require_results)
read_methods :: proc(
    reader: ^ClassFileReader, 
    classfile: ClassFile,
    allocator := context.allocator,
) -> (
    methods: []MethodInfo,
    err: Error,
) {
    methods = alloc_slice(reader, []MethodInfo, allocator) or_return

    for &method in methods {
        access_flags := read_flags(reader, MethodAccessFlags) or_return
        name_idx := read_idx(ConstantUtf8Info, reader) or_return
        descriptor_idx := read_idx(ConstantUtf8Info, reader) or_return
        attributes := read_attributes(reader, classfile, allocator) or_return
        
        method = MethodInfo { access_flags, name_idx, descriptor_idx, attributes }
    }
    return methods, .None
}

@(private, require_results)
read_fields :: proc(
    reader: ^ClassFileReader,
    classfile: ClassFile,
    allocator := context.allocator,
) -> (
    fields: []FieldInfo,
    err: Error,
) {
    fields = alloc_slice(reader, []FieldInfo, allocator) or_return

    for &field in fields{
        access_flags := read_flags(reader, FieldAccessFlags) or_return
        name_idx := read_idx(ConstantUtf8Info, reader) or_return
        descriptor_idx := read_idx(ConstantUtf8Info, reader) or_return
        attributes := read_attributes(reader, classfile, allocator) or_return

        field = FieldInfo { access_flags, name_idx, descriptor_idx, attributes }
    }
    return fields, .None
}

// Reads a binary encoded flags type, backed by a u16 and validates it.
// Returns Error.InvalidAccessFlags if bits are set which are not a valid 
// flag of type F.
@(private, require_results)
read_flags :: proc(
    reader: ^ClassFileReader, 
    $T: typeid/bit_set[$F; u16],
) -> (
    flags: T, 
    err: Error,
) {
    flags = transmute(T) read_u16(reader) or_return
    validate_flags(flags) or_return
    return flags, .None
}

@(private, require_results)
validate_flags :: proc(flags: $T/bit_set[$F; u16]) -> Error {
    check: for flag in flags {
        for f in F {
            if flag == f do continue check
        }
        return .InvalidAccessFlags
    }
    return .None
}

// -------------------------------------------------- 
// Attribute parsing functions
// -------------------------------------------------- 

@(private, require_results)
read_attributes :: proc(
    reader: ^ClassFileReader, 
    classfile: ClassFile, 
    allocator := context.allocator,
) -> (
    attributes: []AttributeInfo, 
    err: Error,
) {
    attributes = alloc_slice(reader, []AttributeInfo, allocator) or_return

    for &attribute in attributes {
        attribute = read_attribute_info(reader, classfile, allocator) or_return
    }

    return attributes, .None
}

@(private, require_results)
read_attribute_info :: proc(
    reader: ^ClassFileReader, 
    classfile: ClassFile, 
    allocator := context.allocator,
) -> (
    attribute: AttributeInfo, 
    err: Error,
) {
    name_idx := read_idx(ConstantUtf8Info, reader) or_return
    //fmt.println(name_idx.idx, classfile.constant_pool_count)
    length := read_u32(reader) or_return
    attrib_name := cp_get_str(classfile, name_idx)
    //fmt.println("reading attrib", attrib_name)

    if reader.pos + int(length) > len(reader.bytes) {
        return attribute, .UnexpectedEof
    }

    // TODO: unchecked calls don't apply to indirect calls
    // not really something we can do about

    switch attrib_name {
    case "ConstantValue":
        constantvalue_idx := unchecked_read_u16(reader)
        attribute = ConstantValue { constantvalue_idx }
    case "Code":
        // TODO: read bytecode
        max_stack := unchecked_read_u16(reader)
        max_locals := unchecked_read_u16(reader)
        code_length := unchecked_read_u32(reader)
        code := unchecked_read_nbytes(reader, code_length)

        exception_table := alloc_slice(reader, []ExceptionHandler, allocator) or_return

        for &exception in exception_table {
            start_pc := unchecked_read_u16(reader)
            end_pc := unchecked_read_u16(reader)
            handler_pc := unchecked_read_u16(reader)
            catch_type := unchecked_read_idx(ConstantClassInfo, reader)
            exception = ExceptionHandler { start_pc, end_pc, handler_pc, catch_type }
        }

        attributes := read_attributes(reader, classfile) or_return
        attribute = Code {
            max_stack, max_locals, 
            code,
            exception_table,
            attributes,
        }
    case "StackMapTable":
        frames := alloc_slice(reader, []StackMapFrame, allocator) or_return
        for &frame in frames {
            frame = read_stack_map_frame(reader) or_return
        }
        attribute = StackMapTable { frames }
    case "Exceptions":
        exception_idx_table := unchecked_read_indices(ConstantClassInfo, reader)
        attribute = Exceptions { exception_idx_table }
    case "InnerClasses":
        classes := alloc_slice(reader, []InnerClassEntry, allocator) or_return
        for &class in classes {
            class = InnerClassEntry {
                inner_class_info_idx = unchecked_read_idx(ConstantClassInfo, reader),
                outer_class_info_idx = unchecked_read_idx(ConstantClassInfo, reader),
                name_idx = unchecked_read_idx(ConstantUtf8Info, reader),
                access_flags = read_flags(reader, InnerClassAccessFlags) or_return,
            }
        }
        attribute = InnerClasses { classes }
    case "EnclosingMethod":
        class_idx := unchecked_read_idx(ConstantClassInfo, reader)
        method_idx := unchecked_read_idx(ConstantNameAndTypeInfo, reader)
        attribute = EnclosingMethod { class_idx, method_idx }
    case "Synthetic": attribute = Synthetic {}
    case "Signature": 
        signature_idx := unchecked_read_idx(ConstantUtf8Info, reader)
        attribute = Signature { signature_idx }
    case "SourceFile": 
        sourcefile_idx := unchecked_read_idx(ConstantUtf8Info, reader)
        attribute = SourceFile { sourcefile_idx }
    case "SourceDebugExtension":
        debug_extension := unchecked_read_nbytes(reader, length)
        attribute = SourceDebugExtension { string(debug_extension) }
    case "LineNumberTable":
        // TODO: mem.slice_data_cast?
        table := alloc_slice(reader, []LineNumberTableEntry, allocator) or_return

        for &entry in table {
            start_pc := unchecked_read_u16(reader)
            line_number := unchecked_read_u16(reader)
            entry = LineNumberTableEntry { start_pc, line_number }
        }
        attribute = LineNumberTable { table }
    case "LocalVariableTable":
        table := read_local_variable_table(reader) or_return
        attribute = LocalVariableTable  { table }
    case "LocalVariableTypeTable":
        table := read_local_variable_type_table(reader) or_return
        // SAFETY: this should keep working as long as both entry types have the same size
        attribute = LocalVariableTypeTable { transmute([]LocalVariableTypeTableEntry)table }
    case "Deprecated": attribute = Deprecated {}
    case "RuntimeVisibleAnnotations":
        annotations := read_annotations(reader, allocator) or_return
        attribute = RuntimeVisibleAnnotations { annotations }
    case "RuntimeInvisibleAnnotations":
        annotations := read_annotations(reader, allocator) or_return
        attribute = RuntimeInvisibleAnnotations { annotations }
    case "RuntimeVisibleParameterAnnotations":
        parameter_annotations := read_parameter_annotations(reader) or_return
        attribute = RuntimeVisibleParameterAnnotations { parameter_annotations }
    case "RuntimeInvisibleParameterAnnotations":
        parameter_annotations := read_parameter_annotations(reader) or_return
        attribute = RuntimeInvisibleParameterAnnotations { parameter_annotations }
    case "RuntimeVisibleTypeAnnotations":
        type_annotations := read_type_annotations(reader, allocator) or_return
        attribute = RuntimeVisibleTypeAnnotations { type_annotations }
    case "RuntimeInvisibleTypeAnnotations":
        type_annotations := read_type_annotations(reader, allocator) or_return
        attribute = RuntimeInvisibleTypeAnnotations { type_annotations }
    case "AnnotationDefault":
        default_value := read_element_value(reader, allocator) or_return
        attribute = AnnotationDefault { default_value }
    case "BootstrapMethods":
        bootstrap_methods := alloc_slice(reader, []BootstrapMethod, allocator) or_return
        for &method in bootstrap_methods {
            method = BootstrapMethod {
                bootstrap_method_ref = unchecked_read_idx(ConstantMethodHandleInfo, reader),
                bootstrap_args = unchecked_read_u16_slice(reader),
            }
        }
        attribute = BootstrapMethods { bootstrap_methods }
    case "NestHost":
        host_class_idx := unchecked_read_idx(ConstantClassInfo, reader)
        attribute = NestHost { host_class_idx }
    case "NestMembers":
        classes := unchecked_read_indices(ConstantClassInfo, reader)
        attribute = NestMembers { classes }
    case "Module":
        attribute = read_module(reader) or_return
    case "ModulePackages":
        package_idx := unchecked_read_indices(ConstantPackageInfo, reader)
        attribute = ModulePackages { package_idx }
    case "ModuleMainClass":
        main_class_idx := unchecked_read_idx(ConstantClassInfo, reader)
        attribute = ModuleMainClass { main_class_idx }
    case "Record":
        components := alloc_slice(reader, []RecordComponentInfo, allocator) or_return

        for &component in components {
            name_idx := unchecked_read_idx(ConstantUtf8Info, reader)
            descriptor_idx := unchecked_read_idx(ConstantUtf8Info, reader)
            attributes := read_attributes(reader, classfile, allocator) or_return

            component = RecordComponentInfo {
                name_idx, descriptor_idx, attributes,
            }
        }
        attribute = Record { components }
    case "PermittedSubclasses":
        classes := unchecked_read_indices(ConstantClassInfo, reader)
        attribute = PermittedSubclasses { classes }
    case:
        attribute = Unknown { bytes = unchecked_read_nbytes(reader, length) }
    }
    return attribute, .None
}

@(private, require_results)
read_stack_map_frame :: proc(
    reader: ^ClassFileReader,
) -> (
    frame: StackMapFrame, 
    err: Error,
) {
    frame_type := read_u8(reader) or_return

    switch frame_type {
    case 0..=63: frame = SameFrame {}
    case 64..=127:
        stack := read_verification_type_info(reader) or_return
        frame = SameLocals1StackItemFrame { stack }
    case 128..=246: return frame, .ReservedFrameType
    case 247:
        offset_delta := read_u16(reader) or_return
        stack := read_verification_type_info(reader) or_return
        frame = SameLocals1StackItemFrameExtended { offset_delta, stack }
    case 248..=250:
        offset_delta := read_u16(reader) or_return
        frame = ChopFrame { offset_delta }
    case 251:
        offset_delta := read_u16(reader) or_return
        frame = SameFrameExtended { offset_delta }
    case 252..=254:
        offset_delta := read_u16(reader) or_return
        count := u16(frame_type) - FRAME_LOCALS_OFFSET  
        locals := read_verification_type_infos(reader, count) or_return
        frame = AppendFrame { offset_delta, locals }
    case 255:
        offset_delta := read_u16(reader) or_return
        number_of_locals := read_u16(reader) or_return
        locals := read_verification_type_infos(reader, number_of_locals) or_return
        number_of_stack_items := read_u16(reader) or_return
        stack := read_verification_type_infos(reader, number_of_stack_items) or_return
        frame = FullFrame { offset_delta, locals, stack }
    case: return frame, .UnknownFrameType
    }
    return frame, .None
}

@(private, require_results)
read_module :: proc(
    reader: ^ClassFileReader, 
    allocator := context.allocator,
) -> (
    module: Module, 
    err: Error,
) {
    module_name_idx := read_idx(ConstantModuleInfo, reader) or_return
    module_flags := read_flags(reader, ModuleFlags) or_return
    module_version_idx := read_idx(ConstantUtf8Info, reader) or_return

    requires := alloc_slice(reader, []ModuleRequire, allocator) or_return
    for &require in requires {
        require = ModuleRequire {
            requires_idx = read_idx(ConstantModuleInfo, reader) or_return,
            requires_flags = read_flags(reader, ModuleRequireFlags) or_return,
            requires_version_idx = read_idx(ConstantUtf8Info, reader) or_return,
        }

    }

    exports := alloc_slice(reader, []ModuleExport, allocator) or_return
    for &export in exports {
        export = ModuleExport {
            exports_idx = read_idx(ConstantPackageInfo, reader) or_return,
            exports_flags = read_flags(reader, ModuleExportFlags) or_return,
            exports_to_idx = read_indices(ConstantModuleInfo, reader) or_return,
        }
    }

    opens := alloc_slice(reader, []ModuleOpens, allocator) or_return
    for &open in opens {
        open = ModuleOpens {
            opens_idx = read_idx(ConstantPackageInfo, reader) or_return,
            opens_flags = read_flags(reader, ModuleOpensFlags) or_return,
            opens_to_idx = read_indices(ConstantModuleInfo, reader) or_return,
        }
    }

    uses_idx := read_indices(ConstantClassInfo, reader) or_return

    provides := alloc_slice(reader, []ModuleProvides, allocator) or_return
    for &provide in provides {
        provide = ModuleProvides {
            provides_idx = read_idx(ConstantClassInfo, reader) or_return,
            provides_with_idx = read_indices(ConstantClassInfo, reader) or_return,
        }
    }
    
    return Module {
        module_name_idx,
        module_flags,
        module_version_idx,
        requires,
        exports,
        opens,
        uses_idx,
        provides,
    }, .None
}

// required for transmuting
#assert(size_of(LocalVariableTableEntry) == size_of(LocalVariableTypeTableEntry))

read_local_variable_type_table :: read_local_variable_table

@(private, require_results)
read_local_variable_table :: proc(
    reader: ^ClassFileReader, 
    allocator := context.allocator,
) -> (
    table: []LocalVariableTableEntry, 
    err: Error,
) {
    table = alloc_slice(reader, []LocalVariableTableEntry, allocator) or_return

    for &local_var in table {
        local_var = LocalVariableTableEntry {
            start_pc = read_u16(reader) or_return,
            length = read_u16(reader) or_return,
            name_idx = read_idx(ConstantUtf8Info, reader) or_return,
            descriptor_idx = read_idx(ConstantUtf8Info, reader) or_return,
            idx = read_u16(reader) or_return,
        }
    }
    return table, .None
}

@(private, require_results)
read_parameter_annotations :: proc(
    reader: ^ClassFileReader, 
    allocator := context.allocator,
) -> (
    param_annotations: []ParameterAnnotation, 
    err: Error,
) {
    param_annotations = alloc_slice(reader, []ParameterAnnotation, allocator) or_return

    for &annotation in param_annotations {
        annotations := read_annotations(reader, allocator) or_return
        annotation = ParameterAnnotation { annotations }
    }
    return param_annotations, .None
}

@(private, require_results)
read_annotations :: proc(
    reader: ^ClassFileReader, 
    allocator := context.allocator,
) -> (
    annotations: []Annotation, 
    err: Error,
) {
    annotations = alloc_slice(reader, []Annotation, allocator) or_return

    for &annotation in annotations {
        annotation = read_annotation(reader, allocator) or_return
    }
    return annotations, .None
}

@(private, require_results)
read_annotation :: proc(
    reader: ^ClassFileReader, 
    allocator := context.allocator,
) -> (
    annotation: Annotation, 
    err: Error,
) {
    type_idx := read_idx(ConstantUtf8Info, reader) or_return
    element_value_pairs := read_element_value_pairs(reader, allocator) or_return

    return Annotation { type_idx, element_value_pairs }, .None
}

@(private, require_results)
read_element_value_pairs :: proc(
    reader: ^ClassFileReader,
    allocator := context.allocator,
) -> (
    pairs: []ElementValuePair,
    err: Error,
) {
    pairs = alloc_slice(reader, []ElementValuePair, allocator) or_return

    for &pair in pairs {
        element_value_idx := read_idx(ConstantUtf8Info, reader) or_return
        element_value := read_element_value(reader, allocator) or_return
        pair = ElementValuePair { element_value_idx, element_value }
    }

    return pairs, .None
}

@(private, require_results)
read_element_value :: proc(
    reader: ^ClassFileReader, 
    allocator := context.allocator,
) -> (
    element_value: ElementValue, 
    err: Error,
) {
    element_value_tag := read_u8(reader) or_return

    switch element_value_tag {
    case 'B', 'C', 'D', 'F', 'I', 'J', 'S', 'Z', 's':
        element_value.value = ConstValueIdx(read_u16(reader) or_return)
    case 'e':
        type_name_idx := read_idx(ConstantUtf8Info, reader) or_return
        const_name_idx := read_idx(ConstantUtf8Info, reader) or_return
        element_value.value = EnumConstValue { type_name_idx, const_name_idx }
    case 'c':
        class_info_idx := read_u16(reader) or_return
        element_value.value = ClassInfoIdx(class_info_idx)
    case '@':
        element_value.value = read_annotation(reader) or_return
    case '[':
        values := alloc_slice(reader, []ElementValue, allocator) or_return
        for &value in values {
            value = read_element_value(reader, allocator) or_return
        }
        element_value.value = ArrayValue { values }
    case:
        return element_value, .UnknownElementValueTag
    }
    return element_value, .None
}

@(private, require_results)
read_verification_type_infos :: proc(
    reader: ^ClassFileReader, 
    count: u16, 
    allocator := context.allocator,
) -> (
    locals: []VerificationTypeInfo, 
    err: Error,
) {
    locals = make_safe([]VerificationTypeInfo, count, allocator) or_return

    for &local in locals {
        local = read_verification_type_info(reader) or_return
    }
    return locals, .None
}

@(private, require_results)
read_verification_type_info :: proc(
    reader: ^ClassFileReader,
) -> (
    info: VerificationTypeInfo, 
    err: Error,
) {
    tag := FrameTag(read_u8(reader) or_return)
    switch tag {
    case .Top: info = TopVariableInfo {}
    case .Integer: info = IntegerVariableInfo {}
    case .Float: info = FloatVariableInfo {}
    case .Double: info = DoubleVariableInfo {}
    case .Long: info = LongVariableInfo {}
    case .Null: info = NullVariableInfo {}
    case .UninitializedThis: info = UninitializedThisVariableInfo {}
    case .Object: 
        cp_idx := read_idx(ConstantClassInfo, reader) or_return
        info = ObjectVariableInfo { cp_idx }
    case .Uninitialized:
        offset := read_u16(reader) or_return
        info = UninitializedVariableInfo { offset }
    case: 
        return info, .UnknownVerificationTypeInfoTag
    }
    return info, .None
}

FrameTag :: enum u8 {
    Top               = 0,
    Integer           = 1,
    Float             = 2,
    Double            = 3,
    Long              = 4,
    Null              = 5,
    UninitializedThis = 6,
    Object            = 7,
    Uninitialized     = 8,
}

@(private, require_results)
read_type_annotations :: proc(
    reader: ^ClassFileReader,
    allocator := context.allocator,
) -> (
    type_annotations: []TypeAnnotation,
    err: Error,
) {
    type_annotations = alloc_slice(reader, []TypeAnnotation, allocator) or_return
    for &type_annotation in type_annotations {
        target_type := TargetType(read_u8(reader) or_return)
        target_info: TargetInfo

        switch target_type {
        case .ClassType, 
             .MethodType:
            type_parameter_idx := read_u16(reader) or_return
            target_info = TypeParameterTarget { type_parameter_idx }
        case .ClassExtends:
            super_type_idx := read_u16(reader) or_return
            target_info = SuperTypeTarget { super_type_idx }
        case .ClassTypeParameterBound,
             .MethodTypeParameterBound:
            type_parameter_idx := read_u16(reader) or_return
            bound_idx := read_u16(reader) or_return
            target_info = TypeParameterBoundTarget { type_parameter_idx, bound_idx }
        case .Field,
             .MethodReturn,
             .MethodReceiver:
            target_info = EmptyTarget {}
        case .MethodFormalParameter:
            formal_parameter_idx := read_u16(reader) or_return
            target_info = FormalParameterTarget { formal_parameter_idx }
        case .Throws:
            throws_type_idx := read_u16(reader) or_return
            target_info = ThrowsTarget { throws_type_idx }
        case .LocalVariable,
             .ResourceVariable:
            table := alloc_slice(reader, []LocalVarTargetEntry, allocator) or_return
            for &entry in table {
                start_pc := read_u16(reader) or_return
                length := read_u16(reader) or_return
                idx := read_u16(reader) or_return
                entry = LocalVarTargetEntry { start_pc, length, idx }
            }

            target_info = LocalVarTarget { table }
        case .ExceptionParameter:
            exception_table_idx := read_u16(reader) or_return
            target_info = CatchTarget { exception_table_idx }
        case .Instanceof,
             .New,
             .ConstructorReference,
             .MethodReference:
            offset := read_u16(reader) or_return
            target_info = OffsetTarget { offset }
        case .Cast,
             .ConstructorInvocationTypeArgument,
             .MethodInvocationTypeArgument,
             .ConstructorReferenceTypeArgument,
             .MethodReferenceTypeArgument:
            offset := read_u16(reader) or_return
            type_argument_idx := read_u16(reader) or_return
            target_info = TypeArgumentTarget { offset, type_argument_idx }
        case: 
            return type_annotations, .InvalidTargetType
        }

        path := alloc_slice(reader, []PathEntry, allocator) or_return
        for &path_entry in path {
            path_kind := PathKind(read_u8(reader) or_return)
            type_argument_idx: u8

            switch path_kind {
            case .ArrayType,
                 .NestedType,
                 .Wildcard:
                type_argument_idx = 0
            case .Parameterized:
                // TODO: is this correct? where else would we get the value from
                // https://docs.oracle.com/javase/specs/jvms/se21/html/jvms-4.html#jvms-4.7.20.2
                type_argument_idx = read_u8(reader) or_return
            case:
                return type_annotations, .InvalidPathKind
            }

            path_entry = PathEntry { path_kind, type_argument_idx }
        }

        target_path := TypePath { path }
        annotation := read_annotation(reader, allocator) or_return

        type_annotation = TypeAnnotation {
            target_type,
            target_info,
            target_path,
            annotation,
        }
    }

    return type_annotations, .None
}

/// -------------------------------------------------- 
/// Low level parsing functions
/// -------------------------------------------------- 

// An alternative for builtin.make, which returns an optional Error, to use or_return on.
@(private, require_results)
make_safe :: proc(
    $T: typeid/[]$E, 
    #any_int len: int, 
    allocator := context.allocator, 
    loc := #caller_location,
) -> (
    T, Error,
) {
    t, err := make(T, len, allocator, loc)
    if err != .None do return t, .AllocatorError
    return t, .None
}

@(private, require_results)
alloc_slice :: proc(
    reader: ^ClassFileReader,
    $T: typeid/[]$E,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    ret: T, 
    err: Error,
) {
    length := read_u16(reader) or_return
    alloc_err: mem.Allocator_Error
    // TODO: non-zeroed slice in non debug mode
    when true {
        ret, alloc_err = make(T, length, allocator, loc)
    } else {
        bytes: []u8 = ---
        bytes, alloc_err = mem.alloc_bytes_non_zeroed(int(length), align_of(T), allocator, loc)
        ret = mem.slice_data_cast(T, bytes)
        //mem.zero_slice(bytes)
    }
    //ret, alloc_err = make(T, length, allocator, loc)

    if alloc_err != .None do return ret, .AllocatorError
    return ret, .None
}

@(private, require_results)
read_u8 :: proc(using reader: ^ClassFileReader) -> (u8, Error) {
    if pos >= len(bytes) {
        return 0, .UnexpectedEof
    }
    defer pos += 1
    #no_bounds_check return bytes[pos], .None
}

// TODO: determine impact of calls into encoding/endian vs inlining these manually

@(private, require_results)
read_u16 :: proc(using reader: ^ClassFileReader) -> (u16, Error) {
    ret, ok := endian.get_u16(bytes[pos:], .Big)
    if !ok do return ret, .UnexpectedEof
    pos += 2
    return ret, .None
}

@(private, require_results)
read_u32 :: proc(using reader: ^ClassFileReader) -> (u32, Error) {
    ret, ok := endian.get_u32(bytes[pos:], .Big)
    if !ok do return ret, .UnexpectedEof
    pos += 4
    return ret, .None
}

@(private, require_results)
read_nbytes :: proc(using reader: ^ClassFileReader, #any_int n: int) -> ([]u8, Error) { 
    if pos + n > len(bytes) {
        return nil, .UnexpectedEof
    }
    defer pos += n
    #no_bounds_check return bytes[pos:][:n], .None
}

// Reads a slice of u16s, the length is prepended as a u16 before the actual data.
// | length: u16 | data: ...u16 (length items) |
@(private, require_results)
read_u16_slice :: proc(reader: ^ClassFileReader) -> (ret: []u16, err: Error) {
    elem_count := read_u16(reader) or_return
    bytes := read_nbytes(reader, elem_count * size_of(u16)) or_return
    return mem.slice_data_cast([]u16, bytes), .None
}

@(private)
read_idx :: proc($E: typeid, reader: ^ClassFileReader) -> (ret: Ptr(E), err: Error)
where intrinsics.type_is_variant_of(CPInfo, E) {
    idx := #force_inline read_u16(reader) or_return
    return Ptr(E) { idx }, .None
}

// See read_u16_slice().
@(private, require_results)
read_indices :: proc($E: typeid, reader: ^ClassFileReader) -> (ret: []Ptr(E), err: Error)
where intrinsics.type_is_variant_of(CPInfo, E) {
    elem_count := read_u16(reader) or_return
    bytes := read_nbytes(reader, elem_count * size_of(u16)) or_return
    return mem.slice_data_cast([]Ptr(E), bytes), .None
}

// -------------------------------------------------- 
// Unchecked low level parsing functions.
// -------------------------------------------------- 

@(private, require_results)
unchecked_read_u16 :: proc(using reader: ^ClassFileReader) -> u16 {
    defer pos += 2
    return endian.unchecked_get_u16be(bytes[pos:])
}

@(private, require_results)
unchecked_read_u32 :: proc(using reader: ^ClassFileReader) -> u32 {
    defer pos += 4
    return endian.unchecked_get_u32be(bytes[pos:])
}

@(private, require_results)
unchecked_read_nbytes :: proc(using reader: ^ClassFileReader, #any_int n: int) -> []u8 {
    defer pos += n
    #no_bounds_check return bytes[pos:][:n]
}

@(private, require_results)
unchecked_read_u16_slice :: proc(reader: ^ClassFileReader) -> []u16 {
    elem_count := unchecked_read_u16(reader)
    bytes := unchecked_read_nbytes(reader, elem_count * size_of(u16))
    return mem.slice_data_cast([]u16, bytes)
}

@(private, require_results)
unchecked_read_idx :: proc($E: typeid, reader: ^ClassFileReader) -> Ptr(E)
where intrinsics.type_is_variant_of(CPInfo, E) #no_bounds_check {
    idx := #force_inline unchecked_read_u16(reader)
    return Ptr(E) { idx }
}

// See read_u16_slice().
@(private, require_results)
unchecked_read_indices :: proc($E: typeid, reader: ^ClassFileReader) -> []Ptr(E)
where intrinsics.type_is_variant_of(CPInfo, E) {
    elem_count := unchecked_read_u16(reader)
    bytes := unchecked_read_nbytes(reader, elem_count * size_of(u16))
    return mem.slice_data_cast([]Ptr(E), bytes)
}
