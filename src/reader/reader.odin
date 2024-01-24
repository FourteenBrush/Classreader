package reader

import "core:slice"
import "core:encoding/endian"

ClassFileReader :: struct {
    bytes: []u8,
    pos: int,
}

// Creates a new ClassFileReader, reading the given bytes.
// These bytes must be deallocated by the caller.
reader_new :: proc(bytes: []u8) -> ClassFileReader {
    return ClassFileReader { bytes, 0 }
}

@private
MAGIC :: 0xCAFEBABE

// Attempts to a read a classfile, returning the error if failed.
// NOTE: the resulting ClassFile's lifetime is bound to the bytes it got from the reader.
// This might become subject to change, to only clone necessary byte slices instead.
read_classfile :: proc(
    reader: ^ClassFileReader, 
    allocator := context.allocator,
) -> (
    classfile: ClassFile,
    err: Error,
) {
    magic := read_u32(reader) or_return
    if magic != MAGIC do return classfile, .InvalidHeader

    using classfile
    minor_version = read_u16(reader) or_return
    major_version = read_u16(reader) or_return
    constant_pool_count = read_u16(reader) or_return
    constant_pool = read_constant_pool(reader, constant_pool_count, allocator) or_return

    // TODO: ensure valid
    access_flags = transmute(ClassAccessFlags) read_u16(reader) or_return
    this_class = read_u16(reader) or_return
    super_class = read_u16(reader) or_return

    interfaces = read_interfaces(reader) or_return
    fields = read_fields(reader, classfile, allocator) or_return
    methods = read_methods(reader, classfile, allocator) or_return
    attributes = read_attributes(reader, classfile, allocator) or_return
    return
}

Error :: enum {
    // No error
    None,
    // Some generic IO error
    IO,
    // Magic number was not present in the file header
    InvalidHeader,
    // Expected more bytes
    UnexpectedEof,
    // Constant pool index is invalid
    InvalidCPIndex,
    // Constant pool index points to an entry with the wrong type
    WrongCPType,
    // Unknown VerificationTypeInfo tag
    UnknownVerificationTypeInfoTag,
    // Unknown attribute name
    UnknownAttributeName,
    // Unknown ElementValue tag
    UnknownElementValueTag,
    // Using a reserved StackMapFrame type
    ReservedFrameType,
    // Unknown StackMapFrame type
    UnknownFrameType,
    // Missing attribute in some attribute holder
    MissingAttribute,
    // Unknown bytecode opcode in a Code attribute,
    UnknownOpcode,
}

@private
read_constant_pool :: proc(
    reader: ^ClassFileReader, 
    count: u16, 
    allocator := context.allocator,
) -> (
    constant_pool: []ConstantPoolEntry, 
    err: Error,
) {
    constant_pool = make([]ConstantPoolEntry, count - 1, allocator) // omit first entry

    for i := 0; i < int(count) - 1; i += 1 {
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

@private
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
            name_idx := read_u16(reader) or_return
            entry = ConstantClassInfo { name_idx }
        case .String:
            string_idx := read_u16(reader) or_return
            entry = ConstantStringInfo { string_idx }
        case .FieldRef, .MethodRef, .InterfaceMethodRef:
            class_idx := read_u16(reader) or_return
            name_and_type_idx := read_u16(reader) or_return
            entry = ConstantFieldRefInfo { class_idx, name_and_type_idx }
        case .NameAndType:
            name_idx := read_u16(reader) or_return
            descriptor_idx := read_u16(reader) or_return
            entry = ConstantNameAndTypeInfo { name_idx, descriptor_idx }
        case .MethodHandle:
            reference_kind := ReferenceKind(read_u8(reader) or_return)
            reference_idx := read_u16(reader) or_return
            entry = ConstantMethodHandleInfo { reference_kind, reference_idx }
        case .MethodType:
            descriptor_idx := read_u16(reader) or_return
            entry = ConstantMethodTypeInfo { descriptor_idx }
        case .InvokeDynamic:
            bootstrap_method_attr_idx := read_u16(reader) or_return
            name_and_type_idx := read_u16(reader) or_return
            entry = ConstantInvokeDynamicInfo { bootstrap_method_attr_idx, name_and_type_idx }
        case .Module:
        case .Package:
            // TODO
    }
    return entry, .None
}

@private
read_interfaces :: proc(reader: ^ClassFileReader) -> (interfaces: []u16, err: Error) {
    count := read_u16(reader) or_return
    interfaces = read_u16_array(reader, count) or_return
    return interfaces, .None
}

@private
read_methods :: proc(
    reader: ^ClassFileReader, 
    classfile: ClassFile,
    allocator := context.allocator,
) -> (
    methods: []MethodInfo,
    err: Error,
) {
    count := read_u16(reader) or_return
    methods = make([]MethodInfo, count, allocator)

    for i in 0..<count {
        // TODO: validate
        access_flags := transmute(MethodAccessFlags) read_u16(reader) or_return
        name_idx := read_u16(reader) or_return
        descriptor_idx := read_u16(reader) or_return
        attributes := read_attributes(reader, classfile, allocator) or_return
        
        methods[i] = MethodInfo {
            access_flags,
            name_idx,
            descriptor_idx,
            attributes,
        }
    }
    return methods, .None
}

@private
read_fields :: proc(
    reader: ^ClassFileReader,
    classfile: ClassFile,
    allocator := context.allocator,
) -> (
    fields: []FieldInfo,
    err: Error,
) {
    count := read_u16(reader) or_return
    fields = make([]FieldInfo, count, allocator)

    for i in 0..<count {
        // TODO: validate
        access_flags := transmute(FieldAccessFlags)read_u16(reader) or_return
        name_idx := read_u16(reader) or_return
        descriptor_idx := read_u16(reader) or_return

        fields[i] = FieldInfo {
            access_flags, name_idx,
            descriptor_idx,
            read_attributes(reader, classfile, allocator) or_return,
        }
    }
    return fields, .None
}

@private
read_attributes :: proc(
    reader: ^ClassFileReader, 
    classfile: ClassFile, 
    allocator := context.allocator,
) -> (
    attributes: []AttributeInfo, 
    err: Error,
) {
    count := read_u16(reader) or_return
    attributes = make([]AttributeInfo, count, allocator)
    
    for i in 0..<count {
        attributes[i] = read_attribute_info(reader, classfile, allocator) or_return
    }
    return attributes, .None
}

@private
read_attribute_info :: proc(
    reader: ^ClassFileReader, 
    classfile: ClassFile, 
    allocator := context.allocator,
) -> (
    attribute: AttributeInfo, 
    err: Error,
) {
    name_idx := read_u16(reader) or_return
    length := read_u32(reader) or_return
    attrib_name := cp_get_str(classfile, name_idx)

    switch attrib_name {
        case "ConstantValue":
            constantvalue_idx := read_u16(reader) or_return
            attribute = ConstantValue { constantvalue_idx }
        case "Code":
            // TODO: read bytecode
            max_stack := read_u16(reader) or_return
            max_locals := read_u16(reader) or_return
            code_length := read_u32(reader) or_return
            code := read_nbytes(reader, code_length) or_return
            exception_table_length := read_u16(reader) or_return
            exception_table := make([]ExceptionHandler, exception_table_length, allocator)

            for i in 0..<exception_table_length {
                start_pc := read_u16(reader) or_return
                end_pc := read_u16(reader) or_return
                handler_pc := read_u16(reader) or_return
                catch_type := read_u16(reader) or_return
                exception_table[i] = ExceptionHandler { start_pc, end_pc, handler_pc, catch_type }
            }

            attributes := read_attributes(reader, classfile) or_return
            attribute = Code {
                max_stack, max_locals, 
                code,
                exception_table,
                attributes,
            }
        case "StackMapTable":
            number_of_entries := read_u16(reader) or_return
            entries := make([]StackMapFrame, number_of_entries, allocator)

            for i in 0..<number_of_entries {
                frame_type := read_u8(reader) or_return
                switch frame_type {
                    case 0..=63:
                        entries[i] = SameFrame {}
                    case 64..=127:
                        stack := read_verification_type_info(reader) or_return
                        entries[i] = SameLocals1StackItemFrame { stack }
                    case 128..=246:
                        return attribute, .ReservedFrameType
                    case 247:
                        offset_delta := read_u16(reader) or_return
                        stack := read_verification_type_info(reader) or_return
                        entries[i] = SameLocals1StackItemFrameExtended { offset_delta, stack }
                    case 248..=250:
                        offset_delta := read_u16(reader) or_return
                        entries[i] = ChopFrame { offset_delta }
                    case 251:
                        offset_delta := read_u16(reader) or_return
                        entries[i] = SameFrameExtended { offset_delta }
                    case 252..=254:
                        offset_delta := read_u16(reader) or_return
                        count := u16(frame_type) - FRAME_LOCALS_OFFSET  
                        locals := read_verification_type_infos(reader, count) or_return
                        entries[i] = AppendFrame { offset_delta, locals }
                    case 255:
                        offset_delta := read_u16(reader) or_return
                        number_of_locals := read_u16(reader) or_return
                        locals := read_verification_type_infos(reader, number_of_locals) or_return
                        number_of_stack_items := read_u16(reader) or_return
                        stack := read_verification_type_infos(reader, number_of_stack_items) or_return
                        entries[i] = FullFrame { offset_delta, locals, stack }
                    case:
                        return attribute, .UnknownFrameType
                }
            }
            attribute = StackMapTable { entries }
        case "Exceptions":
            number_of_exceptions := read_u16(reader) or_return
            exception_idx_table := read_u16_array(reader, number_of_exceptions) or_return
            attribute = Exceptions { exception_idx_table }
        case "InnerClasses":
            number_of_classes := read_u16(reader) or_return
            classes := make([]InnerClassEntry, number_of_classes, allocator)

            for i in 0..<number_of_classes {
                inner_class_info_idx := read_u16(reader) or_return
                outer_class_info_idx := read_u16(reader) or_return
                name_idx := read_u16(reader) or_return
                access_flags := transmute(InnerClassAccessFlags) read_u16(reader) or_return
                classes[i] = InnerClassEntry {
                    inner_class_info_idx,
                    outer_class_info_idx,
                    name_idx, access_flags,
                }
            }
            attribute = InnerClasses { classes }
        case "EnclosingMethod":
            class_idx := read_u16(reader) or_return
            method_idx := read_u16(reader) or_return
            attribute = EnclosingMethod { class_idx, method_idx }
        case "Synthetic": attribute = Synthetic {}
        case "Signature": 
            signature_idx := read_u16(reader) or_return
            attribute = Signature { signature_idx }
        case "SourceFile": 
            sourcefile_idx := read_u16(reader) or_return
            attribute = SourceFile { sourcefile_idx }
        case "SourceDebugExtension":
            debug_extension := read_nbytes(reader, int(length)) or_return
            attribute = SourceDebugExtension { string(debug_extension) }
        case "LineNumberTable":
            // TODO: slice.reinterpret?
            table_length := read_u16(reader) or_return
            table := make([]LineNumberTableEntry, table_length, allocator)

            for i in 0..<table_length {
                start_pc := read_u16(reader) or_return
                line_number := read_u16(reader) or_return
                table[i] = LineNumberTableEntry { start_pc, line_number }
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
        case "AnnotationDefault":
            default_value := read_element_value(reader, allocator) or_return
            info := AnnotationDefault { default_value }
        case "BootstrapMethods":
            num_bootstrap_methods := read_u16(reader) or_return
            bootstrap_methods := make([]BootstrapMethod, num_bootstrap_methods, allocator)

            for i in 0..<num_bootstrap_methods {
                bootstrap_method_ref := read_u16(reader) or_return
                num_bootstrap_args := read_u16(reader) or_return
                bootstrap_args := read_u16_array(reader, num_bootstrap_args) or_return

                bootstrap_methods[i] = BootstrapMethod {
                    bootstrap_method_ref,
                    bootstrap_args,
                }
            }
            attribute = BootstrapMethods { bootstrap_methods }
        case "NestHost":
            host_class_idx := read_u16(reader) or_return
            attribute = NestHost { host_class_idx }
        case "NestMembers":
            number_of_classes := read_u16(reader) or_return
            classes := read_u16_array(reader, number_of_classes) or_return
            attribute = NestMembers { classes }
        case "Module":
            // TODO: read these attributes
        case "ModulePackages":
        case "ModuleMainClass":
        case:
            return attribute, .UnknownAttributeName
    }
    return attribute, .None
}

// required for transmuting
#assert(size_of(LocalVariableTableEntry) == size_of(LocalVariableTypeTableEntry))

read_local_variable_type_table :: read_local_variable_table

@private
read_local_variable_table :: proc(
    reader: ^ClassFileReader, 
    allocator := context.allocator,
) -> (
    table: []LocalVariableTableEntry, 
    err: Error,
) {
    table_length := read_u16(reader) or_return
    table = make([]LocalVariableTableEntry, table_length, allocator)

    for i in 0..<table_length {
        start_pc := read_u16(reader) or_return
        length := read_u16(reader) or_return
        name_idx := read_u16(reader) or_return
        signature_idx := read_u16(reader) or_return
        idx := read_u16(reader) or_return

        table[i] = LocalVariableTableEntry {
            start_pc, length,
            name_idx, signature_idx,
            idx,
        }
    }
    return table, .None
}

@private
read_parameter_annotations :: proc(
    reader: ^ClassFileReader, 
    allocator := context.allocator,
) -> (
    param_annotations: []ParameterAnnotation, 
    err: Error,
) {
    num_parameters := read_u8(reader) or_return
    param_annotations = make([]ParameterAnnotation, num_parameters, allocator)

    for i in 0..<num_parameters {
        annotations := read_annotations(reader, allocator) or_return
        param_annotations[i] = ParameterAnnotation { annotations }
    }
    return param_annotations, .None
}

@private
read_annotations :: proc(
    reader: ^ClassFileReader, 
    allocator := context.allocator,
) -> (
    annotations: []Annotation, 
    err: Error,
) {
    num_annotations := read_u16(reader) or_return
    annotations = make([]Annotation, num_annotations, allocator)

    for i in 0..<num_annotations {
        annotations[i] = read_annotation(reader, allocator) or_return
    }
    return annotations, .None
}

@private
read_annotation :: proc(
    reader: ^ClassFileReader, 
    allocator := context.allocator,
) -> (
    annotation: Annotation, 
    err: Error,
) {
    type_idx := read_u16(reader) or_return
    num_element_value_pairs := read_u16(reader) or_return
    element_value_pairs := make([]ElementValuePair, num_element_value_pairs, allocator)

    for i in 0..<num_element_value_pairs {
        element_value_idx := read_u16(reader) or_return
        element_value := read_element_value(reader, allocator) or_return
        element_value_pairs[i] = ElementValuePair { element_value_idx, element_value }
    }

    return Annotation { type_idx, element_value_pairs }, .None
}

@private
read_element_value :: proc(
    reader: ^ClassFileReader, 
    allocator := context.allocator,
) -> (
    element_value: ElementValue, 
    err: Error,
) {
    element_value_tag := read_u8(reader) or_return
    using element_value 

    switch element_value_tag {
        case 'B', 'C', 'D', 'F', 'I', 'J', 'S', 'Z', 's':
            value = ConstValueIdx(read_u16(reader) or_return)
        case 'e':
            type_name_idx := read_u16(reader) or_return
            const_name_idx := read_u16(reader) or_return
            value = EnumConstValue { type_name_idx, const_name_idx }
        case 'c':
            class_info_idx := read_u16(reader) or_return
            value = ClassInfoIdx(class_info_idx)
        case '@':
            value = read_annotation(reader) or_return
        case '[':
            num_values := read_u16(reader) or_return
            values := make([]ElementValue, num_values, allocator)
            for i in 0..<num_values {
                values[i] = read_element_value(reader, allocator) or_return
            }
            value = ArrayValue { values }
        case:
            return element_value, .UnknownElementValueTag
    }
    return element_value, .None
}

@private
read_verification_type_infos :: proc(
    reader: ^ClassFileReader, 
    count: u16, 
    allocator := context.allocator,
) -> (
    locals: []VerificationTypeInfo, 
    err: Error,
) {
    locals = make([]VerificationTypeInfo, count, allocator)
    for i in 0..<count {
        locals[i] = read_verification_type_info(reader) or_return
    }
    return locals, .None
}

@private
read_verification_type_info :: proc(reader: ^ClassFileReader) -> (info: VerificationTypeInfo, err: Error) {
    tag := read_u8(reader) or_return
    switch tag {
        case 0: info = TopVariableInfo {}
        case 1: info = IntegerVariableInfo {}
        case 2: info = FloatVariableInfo {}
        case 3: info = DoubleVariableInfo {}
        case 4: info = LongVariableInfo {}
        case 5: info = NullVariableInfo {}
        case 6: info = UninitializedThisVariableInfo {}
        case 7: 
            cp_idx := read_u16(reader) or_return
            info = ObjectVariableInfo { cp_idx }
        case 8:
            offset := read_u16(reader) or_return
            info = UninitializedVariableInfo { offset }
        case: 
            return info, .UnknownVerificationTypeInfoTag
    }
    return info, .None
}

@private
read_u8 :: proc(using reader: ^ClassFileReader) -> (u8, Error) #no_bounds_check {
    if pos >= len(bytes) {
        return 0, .UnexpectedEof
    }
    pos += 1
    return bytes[pos - 1], .None
}

@private
read_u16 :: proc(using reader: ^ClassFileReader) -> (u16, Error) #no_bounds_check {
    ret, ok := endian.get_u16(bytes[pos:], .Big)
    if !ok do return ret, .UnexpectedEof
    pos += 2
    return ret, .None
}

@private
read_u32 :: proc(using reader: ^ClassFileReader) -> (u32, Error) #no_bounds_check {
    ret, ok := endian.get_u32(bytes[pos:], .Big)
    if !ok do return ret, .UnexpectedEof
    pos += 4
    return ret, .None
}

@private
read_nbytes :: proc(using reader: ^ClassFileReader, #any_int n: int) -> ([]u8, Error) #no_bounds_check { 
    if pos + n > len(bytes) {
        return nil, .UnexpectedEof
    }
    ret := bytes[pos:][:n]
    pos += n
    return ret, .None
}

// Reads a number of bytes and reinterprets that as a slice of u16s.
// Params:
// - elem_count: the expected amount of elements in the returned slice.
//   The actual amount of read bytes will be elem_count * size_of(u16).
@private
read_u16_array :: proc(reader: ^ClassFileReader, #any_int elem_count: int) -> (
    ret: []u16,
    err: Error,
) {
    bytes := read_nbytes(reader, elem_count * size_of(u16)) or_return
    ret = slice.reinterpret([]u16, bytes)
    return ret, .None
}
