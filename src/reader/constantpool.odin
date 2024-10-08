package reader

import "base:intrinsics"

// A constantpool entry, consists of a one byte tag and the actual value.
ConstantPoolEntry :: struct {
    tag: ConstantType,
    info: CPInfo,
}

// A ConstantPoolEntry tag.
ConstantType :: enum u8 {
    Utf8               = 1,
    Integer            = 3,
    Float              = 4,
    Long               = 5,
    Double             = 6,
    Class              = 7,
    String             = 8,
    FieldRef           = 9,
    MethodRef          = 10,
    InterfaceMethodRef = 11,
    NameAndType        = 12,
    MethodHandle       = 15,
    MethodType         = 16,
    Dynamic            = 17,
    InvokeDynamic      = 18,
    Module             = 19,
    Package            = 20,
}

CPInfo :: union {
    ConstantUtf8Info,
    ConstantIntegerInfo,   
    ConstantFloatInfo,
    ConstantLongInfo,
    ConstantDoubleInfo,
    ConstantClassInfo,
    ConstantStringInfo,
    // Aliased as ConstantMethodRefInfo and ConstantInterfaceMethodRefInfo.
    ConstantFieldRefInfo,
    ConstantNameAndTypeInfo,
    ConstantMethodHandleInfo,
    ConstantMethodTypeInfo,
    ConstantDynamicInfo,
    ConstantInvokeDynamicInfo,
    ConstantModuleInfo,
    ConstantPackageInfo,
}

// A wrapper around an index into the constant pool. Additionally this type
// also encodes what type of entry can be found at that index (E).
// IMPORTANT NOTE: to uphold above contract, one must guarantee that E is always a specialization
// of CPInfo, this cannot be specified here as it would result in a cyclic declaration.
Ptr :: struct($E: typeid) {
    // An index into the classfile's constant pool, the entry at that index is of type E.
    // See cp_get().
    idx: u16,
}

#assert(size_of(Ptr(/* anything */ ConstantUtf8Info)) == size_of(u16))

// Represents a constant string value.
// TODO: let the reader read this properly (slightly different utf8 encoding)
ConstantUtf8Info :: struct {
    // The bytes of the string, no byte may be 0 or be within the range 0xf0 - 0xff.
    // String content is encoded in modified UTF8.
    bytes: []u8 `fmt:"s"`,
}

// Represents a 32 bit int.
ConstantIntegerInfo :: struct {
    bytes: u32,
}

// Represents a 32 bit float.
ConstantFloatInfo :: distinct ConstantIntegerInfo

// Represents a 64 bit long.
ConstantLongInfo :: struct {
    high_bytes: u32,
    low_bytes: u32,
}

// Represents a 64 bit double.
ConstantDoubleInfo :: distinct ConstantLongInfo

// Represents a class or interface.
ConstantClassInfo :: struct {
    // Points to a ConstantUtf8Info entry representing a class or interface name.
    name_idx: Ptr(ConstantUtf8Info),
}

// Represents constant objects of type String.
ConstantStringInfo :: struct {
    // Points to a ConstantUtf8Info entry representing the unicode code points.
    string_idx: Ptr(ConstantUtf8Info),
}

// Represents a field from a class.
ConstantFieldRefInfo :: struct {
    // Points to a ConstantClassInfo entry representing a class or interface
    // that has this field or method as member.
    class_idx: Ptr(ConstantClassInfo),
    // Points to a ConstantNameAndTypeInfo entry for the field or method.
    name_and_type_idx: Ptr(ConstantNameAndTypeInfo),
}

// Represents a method.
ConstantMethodRefInfo :: ConstantFieldRefInfo

// Represents an interface method.
ConstantInterfaceMethodRefInfo :: ConstantFieldRefInfo

// Represents a field or method, without indicating which class or interface it belongs to.
ConstantNameAndTypeInfo :: struct {
    // Points to a ConstantUtf8Info entry representing either the method name <init>
    // or the fully unqualified name, denoting a field or method.
    name_idx: Ptr(ConstantUtf8Info),
    // Points to a ConstantUtf8Info entry
    // representing a field or method descriptor.
    descriptor_idx: Ptr(ConstantUtf8Info),
}

// Represents a method handle.
ConstantMethodHandleInfo :: struct {
    // Denotes the kind of method handle, which characterizes its bytecode behaviour.
    reference_kind: ReferenceKind,
    // If reference_kind is InvokeVirtual, InvokeStatic, InvokeSpecial or NewInvokeSpecial,
    // then this must point to a ConstantMethodRefInfo representing a class method 
    // or constructor for which a method handle is to be created. 
    // When reference_kind is InvokeInterface, this points to a 
    // ConstantInterfaceMethodRefInfo.
    reference_idx: Ptr(ConstantMethodRefInfo), // NOTE: alias
}

ReferenceKind :: enum u8 {
    GetField         = 1,
    GetStatic        = 2,
    PutField         = 3,
    PutStatic        = 4,
    InvokeVirtual    = 5,
    InvokeStatic     = 6,
    InvokeSpecial    = 7,
    NewInvokeSpecial = 8,
    InvokeInterface  = 9,
}

// Represents a method type.
ConstantMethodTypeInfo :: struct {
    // Points to a ConstantUtf8Info entry representing a method descriptor.
    descriptor_idx: Ptr(ConstantUtf8Info),
}

// Represents a dynamically-computed constant, an arbitrary value that is
// produced by invocation of a bootstrap method in the course of an ldc instruction,
// among others.
ConstantDynamicInfo :: struct {
    // Points to an entry in the BootstrapMethods table of the class file.
    bootstrap_method_attr_idx: u16,
    // Points to a ConstantNameAndType structure representing a method name and descriptor.
    name_and_type_idx: Ptr(ConstantNameAndTypeInfo),
}

// Used by an invokedynamic instruction to specify a bootstrap method,
// the dynamic invocation name, the argument and return types of the call,
// and optionally, a sequence of additional constants called static arguments 
// to the bootstrap method.
ConstantInvokeDynamicInfo :: struct {
    // Points to an entry in the BootstrapMethods table of the class file.
    bootstrap_method_attr_idx: u16,
    // Points to a ConstantNameAndType structure representing a method name and descriptor.
    name_and_type_idx: Ptr(ConstantNameAndTypeInfo),
}

// Used to represent a package exported or opened by a module.
ConstantModuleInfo :: struct {
    // Points to a ConstantUtf8Info representing a valid package name, encoded
    // in its internal form.
    name_idx: Ptr(ConstantUtf8Info),
}

// Represents a package exported or opened by a module
ConstantPackageInfo :: struct {
    // Points to a ConstantUtf8Info representing a valid package name, encoded
    // in its internal form.
    name_idx: Ptr(ConstantUtf8Info),
}
