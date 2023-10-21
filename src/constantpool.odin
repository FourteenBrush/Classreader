package main

ConstantPoolEntry :: struct {
    tag: ConstantType,
    info: CPInfo,
}

// TODO: fix this awful name
CPInfo :: union #no_nil {
    DummyInfo, // meant to occupy the empry second slot of a long/ double
    ConstantUtf8Info,
    ConstantIntegerInfo, // and Float alias
    ConstantDoubleInfo, // and Long alias
    ConstantClassInfo,
    ConstantStringInfo,
    ConstantFieldRefInfo, // and MethodRef, InterfaceMethodRef alias
    ConstantNameAndTypeInfo,
    ConstantMethodHandleInfo,
    ConstantMethodTypeInfo,
    ConstantInvokeDynamicInfo,
}

DummyInfo :: struct {}

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
    bytes: []u8 `fmt:"s"`,
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
    name_idx: u16,
}

ConstantStringInfo :: struct {
    string_idx: u16,
}

ConstantFieldRefInfo :: struct {
    class_idx: u16,
    name_and_type_idx: u16,
}

ConstantMethodRefInfo :: ConstantFieldRefInfo
ConstantInterfaceMethodRefInfo :: ConstantFieldRefInfo

ConstantNameAndTypeInfo :: struct {
    name_idx: u16,
    // Points to a ConstantUtf8Info entry
    // representing a field or method descriptor
    descriptor_idx: u16,
}

ConstantMethodHandleInfo :: struct {
    reference_kind: ReferenceKind,
    reference_idx: u16,
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
    descriptor_idx: u16,
}

ConstantInvokeDynamicInfo :: struct {
    bootstrap_method_attr_idx: u16,
    name_and_type_idx: u16,
}
