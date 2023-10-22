package classreader

import "core:fmt"
import "core:encoding/endian"

ClassFileReader :: struct {
    bytes: []u8,
    pos: int,
}

reader_new :: proc(bytes: []u8) -> ClassFileReader {
    return ClassFileReader { bytes, 0 }
}

@private
MAGIC :: 0xCAFEBABE

reader_read_class_file :: proc(using reader: ^ClassFileReader) -> (classfile: ClassFile, err: Errno) {
    magic := read_unsigned_int(reader) or_return
    if magic != MAGIC {
        return classfile, .InvalidHeader
    }

    using classfile
    minor_version = read_unsigned_short(reader) or_return
    major_version = read_unsigned_short(reader) or_return
    constant_pool_count = read_unsigned_short(reader) or_return
    constant_pool = read_constant_pool(reader, int(constant_pool_count)) or_return

    access_flags = read_unsigned_short(reader) or_return
    this_class = read_unsigned_short(reader) or_return
    super_class = read_unsigned_short(reader) or_return

    interfaces_count = read_unsigned_short(reader) or_return
    interfaces = read_interfaces(reader, int(interfaces_count)) or_return

    fields_count = read_unsigned_short(reader) or_return
    fields = read_fields(reader, int(fields_count), &classfile) or_return

    methods_count = read_unsigned_short(reader) or_return
    methods = read_methods(reader, int(methods_count), &classfile) or_return

    attributes_count = read_unsigned_short(reader) or_return
    attributes = read_attributes(reader, int(attributes_count), &classfile) or_return
    return
}

Errno :: enum {
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
    // unknown verification_type_info tag
    UnknownVerificationType,
    // unknown attribute name
    UnknownAttribute,
}

@private
read_constant_pool :: proc(reader: ^ClassFileReader, count: int) -> (constant_pool: []ConstantPoolEntry, err: Errno) {
    constant_pool = make([]ConstantPoolEntry, count - 1) // omit first entry

    for i := 0; i < count - 1; i += 1 {
        tag := ConstantType(read_unsigned_byte(reader) or_return)
        entry := read_constant_pool_entry(reader, tag) or_return

        constant_pool[i] = ConstantPoolEntry { tag, entry }
        if tag == .Double || tag == .Long {
            // ConstantType(0) does not exist, but doesn't matter because it's never printed
            constant_pool[i + 1] = ConstantPoolEntry { ConstantType(0), DummyInfo{} }
            i += 1
        }
    }
    return constant_pool, .None
}

@private
read_constant_pool_entry :: proc(reader: ^ClassFileReader, tag: ConstantType) -> (entry: CPInfo, err: Errno) {
    switch tag {
        case .Utf8:
            length := read_unsigned_short(reader) or_return
            bytes := read_nbytes(reader, int(length)) or_return
            entry = ConstantUtf8Info { length, bytes }
        case .Integer, .Float:
            bytes := read_unsigned_int(reader) or_return
            entry = ConstantIntegerInfo { bytes }
        case .Long, .Double:
            high_bytes := read_unsigned_int(reader) or_return
            low_bytes := read_unsigned_int(reader) or_return
            entry = ConstantLongInfo { high_bytes, low_bytes }
        case .Class:
            name_idx := read_unsigned_short(reader) or_return
            entry = ConstantClassInfo { name_idx }
        case .String:
            string_idx := read_unsigned_short(reader) or_return
            entry = ConstantStringInfo { string_idx }
        case .FieldRef, .MethodRef, .InterfaceMethodRef:
            class_idx := read_unsigned_short(reader) or_return
            name_and_type_idx := read_unsigned_short(reader) or_return
            entry = ConstantFieldRefInfo { class_idx, name_and_type_idx }
        case .NameAndType:
            name_idx := read_unsigned_short(reader) or_return
            descriptor_idx := read_unsigned_short(reader) or_return
            entry = ConstantNameAndTypeInfo { name_idx, descriptor_idx }
        case .MethodHandle:
            reference_kind := ReferenceKind(read_unsigned_byte(reader) or_return)
            reference_idx := read_unsigned_short(reader) or_return
            entry = ConstantMethodHandleInfo { reference_kind, reference_idx }
        case .MethodType:
            descriptor_idx := read_unsigned_short(reader) or_return
            entry = ConstantMethodTypeInfo { descriptor_idx }
        case .InvokeDynamic:
            bootstrap_method_attr_idx := read_unsigned_short(reader) or_return
            name_and_type_idx := read_unsigned_short(reader) or_return
            entry = ConstantInvokeDynamicInfo { bootstrap_method_attr_idx, name_and_type_idx }
    }
    return entry, .None
}

@private
read_interfaces :: proc(reader: ^ClassFileReader, count: int) -> (interfaces: []u16, err: Errno) {
    // TODO: transmute byte array instead
    interfaces = make([]u16, count)

    for i in 0..<count {
        interfaces[i] = read_unsigned_short(reader) or_return
    }
    return interfaces, .None
}

@private
read_methods :: proc(reader: ^ClassFileReader, count: int, classfile: ^ClassFile) -> (methods: []MethodInfo, err: Errno) {
    methods = make([]MethodInfo, count)

    for i in 0..<count {
        access_flags := read_unsigned_short(reader) or_return
        name_idx := read_unsigned_short(reader) or_return
        descriptor_idx := read_unsigned_short(reader) or_return
        attributes_count := read_unsigned_short(reader) or_return
        attributes := read_attributes(reader, int(attributes_count), classfile) or_return

        methods[i] = MethodInfo {
            access_flags,
            name_idx,
            descriptor_idx,
            attributes_count,
            attributes,
        }
    }
    return methods, .None
}

@private
read_fields :: proc(reader: ^ClassFileReader, count: int, classfile: ^ClassFile) -> (fields: []FieldInfo, err: Errno) {
    fields = make([]FieldInfo, count)

    for i in 0..<count {
        access_flags := read_unsigned_short(reader) or_return
        name_idx := read_unsigned_short(reader) or_return
        descriptor_idx := read_unsigned_short(reader) or_return
        attributes_count := read_unsigned_short(reader) or_return

        fields[i] = FieldInfo {
            access_flags, name_idx,
            descriptor_idx, attributes_count,
            read_attributes(reader, int(attributes_count), classfile) or_return,
        }
    }
    return fields, .None
}

@private
read_attributes :: proc(reader: ^ClassFileReader, count: int, classfile: ^ClassFile) -> (attributes: []AttributeInfo, err: Errno) {
    attributes = make([]AttributeInfo, count)
    
    for i in 0..<count {
        attributes[i] = read_attribute_info(reader, classfile) or_return
    }
    return attributes, .None
}

@private
read_attribute_info :: proc(reader: ^ClassFileReader, classfile: ^ClassFile) -> (attribute: AttributeInfo, err: Errno) {
    name_idx := read_unsigned_short(reader) or_return
    length := read_unsigned_int(reader) or_return
    inner: AttributeInfoInner

    attrib_name := cp_get_str(classfile, name_idx)

    switch attrib_name {
        case "ConstantValue":
            constantvalue_idx := read_unsigned_short(reader) or_return
            inner = ConstantValue { constantvalue_idx }
        case "Code":
            max_stack := read_unsigned_short(reader) or_return
            max_locals := read_unsigned_short(reader) or_return
            code_length := read_unsigned_int(reader) or_return
            code := read_nbytes(reader, int(code_length)) or_return
            exception_table_length := read_unsigned_short(reader) or_return
            exception_table := make([]ExceptionHandler, exception_table_length)

            for i in 0..<exception_table_length {
                start_pc := read_unsigned_short(reader) or_return
                end_pc := read_unsigned_short(reader) or_return
                handler_pc := read_unsigned_short(reader) or_return
                catch_type := read_unsigned_short(reader) or_return
                exception_table[i] = { start_pc, end_pc, handler_pc, catch_type }
            }

            attributes_count := read_unsigned_short(reader) or_return
            attributes := read_attributes(reader, int(attributes_count), classfile) or_return
            inner = Code {
                max_stack, max_locals,
                code_length, code,
                exception_table_length, exception_table,
                attributes_count, attributes,
            }
        case "StackMapTable":
            number_of_entries := read_unsigned_short(reader) or_return
            entries := make([]StackMapFrame, number_of_entries)

            for i in 0..<number_of_entries {
                frame_type := read_unsigned_byte(reader) or_return
                switch frame_type {
                    case 0..=63:
                        entries[i] = SameFrame {}
                    case 64..=127:
                        stack := read_verification_type_info(reader) or_return
                        entries[i] = SameLocals1StackItemFrame { stack }
                    case 247:
                        offset_delta := read_unsigned_short(reader) or_return
                        stack := read_verification_type_info(reader) or_return
                        entries[i] = SameLocals1StackItemFrameExtended { offset_delta, stack }
                    case 248..=250:
                        offset_delta := read_unsigned_short(reader) or_return
                        entries[i] = ChopFrame { offset_delta }
                    case 251:
                        offset_delta := read_unsigned_short(reader) or_return
                        entries[i] = SameFrameExtended { offset_delta }
                    case 252..=254:
                        offset_delta := read_unsigned_short(reader) or_return
                        locals := make([]VerificationTypeInfo, frame_type - 251)
                        for j in 0..<len(locals) {
                            locals[j] = read_verification_type_info(reader) or_return
                        }
                        entries[i] = AppendFrame { offset_delta, locals }
                    case 255:
                        offset_delta := read_unsigned_short(reader) or_return
                        number_of_locals := read_unsigned_short(reader) or_return
                        locals := read_verification_type_infos(reader, number_of_locals) or_return
                        number_of_stack_items := read_unsigned_short(reader) or_return
                        stack := read_verification_type_infos(reader, number_of_stack_items) or_return
                        entries[i] = FullFrame {
                            offset_delta,
                            number_of_locals, locals,
                            number_of_stack_items, stack,
                        }
                }
            }
            inner = StackMapTable { number_of_entries, entries }
        case "Exceptions":
            number_of_exceptions := read_unsigned_short(reader) or_return
            exception_idx_table := make([]u16, number_of_exceptions)

            for j in 0..<number_of_exceptions {
                exception_idx_table[j] = read_unsigned_short(reader) or_return
            }
            inner = Exceptions { number_of_exceptions, exception_idx_table }
        case "InnerClasses":
            number_of_classes := read_unsigned_short(reader) or_return
            classes := make([]InnerClassEntry, number_of_classes)

            for i in 0..<number_of_classes {
                inner_class_info_idx := read_unsigned_short(reader) or_return
                outer_class_info_idx := read_unsigned_short(reader) or_return
                name_idx := read_unsigned_short(reader) or_return
                access_flags := read_unsigned_short(reader) or_return
                classes[i] = InnerClassEntry {
                    inner_class_info_idx,
                    outer_class_info_idx,
                    name_idx, access_flags,
                }
            }
            inner = InnerClasses { number_of_classes, classes }
        case "EnclosingMethod":
            class_idx := read_unsigned_short(reader) or_return
            method_idx := read_unsigned_short(reader) or_return
            inner = EnclosingMethod { class_idx, method_idx }
        case "Synthetic": inner = Synthetic {}
        case "Signature": 
            signature_idx := read_unsigned_short(reader) or_return
            inner = Signature { signature_idx }
        case "SourceFile": 
            sourcefile_idx := read_unsigned_short(reader) or_return
            inner = SourceFile { sourcefile_idx }
        case "SourceDebugExtension":
            debug_extension := read_nbytes(reader, int(length)) or_return
            inner = SourceDebugExtension { debug_extension }
        case "LineNumberTable":
            table_length := read_unsigned_short(reader) or_return
            table := make([]LineNumberTableEntry, table_length)
            for i in 0..<table_length {
                start_pc := read_unsigned_short(reader) or_return
                line_number := read_unsigned_short(reader) or_return
                table[i] = LineNumberTableEntry { start_pc, line_number }
            }
            inner = LineNumberTable { table_length, table }
        case "LocalVariableTable":
            table_length := read_unsigned_short(reader) or_return
            table := make([]LocalVariableTableEntry, table_length)
            for i in 0..<table_length {
                start_pc := read_unsigned_short(reader) or_return
                length := read_unsigned_short(reader) or_return
                name_idx := read_unsigned_short(reader) or_return
                descriptor_idx := read_unsigned_short(reader) or_return
                idx := read_unsigned_short(reader) or_return
                table[i] = LocalVariableTableEntry {
                    start_pc, length,
                    name_idx, descriptor_idx,
                    idx,
                }
            }
            inner = LocalVariableTable  { table_length, table }
        case "LocalVariableTypeTable":
            table_length := read_unsigned_short(reader) or_return
            table := make([]LocalVariableTypeTableEntry, table_length)
            for i in 0..<table_length {
                start_pc := read_unsigned_short(reader) or_return
                length := read_unsigned_short(reader) or_return
                name_idx := read_unsigned_short(reader) or_return
                signature_idx := read_unsigned_short(reader) or_return
                idx := read_unsigned_short(reader) or_return
                table[i] = LocalVariableTypeTableEntry {
                    start_pc, length,
                    name_idx, signature_idx,
                    idx,
                }
            }
            inner = LocalVariableTypeTable { table_length, table }
        case "Deprecated": inner = Deprecated {}
        case "RuntimeVisibleAnnotations":
            num_annotations := read_unsigned_short(reader) or_return
            annotations := read_annotations(reader) or_return
            inner = RuntimeVisibleAnnotations { num_annotations, annotations }
        case "RuntimeInvisibleAnnotations":
            annotations := read_annotations(reader) or_return
            inner = RuntimeInvisibleAnnotations { u16(len(annotations)), annotations }
        case "RuntimeVisibleParameterAnnotations":
            parameter_annotations := read_parameter_annotations(reader) or_return
            inner = RuntimeVisibleParameterAnnotations { u8(len(parameter_annotations)), parameter_annotations }
        case "RuntimeInvisibleParameterAnnotations":
            parameter_annotations := read_parameter_annotations(reader) or_return
            inner = RuntimeInvisibleParameterAnnotations { u8(len(parameter_annotations)), parameter_annotations }
        case "AnnotationDefault":
            default_value := read_element_value(reader) or_return
            inner := AnnotationDefault { default_value }
        case "BootstrapMethods":
            num_bootstrap_methods := read_unsigned_short(reader) or_return
            bootstrap_methods := make([]BootstrapMethod, num_bootstrap_methods)

            for i in 0..<num_bootstrap_methods {
                bootstrap_method_ref := read_unsigned_short(reader) or_return
                num_bootstrap_arguments := read_unsigned_short(reader) or_return
                bootstrap_arguments := make([]u16, num_bootstrap_arguments)

                for j in 0..<num_bootstrap_arguments {
                    bootstrap_arguments[j] = read_unsigned_short(reader) or_return
                }

                bootstrap_methods[i] = BootstrapMethod {
                    bootstrap_method_ref,
                    num_bootstrap_arguments,
                    bootstrap_arguments,
                }
            }
            inner = BootstrapMethods { num_bootstrap_methods, bootstrap_methods }
        case: return attribute, .UnknownAttribute
    }
    return AttributeInfo { name_idx, length, inner }, .None
}

@private
read_parameter_annotations :: proc(reader: ^ClassFileReader) -> (param_annotations: []ParameterAnnotation, err: Errno) {
    num_parameters := read_unsigned_byte(reader) or_return
    param_annotations = make([]ParameterAnnotation, num_parameters)

    for i in 0..<num_parameters {
        num_annotations := read_unsigned_short(reader) or_return
        annotations := read_annotations(reader) or_return
        param_annotations[i] = ParameterAnnotation { num_annotations, annotations }
    }

    return param_annotations, .None
}

@private
read_annotations :: proc(reader: ^ClassFileReader) -> (annotations: []Annotation, err: Errno) {
    num_annotations := read_unsigned_short(reader) or_return
    annotations = make([]Annotation, num_annotations)

    for i in 0..<num_annotations {
        annotations[i] = read_annotation(reader) or_return
    }
    return annotations, .None
}

@private
read_annotation :: proc(reader: ^ClassFileReader) -> (annotation: Annotation, err: Errno) {
    type_idx := read_unsigned_short(reader) or_return
    element_value_pairs := read_annotation_element_value_pairs(reader) or_return

    return Annotation { type_idx, u16(len(element_value_pairs)), element_value_pairs }, .None
}

@private
read_annotation_element_value_pairs :: proc(reader: ^ClassFileReader) -> (element_value_pairs: []ElementValuePair, err: Errno) {
    num_element_value_pairs := read_unsigned_short(reader) or_return
    element_value_pairs = make([]ElementValuePair, num_element_value_pairs)

    for i in 0..<num_element_value_pairs {
        element_value_idx := read_unsigned_short(reader) or_return
        element_value := read_element_value(reader) or_return
        element_value_pairs[i] = ElementValuePair { element_value_idx, element_value }
    }
    return element_value_pairs, .None
}

@private
read_element_value :: proc(reader: ^ClassFileReader) -> (element_value: ElementValue, err: Errno) {
    element_value_tag := read_unsigned_byte(reader) or_return
    using element_value 

    switch element_value_tag {
        case 'B', 'C', 'D', 'F', 'I', 'J', 'S', 'Z', 's':
            value.const_value_idx = read_unsigned_short(reader) or_return
        case 'e':
            type_name_idx := read_unsigned_short(reader) or_return
            const_name_idx := read_unsigned_short(reader) or_return
            value.enum_const_value = EnumConstValue { type_name_idx, const_name_idx }
        case 'c':
            class_info_idx := read_unsigned_short(reader) or_return
            value.class_info_idx = class_info_idx
        case '@':
            value.annotation_value = read_annotation(reader) or_return
        case '[':
            num_values := read_unsigned_short(reader) or_return
            values := make([]ElementValue, num_values)
            for i in 0..<num_values {
                values[i] = read_element_value(reader) or_return
            }
            value.array_value = ArrayValue { num_values, values }
    }
    return element_value, .None
}

@private
read_verification_type_infos :: proc(reader: ^ClassFileReader, count: u16) -> (locals: []VerificationTypeInfo, err: Errno) {
    locals = make([]VerificationTypeInfo, count)
    for i in 0..<count {
        locals[i] = read_verification_type_info(reader) or_return
    }
    return locals, .None
}

@private
read_verification_type_info :: proc(reader: ^ClassFileReader) -> (info: VerificationTypeInfo, err: Errno) {
    tag := read_unsigned_byte(reader) or_return
    switch tag {
        case 0: info = TopVariableInfo {}
        case 1: info = IntegerVariableInfo {}
        case 2: info = FloatVariableInfo {}
        case 3: info = DoubleVariableInfo {}
        case 4: info = LongVariableInfo {}
        case 5: info = NullVariableInfo {}
        case 6: info = UninitializedThisVariableInfo {}
        case 7: 
            cp_idx := read_unsigned_short(reader) or_return
            info = ObjectVariableInfo { cp_idx }
        case 8:
            offset := read_unsigned_short(reader) or_return
            info = UninitializedVariableInfo { offset }
        case: return info, .UnknownVerificationType
    }
    return info, .None
}

@private
read_all :: proc($T: typeid, reader: ^ClassFileReader, count: u16, fn: proc(^ClassFileReader) -> (T, Errno)) -> (ret: []T, err: Errno) {
    ret = make([]T, count)
    for i in 0..<count {
        ret[i] = fn(reader) or_return
    }
    return ret, .None
}

@private
read_unsigned_byte :: proc(using reader: ^ClassFileReader) -> (u8, Errno) #no_bounds_check {
    if pos >= len(bytes) {
        return 0, .UnexpectedEof
    }
    pos += 1
    return bytes[pos - 1], .None
}

@private
read_unsigned_short :: proc(using reader: ^ClassFileReader) -> (u16, Errno) #no_bounds_check {
    ret, ok := endian.get_u16(bytes[pos:], .Big)
    if !ok do return ret, .UnexpectedEof
    pos += 2
    return ret, .None
}

@private
read_unsigned_int :: proc(using reader: ^ClassFileReader) -> (u32, Errno) #no_bounds_check {
    ret, ok := endian.get_u32(bytes[pos:], .Big)
    if !ok do return ret, .UnexpectedEof
    pos += 4
    return ret, .None
}

@private
read_nbytes :: proc(using reader: ^ClassFileReader, n: int) -> ([]u8, Errno) #no_bounds_check { 
    if pos + n > len(bytes) {
        return nil, .UnexpectedEof
    }
    res := bytes[pos:][:n]
    pos += n
    return res, .None
}
