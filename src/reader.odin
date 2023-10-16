package main

import "core:fmt"

ClassFileReader :: struct {
    bytes: []u8,
    pos: int,
}

reader_new :: #force_inline proc(bytes: []u8) -> ClassFileReader {
    return ClassFileReader { bytes, 0 }
}

@private
HEADER_MAGIC :: 0xCAFEBABE

reader_read_class_file :: proc(using reader: ^ClassFileReader) -> (classfile: ClassFile, err: Errno) {
    magic := read_unsigned_int(reader) or_return
    if magic != HEADER_MAGIC {
        return classfile, .InvalidHeader
    }

    classfile.minor_version = read_unsigned_short(reader) or_return
    classfile.major_version = read_unsigned_short(reader) or_return
    classfile.constant_pool_count = read_unsigned_short(reader) or_return
    fmt.println("constant_pool_count:", classfile.constant_pool_count)
    classfile.constant_pool = read_constant_pool(reader, int(classfile.constant_pool_count)) or_return

    classfile.access_flags = read_unsigned_short(reader) or_return
    classfile.this_class = read_unsigned_short(reader) or_return
    classfile.super_class = read_unsigned_short(reader) or_return

    classfile.interfaces_count = read_unsigned_short(reader) or_return
    classfile.interfaces = read_interfaces(reader, int(classfile.interfaces_count)) or_return

    classfile.fields_count = read_unsigned_short(reader) or_return
    fmt.printf("fields_count: %i\n", classfile.fields_count)
    classfile.fields = read_fields(reader, int(classfile.fields_count)) or_return

    classfile.methods_count = read_unsigned_short(reader) or_return
    fmt.printf("methods_count: %i\n", classfile.methods_count)
    classfile.methods = read_methods(reader, int(classfile.methods_count)) or_return

    fmt.printf("[%i/%i]\n", pos, len(bytes))

    classfile.attributes_count = read_unsigned_short(reader) or_return
    classfile.attributes = read_attributes(reader, int(classfile.attributes_count)) or_return
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
read_constant_pool :: proc(reader: ^ClassFileReader, count: int) -> (constant_pool: []ConstantPoolEntry, err: Errno) {
    constant_pool = make([]ConstantPoolEntry, count - 1)

    for i := 0; i < count - 2; i += 1 {
        tag := ConstantType(read_unsigned_byte(reader) or_return)
        entry, err := read_constant_pool_entry(reader, tag)
        if err != .None {
            fmt.eprintln(" err: failed to read entry:", tag)
            break
        }

        constant_pool[i] = ConstantPoolEntry { tag, entry }
        if tag == .Double || tag == .Float {
            fmt.println("got a float or double at idx", i)
            // i += 1
            fmt.println("pos now at", reader.pos)
        }
    }
    return constant_pool, .None
}

@private
read_constant_pool_entry :: proc(reader: ^ClassFileReader, tag: ConstantType) -> (entry: CPInfo, err: Errno) {
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
            name_idx := read_unsigned_short(reader) or_return
            info = ConstantClassInfo { name_idx }
        case .String:
            string_idx := read_unsigned_short(reader) or_return
            info = ConstantStringInfo { string_idx }
        case .FieldRef, .MethodRef, .InterfaceMethodRef:
            class_idx := read_unsigned_short(reader) or_return
            name_and_type_idx := read_unsigned_short(reader) or_return
            info = ConstantFieldRefInfo { class_idx, name_and_type_idx }
        case .NameAndType:
            name_idx := read_unsigned_short(reader) or_return
            descriptor_idx := read_unsigned_short(reader) or_return
            info = ConstantNameAndTypeInfo { name_idx, descriptor_idx }
        case .MethodHandle:
            reference_kind := ReferenceKind(read_unsigned_byte(reader) or_return)
            reference_idx := read_unsigned_short(reader) or_return
            info = ConstantMethodHandleInfo { reference_kind, reference_idx }
        case .MethodType:
            descriptor_idx := read_unsigned_short(reader) or_return
            info = ConstantMethodTypeInfo { descriptor_idx }
        case .InvokeDynamic:
            bootstrap_method_attr_idx := read_unsigned_short(reader) or_return
            name_and_type_idx := read_unsigned_short(reader) or_return
            info = ConstantInvokeDynamicInfo { bootstrap_method_attr_idx, name_and_type_idx }
    }
    return info, .None
}

@private
read_interfaces :: proc(reader: ^ClassFileReader, count: int) -> (interfaces: []u16, err: Errno) {
    interfaces = make([]u16, count)

    for i in 0..<count {
        interfaces[i] = read_unsigned_short(reader) or_return
    }
    return interfaces, .None
}

@private
read_methods :: proc(reader: ^ClassFileReader, count: int) -> (methods: []MethodInfo, err: Errno) {
    methods = make([]MethodInfo, count)

    for i in 0..<count {
        access_flags := read_unsigned_short(reader) or_return
        name_idx := read_unsigned_short(reader) or_return
        descriptor_idx := read_unsigned_short(reader) or_return
        attributes_count := read_unsigned_short(reader) or_return
        attributes := read_attributes(reader, int(attributes_count)) or_return

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
read_fields :: proc(reader: ^ClassFileReader, count: int) -> (fields: []FieldInfo, err: Errno) {
    fields = make([]FieldInfo, count)

    for i in 0..<count {
        access_flags := read_unsigned_short(reader) or_return
        name_idx := read_unsigned_short(reader) or_return
        descriptor_idx := read_unsigned_short(reader) or_return
        attributes_count := read_unsigned_short(reader) or_return

        fields[i] = FieldInfo {
            access_flags, name_idx,
            descriptor_idx, attributes_count,
            read_attributes(reader, int(attributes_count)) or_return,
        }
    }
    return fields, .None
}

@private
read_attributes :: proc(reader: ^ClassFileReader, count: int) -> (attributes: []AttributeInfo, err: Errno) {
    attributes = make([]AttributeInfo, count)
    
    for i in 0..<count {
        name_idx := read_unsigned_short(reader) or_return
        length := read_unsigned_short(reader) or_return
        info := make([]u8, length)
        attributes[i] = AttributeInfo { name_idx, length, info }
    }
    return attributes, .None
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
