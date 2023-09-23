package main

ConstantPoolInfo :: struct {
    tag: ConstantType,
    info: CPInfo,
}

CPInfo :: union {
    ConstantUtf8Info,
    ConstantIntegerInfo, // and Float alias
    ConstantDoubleInfo,
    ConstantClassInfo,
    ConstantStringInfo,
    ConstantFieldRefInfo, // and MethodRef, InterfaceMethodRef alias
    ConstantNameAndTypeInfo,
    ConstantMethodHandleInfo,
    ConstantMethodTypeInfo,
}

ConstantType :: enum u8 {
    Utf8 = 1,
    Integer = 3,
    Float = 4,
    Long = 5,
    Double = 6,
    Class = 7,
    String = 8,
    FieldRef = 9,
    MethodRef = 10,
    InterfaceMethodRef = 11,
    NameAndType = 12,
    MethodHandle = 15,
    MethodType = 16,
    InvokeDynamic = 18,
}

ConstantUtf8Info :: struct {
    length: u16,
    bytes: []u8,
}

ConstantIntegerInfo :: struct {
    bytes: u32,
}

ConstantFloatInfo :: ConstantIntegerInfo

ConstantLongInfo :: struct {
    high_bytes: u32,
    low_bytes: u32,
}

ConstantDoubleInfo :: ConstantLongInfo

ConstantClassInfo :: struct {
    name_index: u16,
}

ConstantStringInfo :: struct {
    string_index: u16,
}

ConstantFieldRefInfo :: struct {
    class_index: u16,
    name_and_type_index: u16,
}

ConstantMethodRefInfo :: ConstantFieldRefInfo
ConstantInterfaceMethodRefInfo :: ConstantFieldRefInfo

ConstantNameAndTypeInfo :: struct {
    name_index: u16,
    // points to a ConstantUtf8Info entry in the cp
    // representing a field or method descriptor
    descriptor_index: u16,
}

ConstantMethodHandleInfo :: struct {
    reference_kind: ReferenceKind,
    reference_index: u16,
}

ReferenceKind :: enum u8 {
    GetField = 1,
    GetStatic = 2,
    PutField = 3,
    PutStatic = 4,
    InvokeVirtual = 5,
    InvokeStatic = 6,
    InvokeSpecial = 7,
    NewInvokeSpecial = 8,
    InvokeInterface = 9,
}

ConstantMethodTypeInfo :: struct {
    descriptor_index: u16,
}

ConstantInvokeDynamicInfo :: struct {
    bootstrap_method_attr_index: u16,
    name_and_type_index: u16,
}
