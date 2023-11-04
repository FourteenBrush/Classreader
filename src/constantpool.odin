package classreader

// A constantpool entry, consists of a one byte tag and the actual value.
ConstantPoolEntry :: struct {
    tag: ConstantType,
    info: CPInfo,
}

CPInfo :: union #no_nil {
    // meant to occupy the empty second slot of a long/ double
    DummyInfo,
    ConstantUtf8Info,
    ConstantIntegerInfo,   
    ConstantFloatInfo,
    ConstantLongInfo,
    ConstantDoubleInfo,         // and Long alias
    ConstantClassInfo,
    ConstantStringInfo,
    ConstantFieldRefInfo,       // and MethodRef, InterfaceMethodRef alias
    ConstantNameAndTypeInfo,
    ConstantMethodHandleInfo,
    ConstantMethodTypeInfo,
    ConstantInvokeDynamicInfo,
}

// A dummy CPInfo to insert after entries where the second slot is unusable (float and long).
DummyInfo :: struct {}

// A ConstantPoolEntry tag.
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
    bytes: []u8 `fmt:"s"`,
}

ConstantIntegerInfo :: struct {
    bytes: u32,
}

ConstantFloatInfo :: distinct ConstantIntegerInfo

ConstantLongInfo :: struct {
    high_bytes: u32,
    low_bytes: u32,
}

ConstantDoubleInfo :: distinct ConstantLongInfo

ConstantClassInfo :: struct {
    // Points to a ConstantNameAndTypeInfo entry representing a class or interface name.
    name_idx: u16,
}

ConstantStringInfo :: struct {
    // Points to a ConstantUtf8Info entry representing the unicode code points.
    string_idx: u16,
}

ConstantFieldRefInfo :: struct {
    // Points to a ConstantClassInfo entry representing a class or interface
    // that has this field or method as member.
    class_idx: u16,
    // Points to a ConstantNameAndTypeInfo entry for the field or method.
    name_and_type_idx: u16,
}

ConstantMethodRefInfo :: ConstantFieldRefInfo
ConstantInterfaceMethodRefInfo :: ConstantFieldRefInfo

// Represents a field or method, without indicating which class or interface it belongs to.
ConstantNameAndTypeInfo :: struct {
    // Points to a ConstantUtf8Info entry representing either the method name <init>
    // or the fully unqualified name, denoting a field or method.
    name_idx: u16,
    // Points to a ConstantUtf8Info entry
    // representing a field or method descriptor
    descriptor_idx: u16,
}

// Represents a method handle
ConstantMethodHandleInfo :: struct {
    reference_kind: ReferenceKind,
    // If reference_kind is InvokeVirtual, InvokeStatic, InvokeSpecial or NewInvokeSpecial,
    // then this must point to a ConstantMethodRefInfo representing a class method or constructor for which
    // a method handle is to be created. 
    // When reference_kind is InvokeInterface, this points to a ConstantInterfaceMethodRefInfo.
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

// Represents a method type
ConstantMethodTypeInfo :: struct {
    // Points to a ConstantUtf8Info entry representing a method descriptor.
    descriptor_idx: u16,
}

// Used by an invokedynamic instruction to specify a bootstrap method,
// the dynamic invocation name, the argument and return types of the call,
// and optionally, a sequence of additional constants called static arguments to the bootstrap method.
ConstantInvokeDynamicInfo :: struct {
    // Points to an entry in the BootstrapMethods table of the class file.
    bootstrap_method_attr_idx: u16,
    // Points to a ConstantNameAndType structure representing a method name and descriptor.
    name_and_type_idx: u16,
}
