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
    fields = read_fields(reader, int(fields_count)) or_return

    methods_count = read_unsigned_short(reader) or_return
    methods = read_methods(reader, int(methods_count)) or_return

    attributes_count = read_unsigned_short(reader) or_return
    attributes = read_attributes(reader, int(attributes_count)) or_return
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
}

@private
read_constant_pool :: proc(reader: ^ClassFileReader, count: int) -> (constant_pool: []ConstantPoolEntry, err: Errno) {
    constant_pool = make([]ConstantPoolEntry, count - 1) // omit first entry

    for i := 0; i < count - 1; i += 1 {
        tag := ConstantType(read_unsigned_byte(reader) or_return)
        if tag == ConstantType(0) {
            fmt.printf("tag %v\n", tag)
            panic("trap")
        }
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
read_nbytes :: proc(using reader: ^ClassFileReader, n: int) -> ([]u8, Errno) { 
    if pos + n >= len(bytes) {
        return nil, .UnexpectedEof
    }
    res := bytes[pos:][:n]
    pos += n
    return res, .None
}
