package main

ClassFileReader :: struct {
    bytes: []u8,
    pos: int,
}

reader_new :: proc(bytes: []u8) -> ClassFileReader {
    return ClassFileReader { bytes, 0 }
}

HEADER_MAGIC :: 0xCAFEBABE

reader_read_class_file :: proc(using reader: ^ClassFileReader) -> (classfile: ClassFile, err: Errno) {
    magic := read_unsigned_int(reader) or_return
    if magic != HEADER_MAGIC {
        return classfile, .InvalidHeader
    }

    classfile.minor_version = read_unsigned_short(reader) or_return
    classfile.major_version = read_unsigned_short(reader) or_return
    classfile.constant_pool_count = read_unsigned_short(reader) or_return
    classfile.constant_pool = make([]ConstantPoolInfo, classfile.constant_pool_count)
    read_constant_pool(reader, &classfile) or_return

    classfile.access_flags = read_unsigned_short(reader) or_return
    classfile.this_class = read_unsigned_short(reader) or_return
    classfile.super_class = read_unsigned_short(reader) or_return

    classfile.interfaces_count = read_unsigned_short(reader) or_return
    classfile.interfaces = make([]u16, classfile.interfaces_count)
    read_interfaces(reader, &classfile)

    classfile.fields_count = read_unsigned_short(reader) or_return
    classfile.fields = make([]FieldInfo, classfile.fields_count)
    read_fields(reader, &classfile) or_return

    classfile.methods_count = read_unsigned_short(reader) or_return
    classfile.methods = make([]MethodInfo, classfile.methods_count)
    read_methods(reader, &classfile)

    classfile.attributes_count = read_unsigned_short(reader) or_return
    classfile.attributes = make([]AttributeInfo, classfile.attributes_count)
    read_attributes(reader, classfile.attributes, int(classfile.attributes_count)) or_return

    return
}

Errno :: enum {
    None,
    // Magic number was not present in the file header
    InvalidHeader,
    // Expected more bytes
    UnexpectedEof,
    // Constant pool index is invalid
    InvalidCPIndex,
    // Constant pool index points to an entry with the wrong type
    WrongCPType,
}

@private
read_constant_pool :: proc(reader: ^ClassFileReader, using classfile: ^ClassFile) -> Errno {
    for i in 0..<constant_pool_count - 1 {
        entry := read_constant_pool_entry(reader) or_return
        constant_pool[i] = entry
    }
    return .None
}

@private
read_constant_pool_entry :: proc(reader: ^ClassFileReader) -> (entry: ConstantPoolInfo, err: Errno) {
    tag := ConstantType(read_unsigned_byte(reader) or_return)
    info: CPInfo

    switch tag {
        case .Utf8:
            length := read_unsigned_short(reader) or_return
            bytes := read_nbytes(reader, int(length)) or_return
            info = ConstantUtf8Info { length, bytes }
        case .Integer:
            value := read_unsigned_int(reader) or_return
            info = ConstantIntegerInfo { value }
        case .Float:
            value := read_unsigned_int(reader) or_return
            info = ConstantFloatInfo { value }
        case .Long, .Double:
            high_bytes := read_unsigned_int(reader) or_return
            low_bytes := read_unsigned_int(reader) or_return
            info = ConstantLongInfo { high_bytes, low_bytes }
        case .Class:
            name_index := read_unsigned_short(reader) or_return
            info = ConstantClassInfo { name_index }
        case .String:
            string_index := read_unsigned_short(reader) or_return
            info = ConstantStringInfo { string_index }
        case .FieldRef, .MethodRef, .InterfaceMethodRef:
            class_index := read_unsigned_short(reader) or_return
            name_and_type_index := read_unsigned_short(reader) or_return
            info = ConstantFieldRefInfo { class_index, name_and_type_index }
        case .NameAndType:
            reference_kind := read_unsigned_short(reader) or_return
            descriptor_index := read_unsigned_short(reader) or_return
            info = ConstantNameAndTypeInfo { reference_kind, descriptor_index }
        case .MethodHandle:
            reference_kind := ReferenceKind(read_unsigned_byte(reader) or_return)
            reference_index := read_unsigned_short(reader) or_return
            info = ConstantMethodHandleInfo { reference_kind, reference_index }
        case .MethodType:
            descriptor_index := read_unsigned_short(reader) or_return
            info = ConstantMethodTypeInfo { descriptor_index }
        case .InvokeDynamic:
            bootstrap_method_attr_index := read_unsigned_short(reader) or_return
            name_and_type_index := read_unsigned_short(reader) or_return
    }
    return ConstantPoolInfo { tag, info }, .None
}

@private
read_interfaces :: proc(reader: ^ClassFileReader, using classfile: ^ClassFile) -> Errno {
    for i in 0..<interfaces_count {
        interface := read_unsigned_short(reader) or_return
        interfaces[i] = interface
    } 
    return .None
}

@private
read_methods :: proc(reader: ^ClassFileReader, using classfile: ^ClassFile) -> Errno {
    for i in 0..<methods_count {
        access_flags := read_unsigned_short(reader) or_return
        name_index := read_unsigned_short(reader) or_return
        descriptor_index := read_unsigned_short(reader) or_return
        attributes_count := read_unsigned_short(reader) or_return
        attributes := make([]AttributeInfo, attributes_count)
        for j in 0..<attributes_count {
            attributes[j] = read_attribute(reader) or_return
        }

        methods[i] = MethodInfo {
            access_flags,
            name_index,
            descriptor_index,
            attributes_count,
            attributes,
        }
    }
    return .None
}

@private
read_fields :: proc(reader: ^ClassFileReader, using classfile: ^ClassFile) -> Errno {
    for i in 0..<fields_count {
        access_flags := read_unsigned_short(reader) or_return
        name_index := read_unsigned_short(reader) or_return
        descriptor_index := read_unsigned_short(reader) or_return
        attributes_count := read_unsigned_short(reader) or_return

        for j in 0..<attributes_count {
            fields[i] = FieldInfo {
                access_flags, name_index,
                descriptor_index, attributes_count,
                make([]AttributeInfo, attributes_count),
            }
            read_attributes(reader, fields[i].attributes, int(attributes_count))
        }
    }
    return .None
}

@private
read_attributes :: proc(reader: ^ClassFileReader, dest: []AttributeInfo, count: int) -> Errno {
    for i in 0..<count {
        dest[i] = read_attribute(reader) or_return
    }
    return .None
}

@private
read_attribute :: proc(reader: ^ClassFileReader) -> (attrib: AttributeInfo, err: Errno) {
    attrib.attribute_name_index = read_unsigned_short(reader) or_return
    attrib.attribute_length = read_unsigned_short(reader) or_return
    attrib.info = make([]u8, attrib.attribute_length)
    return attrib, .None
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
    if pos + 1 >= len(bytes) {
         return 0, .UnexpectedEof
    }
    res := (u16(bytes[pos]) << 8) | u16(bytes[pos + 1])
    pos += 2
    return res, .None
}

@private
read_unsigned_int :: proc(using reader: ^ClassFileReader) -> (u32, Errno) #no_bounds_check {
    if pos + 3 >= len(bytes) {
        return 0, .UnexpectedEof
    }
    res := (u32(bytes[pos]) << 24) | (u32(bytes[pos + 1]) << 16) | (u32(bytes[pos + 2]) << 8) | u32(bytes[pos + 3])
    pos += 4
    return res, .None
}

@private
read_nbytes :: proc(using reader: ^ClassFileReader, n: int) -> ([]u8, Errno) { 
    if pos + n >= len(bytes) {
        return nil, .UnexpectedEof
    }
    res := bytes[pos:pos + n]
    pos += n
    return res, .None
}
