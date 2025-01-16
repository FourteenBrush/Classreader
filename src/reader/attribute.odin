package reader

import "core:reflect"

import "base:intrinsics"

// An attribute that can be found in the ClassFile, FieldInfo, MethodInfo,
// Code and RecordComponent structures.
//
// Seven attributes are critical to correct interpretation of the class file by the JVM:
// - ConstantValue
// - Code
// - StackMapTable
// - BootstrapMethods
// - NestHost
// - NestMembers
// - PermittedSubClasses
//  
// Ten attributes are not critical to correct interpretation of the class file by the JVM,
// but are either critical to correct interpretation of the class file by the 
// class libraries of the Java SE Platform, or are useful for tools 
// (in which case the section that specifies an attribute describes it as "optional"):
// 
// - Exceptions
// - InnerClasses
// - EnclosingMethod
// - Synthetic
// - Signature
// - Record
// - SourceFile
// - LineNumberTable
// - LocalVariableTable
// - LocalVariableTypeTable
//
// Thirteen attributes are not critical to correct interpretation of the class file by the JVM,
// but contain metadata about the class file that is either exposed by the class libraries 
// of the Java SE Platform, or made available by tools (in which case the section that 
// specifies an attribute describes it as "optional"):
// 
// - SourceDebugExtension
// - Deprecated
// - RuntimeVisibleAnnotations
// - RuntimeInvisibleAnnotations
// - RuntimeVisibleParameterAnnotations
// - RuntimeInvisibleParameterAnnotations
// - RuntimeVisibleTypeAnnotations
// - RuntimeInvisibleTypeAnnotations
// - AnnotationDefault
// - MethodParameters
// - Module
// - ModulePackages
// - ModuleMainClass
AttributeInfo :: union {
    Unknown,
    ConstantValue,
    Code,
    StackMapTable,
    Exceptions,
    InnerClasses,
    EnclosingMethod,
    Synthetic,
    Signature,
    SourceFile,
    SourceDebugExtension,
    LineNumberTable,
    LocalVariableTable,
    LocalVariableTypeTable,
    Deprecated,
    RuntimeVisibleAnnotations,
    RuntimeInvisibleAnnotations,
    RuntimeVisibleTypeAnnotations,
    RuntimeInvisibleTypeAnnotations,
    RuntimeVisibleParameterAnnotations,
    RuntimeInvisibleParameterAnnotations,
    AnnotationDefault,
    BootstrapMethods,
    NestHost,
    NestMembers,
    Module,
    ModulePackages,
    ModuleMainClass,
    Record,
    PermittedSubclasses,
}

// Returns the concrete name of an AttributeInfo variant.
attribute_to_str :: proc(attrib: AttributeInfo) -> string {
    type := reflect.union_variant_typeid(attrib)
    typeinfo := type_info_of(type)
    named := typeinfo.variant.(reflect.Type_Info_Named)
    return named.name
}

// Recursively frees the given slice of AttributeInfos.
attributes_destroy :: proc(attributes: []AttributeInfo, allocator := context.allocator) {
    context.allocator = allocator
    for attrib in attributes {
        attribute_destroy(attrib)
    }
    delete(attributes)
}

// AttributeInfo destructor.
attribute_destroy :: proc(attrib: AttributeInfo, allocator := context.allocator) {
    context.allocator = allocator
    #partial switch attrib in attrib {
    case Code:
        delete(attrib.exception_table)
        attributes_destroy(attrib.attributes)
    case StackMapTable:
        for frame in attrib.frames {
            stack_map_frame_destroy(frame)
        }
    case InnerClasses:
        delete(attrib.classes)
    case SourceDebugExtension:
        delete(attrib.debug_extension)
    case LineNumberTable:
        delete(attrib.line_number_table)
    case LocalVariableTable:
        delete(attrib.local_variable_table)
    case LocalVariableTypeTable:
        delete(attrib.local_variable_type_table)
    case RuntimeVisibleAnnotations:
        annotations_destroy(attrib.annotations)
    case RuntimeInvisibleAnnotations:
        annotations_destroy(attrib.annotations)
    case RuntimeVisibleParameterAnnotations:
        parameter_annotations_destroy(attrib.parameter_annotations)
    case RuntimeInvisibleParameterAnnotations:
        parameter_annotations_destroy(attrib.parameter_annotations)
    case AnnotationDefault:
        element_value_destroy(attrib.default_value.value)
    case BootstrapMethods:
        delete(attrib.bootstrap_methods)
    case Module:
        delete(attrib.requires)
        delete(attrib.exports)
        delete(attrib.opens)
        delete(attrib.provides)
    case Record:
        delete(attrib.components)
    }
}

element_value_destroy :: proc(value: ElementValueInner, allocator := context.allocator) {
    context.allocator = allocator
    #partial switch value in value {
    case Annotation:
        annotation_destroy(value)
    case ArrayValue:
        for element in value.values {
            element_value_destroy(element.value)
        }
        delete(value.values)
    }
}

annotations_destroy :: proc(annotations: []Annotation, allocator := context.allocator) {
    context.allocator = allocator
    for annotation in annotations {
        annotation_destroy(annotation)
    }
    delete(annotations)
}

// Annotation destructor.
annotation_destroy :: proc(annotation: Annotation, allocator := context.allocator) {
    context.allocator = allocator
    for pair in annotation.element_value_pairs {
        element_value_destroy(pair.value.value)
    }
    delete(annotation.element_value_pairs)
}

parameter_annotations_destroy :: proc(annotations: []ParameterAnnotation, allocator := context.allocator) {
    context.allocator = allocator
    for annotation in annotations {
        annotations_destroy(annotation.annotations)
    }
    delete(annotations)
}

// An unknown attribute, not recognized by the specification, which we are
// required to silently ignore.
Unknown :: struct {
    bytes: []u8,
}

// Represents the value of a constant field.
ConstantValue :: struct {
    // The constant pool entry at this index gives the constant value represented by this attribute
    // | Field Type                      |  Entry Type         |
    // |---------------------------------|---------------------|
    // | long                            | ConstantLongInfo    |
    // | float                           | ConstantFloatInfo   |
    // | double                          | ConstantDoubleInfo  | 
    // | int, short, char, byte, boolean | ConstantIntegerInfo |
    // | String                          | ConstantStringInfo  |
    constantvalue_idx: u16,
}

// Contains the Java Virtual Machine instructions and auxiliary information for 
// a single method, instance initialization method, or class or interface 
// initialization method. If the method is either native or abstract, its MethodInfo
// structure must not have a Code attribute, otherwise it must have exactly one.
Code :: struct {
    // Max depth of the operand stack of the corresponding method.
    max_stack: u16,
    // The number of local variables in the local variable array, allocated
    // upon invocation of this method. Including the local variables used to pass
    // parameters to the method on its invocation.
    max_locals: u16,
    // The actual bytecode.
    code: []u8 `fmt:"-"`,
    // A list of exception handlers, the order is significant.
    // When an exception is thrown, this table will be searched from the beginning.
    exception_table: []ExceptionHandler,
    // Valid attributes for a Code attribute are:
    // - LineNumberTable
    // - LocalVariableTable
    // - LocalVariableTypeTable
    // - StackMapTable
    attributes: []AttributeInfo,
}

// Describes one exception handler in the code array.
ExceptionHandler :: struct {
    // Indicates the start in the code array at which the handler is active.
    start_pc: u16,
    // Same but for the end of the handler, this is an exclusive index.
    end_pc: u16,
    // An index into the code array, indicating the start of the exception handler.
    // (Points to an instruction).
    handler_pc: u16,
    // If zero, this exception handler is called for all exceptions, to 
    // implement *finally*. Otherwise this points to a ConstantClassInfo
    // representing a class of exceptions that this handler is designated to catch.
    catch_type: Ptr(ConstantClassInfo),
}

// This attribute is used during the process of verification by type checking.
// A method's Code attribute may have at most one StackMapTable attribute.
StackMapTable :: struct {
    frames: []StackMapFrame,
}

// Indicates which checked exceptions a method may throw.
// There may be at most one Exceptions attribute in each MethodInfo structure.
Exceptions :: struct {
    // Each entry points to a ConstantClassInfo, representing a class 
    // that this method is declared to throw.
    exception_idx_table: []Ptr(ConstantClassInfo),
}

// If the constant pool of a class or interface C contains a ConstantClassInfo
// which represents a class or interface that is not a member of a package. 
// Then C's ClassFile structure must have exactly one InnerClasses attribute. 
InnerClasses :: struct {
    classes: []InnerClassEntry,
}

// Represents a class or interface that's not a package member.
InnerClassEntry :: struct {
    // Points to a ConstantClassInfo representing this entry's class (call it C). 
    inner_class_info_idx: Ptr(ConstantClassInfo),
    // If C is not a member of a class or interface, this must be zero.
    // Otherwise it points to a ConstantClassInfo representing the 
    // class or interface of which C is a member.
    outer_class_info_idx: Ptr(ConstantClassInfo),
    // If C is anonymous, this must be zero. Otherwise this points to a 
    // ConstantUtf8Info, representing the simple name of C, in its sourcecode.
    name_idx: Ptr(ConstantUtf8Info),
    // Denotes access permissions to and properties of C.
    access_flags: InnerClassAccessFlags,
}

// Don't confuse this with ClassAccessFlag
// Access flags used in an InnerClassEntry.
InnerClassAccessFlag :: enum {
    Public     = 0x0001, 
    Private    = 0x0002, 
    Protected  = 0x0004, 
    Static     = 0x0008, 
    Final      = 0x0010, 
    Interface  = 0x0200, 
    Abstract   = 0x0400, 
    Synthetic  = 0x1000, 
    Annotation = 0x2000, 
    Enum       = 0x4000, 
}

InnerClassAccessFlags :: bit_set[InnerClassAccessFlagBit; u16]

// Log 2's of InnerClassAccessFlag, for use within a bit_set.
InnerClassAccessFlagBit :: enum u16 {
    Public     = LOG2(InnerClassAccessFlag.Public),
    Private    = LOG2(InnerClassAccessFlag.Private),
    Protected  = LOG2(InnerClassAccessFlag.Protected),
    Static     = LOG2(InnerClassAccessFlag.Static),
    Final      = LOG2(InnerClassAccessFlag.Final),
    Interface  = LOG2(InnerClassAccessFlag.Interface),
    Abstract   = LOG2(InnerClassAccessFlag.Abstract),
    Synthetic  = LOG2(InnerClassAccessFlag.Synthetic),
    Annotation = LOG2(InnerClassAccessFlag.Annotation),
    Enum       = LOG2(InnerClassAccessFlag.Enum),
}

// A class must have an EnclosingMethod attribute if and only if
// it is a local or anonymous class.
EnclosingMethod :: struct {
    // Points to a ConstantClassInfo, representing the innermost class 
    // that encloses the declaration of the current class.
    class_idx: Ptr(ConstantClassInfo),
    // If the current class is not immediately enclosed by a method or constructor,
    // Then this must be zero. Otherwise points to a ConstantNameAndTypeInfo 
    // representing the method referenced by the class_idx above.
    method_idx: Ptr(ConstantNameAndTypeInfo),
}

// A class member that doesn't appear in the source code must have this attribute,
// or else have the AccSynthetic flag set, the only exceptions are compiler 
// generated methods, like Enum::valueOf().
Synthetic :: struct {}

// Records generic signature info for any class, interface constructor or class member.
Signature :: struct {
    // Points to a ConstantUtf8Info representing a class signature.
    signature_idx: Ptr(ConstantUtf8Info),
}

// An optional classfile attribute, acting as a filename marker.
SourceFile :: struct {
    // points to a ConstantUtf8Info representing the name of the source file
    // from which this class was compiled.
    sourcefile_idx: Ptr(ConstantUtf8Info),
}

// A vendor specific debugging extension.
SourceDebugExtension :: struct {
    debug_extension: string,
}

// Line number table present within the Code attribute.
LineNumberTable :: struct {
    line_number_table: []LineNumberTableEntry,
}

// A mapping between a line number and a code offset.
LineNumberTableEntry :: struct {
    // The index in the code array where the code for a new line begins.
    start_pc: u16,
    // The corresponding line number in the source file.
    line_number: u16,
}

// Used by debuggers to determine the value of a given local variable
// during the execution of a method.
LocalVariableTable :: struct {
    local_variable_table: []LocalVariableTableEntry,
}

LocalVariableTableEntry :: struct {
    // variable located at code[start_pc][:length]
    start_pc: u16,
    length: u16,
    // Points to a ConstantUtf8Info representing a valid unqualified name.
    name_idx: Ptr(ConstantUtf8Info),
    // Points to a ConstantUtf8Info representing a field descriptor.
    descriptor_idx: Ptr(ConstantUtf8Info),
    // Index into the local variable array of the current frame.
    idx: u16,
}

// A table that may be used by debuggers to determine the value of a given
// local variable during the execution of a method.
LocalVariableTypeTable :: struct {
    local_variable_type_table: []LocalVariableTypeTableEntry,
}

// See LocalVariableTypeTable.
// FIXME: this could be an alias for LocalVariableTableEntry
LocalVariableTypeTableEntry :: struct {
    start_pc: u16,
    length: u16,
    // Points to a ConstantUtf8Info representing a valid unqualified name.
    name_idx: Ptr(ConstantUtf8Info),
    // Points to a ConstantUtf8Info structure, representing
    // a field type signature encoding the type of the local variable.
    signature_idx: Ptr(ConstantUtf8Info),
    // Index into the local variable array of the current frame.
    idx: u16,
}

// Denotes a deprecated element.
Deprecated :: struct {}

// Run-time-visible annotations on classes, fields or methods.
RuntimeVisibleAnnotations :: struct {
    annotations: []Annotation,
}

// Annotations that must not be made available for return by reflective apis.
RuntimeInvisibleAnnotations :: struct {
    annotations: []Annotation,
}

// Records runtime visible annotations on types used in the declaration of the 
// corresponding class, field or method, or in an expression in the 
// corresponding method body. This may also be used on generic type parameters 
// of generic classes, interfaces, methods and constructor.
RuntimeVisibleTypeAnnotations :: struct {
    annotations: []TypeAnnotation,
}

RuntimeInvisibleTypeAnnotations :: struct {
    annotations: []TypeAnnotation, 
}

// FIXME: aliases?

// Records run-time-visible parameter annotations of the corresponding MethodInfo.
RuntimeVisibleParameterAnnotations :: struct {
    // Each value of the this table represents all of 
    // the run-time-visible annotations on a single parameter.
    parameter_annotations: []ParameterAnnotation,
}

// Similar to RuntimeVisibleParameterAnnotations, but these annotations must not
// be made available for return by reflective apis.
RuntimeInvisibleParameterAnnotations :: struct {
    parameter_annotations: []ParameterAnnotation,
}

// An annotation as specified by the language.
Annotation :: struct {
    // Points to a ConstantUtf8Info, representing a field descriptor 
    // for the annotation type.
    type_idx: Ptr(ConstantUtf8Info),
    // A list of element-value pairs in the annotation.
    element_value_pairs: []ElementValuePair,
}

// Represents a single runtime visible annotation on a type used in a declaration or
// expression. The meaning of those fields is the same as in an Annotation.
TypeAnnotation :: struct {
    // Denotes the kind of target on which the annotation appears.
    target_type: TargetType,
    // Denotes which which type in a declaration or expression is annotated.
    target_info: TargetInfo,
    // Denotes precisely which part of the type indicated by target_info is indicated.
    target_path: TypePath,
    using annotation: Annotation,
}

// https://docs.oracle.com/javase/specs/jvms/se21/html/jvms-4.html#jvms-4.7.20-400
TargetType :: enum u8 {
    ClassType                         = 0x00,
    MethodType                        = 0x01,
    ClassExtends                      = 0x10,
    ClassTypeParameterBound           = 0x11,
    MethodTypeParameterBound          = 0x12,
    Field                             = 0x13,
    MethodReturn                      = 0x14,
    MethodReceiver                    = 0x15,
    MethodFormalParameter             = 0x16,
    Throws                            = 0x17,
    LocalVariable                     = 0x40,
    ResourceVariable                  = 0x41,
    ExceptionParameter                = 0x42,
    Instanceof                        = 0x43,
    New                               = 0x44,
    ConstructorReference              = 0x45,
    MethodReference                   = 0x46,
    Cast                              = 0x47,
    ConstructorInvocationTypeArgument = 0x48,
    MethodInvocationTypeArgument      = 0x49,
    ConstructorReferenceTypeArgument  = 0x4A,
    MethodReferenceTypeArgument       = 0x4B,
}

TargetInfo :: union {
    TypeParameterTarget,
    SuperTypeTarget,
    TypeParameterBoundTarget,
    EmptyTarget,
    FormalParameterTarget,
    ThrowsTarget,
    LocalVarTarget,
    CatchTarget,
    OffsetTarget,
    TypeArgumentTarget,
}

// Indicates that an annotation appears on the declaration of the i'th parameter
// of a generic class, interface, method or constructor.
TypeParameterTarget :: struct {
    // Specifies which parameter declaration is annotated. A value of 0 means
    // the first parameter declaration.
    type_parameter_idx: u16,
}

// Indicates that an annotation appears on a type in an extends or implements
// clause of a class or interface declaration.
SuperTypeTarget :: struct {
    // A value of 65535 means that the annotation appears on the superclass in an
    // extends or implements clause. Any other value is an index into the interfaces
    // array of the enclosing ClassFile structure, and specifies that the annnotation
    // appears on that superinterface in either the implements clause of a 
    // class or interface declaration.
    super_type_idx: u16,
}

// Indicates that an annotation appears on the i'th bound of the j'th type parameter
// declaration of a generic class, interface, method or constructor.
// Note that this does not record the type which constitutes the bound.
// The type may be found by inspecting the class or method signature stored in the
// appropriate Signature attribute.
TypeParameterBoundTarget :: struct {
    // Specifies which type parameter declaration has an annotated bound.
    // A value of 0 would specify the first type parameter declaration.
    type_parameter_idx: u16,
    // Specifies which bound of the type parameter declaration indicated by
    // type_parameter_idx is annotated. A value of 0 would specify the first bound.
    bound_idx: u16,
}

// Indicates that an annotation appears on either the type in a field or record
// component declaration, the return type of a method, the type of a newly constructed
// object, or the receiver of a method or constructor.
EmptyTarget :: struct {}

// Indicates that an annotation appears on the type of a formal parameter declaration
// of a method, constructor or lambda expression.
FormalParameterTarget :: struct {
    // Specifies which formal parameter declaration has an annotated type. A value of i
    // may, but is not required to, correspond to the i'th parameter descriptor in 
    // the method descriptor.
    formal_parameter_idx: u16,
}

// Indicates that an annotation appears on the i'th type in the throws clause of a
// method or constructor declaration.
ThrowsTarget :: struct {
    // An index into the exception_index_table array of the Exceptions attribute
    // of the MethodInfo structure enclosing the RuntimeVisibleTypeAnnotations attribute.
    throws_type_idx: u16,
}

// Indicates that an annotation appears on the type in a local variable declaration,
// including a variable declared as resource in a try-with-resources statement.
LocalVarTarget :: struct {
    // Each entry indicates a range of code array offsets within which
    // a local variable has a value. It also indicates the index into the local
    // variable array of the current frame at which that local variable can be found.
    table: []LocalVarTargetEntry,
}

// Used within a LocalValTarget.
LocalVarTargetEntry :: struct {
    // An index into the code array in the interval [start_pc:][:length]
    start_pc: u16,
    length: u16,
    // The given local variable must be at idx in the local variable array of
    // the current frame.
    idx: u16,
}

// Indicates that an annotation appears on the i'th type in an exception parameter declaration.
CatchTarget :: struct {
    // An index into the exception_table array of the Code attribute enclosing the 
    // RuntimeVisibleTypeAnnotations.
    exception_table_idx: u16, 
}

// Indicates that an annotation appears on either the type in an instanceof expression
// Or a new expression, or the type before the :: in a method reference expression.
OffsetTarget :: struct {
    // Specifies the code array offset of either the bytecode instruction
    // corresponding to the instanceof expression, the new bytecode instruction,
    // or the bytecode instruction corresponding to the method reference expression.
    offset: u16,
}

// Indicates that an annotation appears on the i'th type in a cast expression, or the i'th
// type argument in the explicit type argument list for any of the following:
// - A new expression
// - An explicit constructor invocation statement
// - A method invocation expression
// - A method reference expression
TypeArgumentTarget :: struct {
    // Specifies the code array offset, depending on the context of this target.
    offset: u16,
    // For a cast expression, this specifies which type in the cast operator
    // is annotated. A value of 0 specifies the first (or only) type in the cast operator.
    // For any explicit type argument list, this specifies which type argument is
    // annotated, a value of zero specifies the first type argument.
    type_argument_idx: u16,
}

// Whenever a type is used in a declaration or expression, this identifies which part
// of the type is annotated.
//
// If an array type T[] is used in a declaration or expression, then an annotation 
// may appear on any component type, including the element type.
//
// If a nested type T1.T2 is used, then an annotation may appear on the innermost 
// member type and the enclosing type for which a type annotation is admissible.
// 
// If a parameterized type T<A> or T<? super A> is used, then an annotation may
// appear on any type argument or on the bound of any wildcard type argument.
TypePath :: struct {
     path: []PathEntry,
}

// Used within a TypePath.
PathEntry :: struct {
    type_path_kind: PathKind,
    // When type_path_kind is .ArrayType, .NestedType or .Wildcard, then this is 0.
    // When type_path_kind is .Parameterized, then this specifies which type argument
    // of a parameterized type is annotated. Where 0 indicates the first type argument.
    type_argument_idx: u8,
}

// Used within a PathEntry.
PathKind :: enum u8 {
    // Annotation is deeper in an array type.
    ArrayType     = 0,
    // Annotation is deeper in a nested type.
    NestedType    = 1,
    // Annotation is on the bound of a wildcard type argument of a parameterized type.
    Wildcard      = 2,
    // Annotation is on a type argument of a parameterized type.
    Parameterized = 3,
}

// Represents a single element-value pair in an annotation.
// E.g. x = "y" in @Annotation(x = "y").
ElementValuePair :: struct {
    // Points to a ConstantUtf8Info representing a field descriptor that denotes 
    // the name of the annotation type element value.
    element_name_idx: Ptr(ConstantUtf8Info),
    // The element value.
    value: ElementValue,
}

// Discriminated union representing the value of an element-value pair.
// It is used to represent element values in all attributes that describe annotations
// (Runtime(In)VisibleAnnotations and, Runtime(In)VisibleParameterAnnotations.
ElementValue :: struct {
    // The type of the element-value pair.

    // | Tag Item | Type                | Value Item      | Constant Type      |
    // |----------|---------------------|-----------------|--------------------|
    // | B        | byte                | ConstValueIdx   | ConstantIntegerInfo|
    // | C        | char                | ConstValueIdx   | ConstantIntegerInfo|
    // | D        | double              | ConstValueIdx   | ConstantDoubleInfo |
    // | F        | float               | ConstValueIdx   | ConstantFloatInfo  |
    // | I        | int                 | ConstValueIdx   | ConstantIntegerInfo|
    // | J        | long                | ConstValueIdx   | ConstantLongInfo   |
    // | S        | short               | ConstValueIdx   | ConstantIntegerInfo|
    // | Z        | boolean             | ConstValueIdx   | ConstantIntegerInfo|
    // | s        | String              | ConstValueIdx   | ConstantUtf8Info   |
    // | e        | Enum class          | EnumConstValue  | Not applicable     |
    // | c        | Class               | ClassInfoIdx    | Not applicable     |
    // | @        | Annotation interface| Annotation      | Not applicable     |
    // | [        | Array type          | ArrayValue      | Not applicable     |
    tag: u8,
    value: ElementValueInner,
}

// See ElementValue.
ElementValueInner :: union {
    ConstValueIdx,
    EnumConstValue,
    ClassInfoIdx,
    Annotation,
    ArrayValue,
}

// Used when the ElementValue.tag is one of the primitive types.
// This then points to an entry of the type designated by the table explaning the tag.
ConstValueIdx :: distinct u16
// Used when the tag is 'c', this points to a ConstantUtf8Info representing the
// return descriptor of the type that is reified by the class.
ClassInfoIdx :: distinct u16

// Used when the tag is 'e'.
EnumConstValue :: struct {
    // Points to a ConstantUtf8Info representing a field descriptor that 
    // denotes the internal form of the binary name of the enum type.
    type_name_idx: Ptr(ConstantUtf8Info),
    // Points to a ConstantUtf8Info representing the simple name of the enum constant.
    const_name_idx: Ptr(ConstantUtf8Info),
}

// Used when the tag is '['.
ArrayValue :: struct {
    // The elements in the array typed ElementValue.
    values: []ElementValue,
}

// Annotation container for one MethodInfo.
ParameterAnnotation :: struct {
    annotations: []Annotation,
}

// Contained within the attributes of MethodInfo structures, this records 
// the default value for the element represented by the MethodInfo structure.
AnnotationDefault :: struct {
    // The actual default value.
    default_value: ElementValue,
}

// Bootstrap method specifiers referenced by invokedynamic instructions.
// There can be at most one BootstrapMethods attribute in a Classfile's attributes.
BootstrapMethods :: struct {
    bootstrap_methods: []BootstrapMethod,
}

// Each bootstrap method represents a MethodHandle.
BootstrapMethod :: struct {
    // Points to a ConstantMethodHandleInfo, which reference_kind should be
    // InvokeStatic or NewInvokeSpecial or else invocation of the method handle
    // during call site specifier resolution will complete abruptly.
    bootstrap_method_ref: Ptr(ConstantMethodHandleInfo),
    // Each entry must point to a ConstantStringInfo, Class, Integer, Long, 
    // Float, Double, MethodHandle or ConstantMethodTypeInfo.
    // TODO: encode in ptr
    bootstrap_args: []u16,
}

// Records the nest host of the nest to which
// the current class or interface claims to belong.
NestHost :: struct {
    // Constant pool index to a ConstantClassInfo.
    host_class_idx: Ptr(ConstantClassInfo),
}

// Records the classes and interfaces that are authorized to claim membership 
// in the nest hosted by the current class or interface.
NestMembers :: struct {
    // A number of indices pointing to a ConstantClassInfo which represents 
    // a class or interface which is a member of the nest,
    // hosted by the current class or interface.
    classes: []Ptr(ConstantClassInfo),
}

// Records information about formal parameters of a method, such as their names.
MethodParameters :: struct {
    parameter: []MethodParameter,
}

// A parameter of a method.
MethodParameter :: struct {
    // When zero, this MethodParameter indicates a parameter with no name.
    // Otherwise points to a ConstantUtf8Info representing a unqualified name.
    name_idx: Ptr(ConstantUtf8Info),
    access_flags: MethodParameterAccessFlags,
}

MethodParameterAccessFlag :: enum u16 {
    // The parameter was declared final.
    Final     = 0x0010,
    // The parameter was not explicitly or implicitly declared in source code.
    // (An implementation artifact of the compiler).
    Synthetic = 0x1000,
    // The parameter was implicitly declared in the source code.
    Mandated  = 0x8000,
}

MethodParameterAccessFlags :: bit_set[MethodParameterAccessFlagBit; u16]

// Log 2's of MethodParameterAccessFlag, for use within a bit_set.
MethodParameterAccessFlagBit :: enum {
    Final     = LOG2(MethodParameterAccessFlag.Final),
    Synthetic = LOG2(MethodParameterAccessFlag.Synthetic),
    Mandated  = LOG2(MethodParameterAccessFlag.Mandated),
}

// Indicates the modules required by a module, the packages exported and opened,
// and the services used and provided by a module.
Module :: struct {
    // Points to a ConstantModuleInfo denoting the current module.
    module_name_idx: Ptr(ConstantModuleInfo),
    module_flags: ModuleFlags,
    // When zero, then no version information about the current module is present.
    // Otherwise points to a ConstantUtf8Info representing the version.
    module_version_idx: Ptr(ConstantUtf8Info),
    // Each entry specifies a dependence on the current module.
    // Unless the current module is java.base, exactly one entry must have 
    // all of the following:
    // - A requires_idx that indicates java.base
    // - A requires_flags that has the .Synthetic flag not set (.Mandated may be set)
    // - If the class file version is 54 or above, a requires_flags that has both the 
    // .Transitive and .StaticPhase not set.
    requires: []ModuleRequire,
    exports: []ModuleExport,
    opens: []ModuleOpens,
    // Each entry points to a ConstantClassInfo representing a service interface 
    // which the current module may discover via java.util.ServiceLoader.
    uses_idx: []Ptr(ConstantClassInfo),
    provides: []ModuleProvides,
}

// Flags for a Module.
ModuleFlag :: enum u16 {
    // Indicates that the module is open.
    Open      = 0x0020,
    // Indicates that the module was not explicitly or implicitly declared.
    Synthetic = 0x1000,
    // Indicates that the module was implicitly declared.
    Mandated  = 0x8000,
}

ModuleFlags :: bit_set[ModuleFlagBit; u16]

// Log 2's of a ModuleFlag, for use within a bit_set.
ModuleFlagBit :: enum u16 {
    Open      = LOG2(ModuleFlag.Open),
    Synthetic = LOG2(ModuleFlag.Synthetic),
    Mandated  = LOG2(ModuleFlag.Mandated),
}

// Specifies a dependence of the current module.
ModuleRequire :: struct {
    // Points to a ConstantModuleInfo denoting a module 
    // on which the current module depends.
    requires_idx: Ptr(ConstantModuleInfo),
    requires_flags: ModuleRequireFlags,
    // When zero then no version information about the dependence is present.
    // Otherwise, points to a ConstantUtf8Info representing the version of the module
    // specified by the requires_idx.
    requires_version_idx: Ptr(ConstantUtf8Info),
}

ModuleRequireFlag :: enum u16 {
    // Indicates that any module which depends on this module, implicitly declares
    // a dependence on this module.
    Transitive  = 0x0020,
    // Indicates that this dependence is mandatory in the static phase, 
    // i.e. at compile time, but is optional in the dynamic phase, i.e. at runtime.
    StaticPhase = 0x0040,
    // Indicates that this dependence was not explicitly or implicitly 
    // declared in the source of the module declaration.
    Synthetic   = 0x1000,
    // Indicates that the this dependence was implicitly declared 
    // in the source of the module.
    Mandated    = 0x8000,
}

ModuleRequireFlags :: bit_set[ModuleRequireFlagBit; u16]

// Log 2's of ModuleRequireFlag, for use within a bit_set.
ModuleRequireFlagBit :: enum u16 {
    Transitive  = LOG2(ModuleRequireFlag.Transitive),
    StaticPhase = LOG2(ModuleRequireFlag.StaticPhase),
    Synthetic   = LOG2(ModuleRequireFlag.Synthetic),
    Mandated    = LOG2(ModuleRequireFlag.Mandated),
}

// Represents a package exported by the current module.
ModuleExport :: struct {
    // Points to a ConstantPackageInfo representing an exported package.
    exports_idx: Ptr(ConstantPackageInfo),
    exports_flags: ModuleExportFlags,
    // When len(exports_to_idx) is zero, then this package is exported 
    // by the current module in an unqualified fashion; 
    // code in any other module may access the types and members in the package.
    // If non-zero, then only code in the modules listed in this table may 
    // access the types and members in this package.
    // Each entry points to a ConstantModuleInfo denoting a module 
    // which can access the types and members in this exported package.
    exports_to_idx: []Ptr(ConstantModuleInfo),
}

ModuleExportFlag :: enum u16 {
    Synthetic = 0x1000,
    Mandated  = 0x8000,
}

ModuleExportFlags :: bit_set[ModuleExportFlagBit; u16]

// Log 2's of ModuleExportFlag, for use within a bit_set.
ModuleExportFlagBit :: enum u16 {
    Synthetic = LOG2(ModuleExportFlag.Synthetic),
    Mandated  = LOG2(ModuleExportFlag.Mandated),
}

// A package opened by the current module.
ModuleOpens :: struct {
    // Points to a ConstantPackageInfo representing a package opened.
    opens_idx: Ptr(ConstantPackageInfo),
    opens_flags: ModuleOpensFlags,
    // When len(opens_to_idx) is zero, then code in any other module 
    // may reflectively access the types and members in the package.
    // Otherwise only code in this table may reflectively access them.
    opens_to_idx: []Ptr(ConstantModuleInfo), 
}

ModuleOpensFlag :: enum u16 {
    Synthetic = 0x1000,
    Mandated  = 0x8000,
}

ModuleOpensFlags :: bit_set[ModuleOpensFlagBit; u16]

// Log 2's of ModuleOpensFlag, for use within a bit_set.
ModuleOpensFlagBit :: enum u16 {
    Synthetic = LOG2(ModuleOpensFlag.Synthetic),
    Mandated  = LOG2(ModuleOpensFlag.Mandated),
}

// Represents a service implementation for a given service name.
ModuleProvides :: struct {
    // Points to a ConstantClassInfo representing a service interface for which
    // the current module provides an interface.
    provides_idx: Ptr(ConstantClassInfo),
    // Each entry must point to a ConstantClassInfo representing a 
    // service implementation for the service specified by provides_idx.
    provides_with_idx: []Ptr(ConstantClassInfo),
}

// Indicates all the packages that are exported or opened by 
// the Module attribute. As well as the packages of the service implementations.
ModulePackages :: struct {
    // Each entry points to a ConstantPackageInfo representing a package
    // in the current module.
    package_idx: []Ptr(ConstantPackageInfo),
}

// Indicates the main class of a module.
ModuleMainClass :: struct {
    // Points to a ConstantClassInfo.
    main_class_idx: Ptr(ConstantClassInfo),
}

// Indicates that the current class is a record, and stores information about
// the record components.
Record :: struct {
    components: []RecordComponentInfo,
}

// Specifies a record component, as in Class::getRecordComponents().
RecordComponentInfo :: struct {
    // Points to a ConstantUtf8Info representing an unqualified name
    // denoting the record component.
    name_idx: Ptr(ConstantUtf8Info),
    // Points to a ConstantUtf8Info, representing a field descriptor, which
    // encodes the type of the record component.
    descriptor_idx: Ptr(ConstantUtf8Info),
    // Valid attributes for a Record attribute are:
    // - Signature
    // - Runtime(In)VisibleAnnotations
    // - Runtime(In)VisibleTypeAnnotations
    attributes: []AttributeInfo,
}

// Records classes or interfaces that can inherit from the current class or interface.
PermittedSubclasses :: struct {
    // Each entry points to a ConstantClassInfo, representing a class or
    // interface which is authorized to directly extend or implement the
    // current class or interface.
    classes: []Ptr(ConstantClassInfo),
}
