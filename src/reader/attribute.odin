package reader

import "core:reflect"

AttributeInfo :: union {
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
    RuntimeVisibleParameterAnnotations,
    RuntimeInvisibleParameterAnnotations,
    AnnotationDefault,
    BootstrapMethods,
    NestHost,
    NestMembers,
}

// Returns the concrete name of an AttributeInfo variant.
attribute_to_str :: proc(attrib: AttributeInfo) -> string {
    type := reflect.union_variant_typeid(attrib)
    typeinfo := type_info_of(type)
    named, _ := typeinfo.variant.(reflect.Type_Info_Named)
    return named.name
}

attributes_destroy :: proc(attributes: []AttributeInfo) {
    for attrib in attributes {
        attribute_destroy(attrib)
    }
    delete(attributes)
}

// AttributeInfo destructor.
attribute_destroy :: proc(attrib: AttributeInfo) {
    #partial switch &attrib in attrib {
        case Code:
            delete(attrib.exception_table)
            attributes_destroy(attrib.attributes)
        case StackMapTable:
            for frame in attrib.entries {
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
    }
}

element_value_destroy :: proc(value: ElementValueInner) {
    #partial switch &value in value {
        case Annotation:
            annotation_destroy(value)
        case ArrayValue:
            for element in value.values {
                element_value_destroy(element.value)
            }
    }
}

annotations_destroy :: proc(annotations: []Annotation) {
    for annotation in annotations {
        annotation_destroy(annotation)
    }
    delete(annotations)
}

// Annotation destructor
annotation_destroy :: proc(annotation: Annotation) {
    for pair in annotation.element_value_pairs {
        element_value_destroy(pair.value.value)
    }
}

parameter_annotations_destroy :: proc(annotations: []ParameterAnnotation) {
    for annotation in annotations {
        annotations_destroy(annotation.annotations)
    }
    delete(annotations)
}

// Represents the value of a constant field.
ConstantValue :: struct {
    // The constant pool entry at this index gives the constant value represented by this attribute
    // | Field Type 	                 |  Entry Type         |
    // |---------------------------------|---------------------|
    // | long 	                         | ConstantLongInfo    |
    // | float 	                         | ConstantFloatInfo   |
    // | double 	                     | ConstantDoubleInfo  | 
    // | int, short, char, byte, boolean | ConstantIntegerInfo |
    // | String 	                     | ConstantStringInfo  |
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
    code: []u8,
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
    catch_type: u16,
}

// This attribute is used during the process of verification by type checking.
// A method's Code attribute may have at most one StackMapTable attribute.
StackMapTable :: struct {
    entries: []StackMapFrame,
}

// Indicates which checked exceptions a method may throw.
// There may be at most one Exceptions attribute in each MethodInfo structure.
Exceptions :: struct {
    // Each entry points to a ConstantClassInfo, representing a class 
    // that this method is declared to throw.
    exception_idx_table: []u16,
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
    inner_class_info_idx: u16,
    // If C is not a member of a class or interface, this must be zero.
    // Otherwise it points to a ConstantClassInfo representing the 
    // class or interface of which C is a member.
    outer_class_info_idx: u16,
    // If C is anonymous, this must be zero. Otherwise this points to a 
    // ConstantUtf8Info, representing the simple name of C, in its sourcecode.
    name_idx: u16,
    // A mask of flags used to denote access permissions to and properties of C.
    access_flags: u16,
}

// Don't confuse this with ClassAccessFlag
// Access flags used in an InnerClassEntry (as a mask).
InnerClassAccessFlag :: enum {
    AccPublic     = 0x0001, // 0b0000 0000 0000 0001
    AccPrivate    = 0x0002, // 0b0000 0000 0000 0010
    AccProteced   = 0x0004, // 0b0000 0000 0000 0100
    AccStatic     = 0x0008, // 0b0000 0000 0000 1000
    AccFinal      = 0x0010, // 0b0000 0000 0001 0000 
    AccInterface  = 0x0200, // 0b0000 0010 0000 0000 
    AccAbstract   = 0x0400, // 0b0000 0100 0000 0000 
    AccSynthetic  = 0x1000, // 0b0001 0000 0000 0000 
    AccAnnotation = 0x2000, // 0b0010 0000 0000 0000 
    AccEnum       = 0x4000, // 0b0100 0000 0000 0000 
}

// A class must have an EnclosingMethod attribute if and only if
// it is a local or anonymous class.
EnclosingMethod :: struct {
    // Points to a ConstantClassInfo, representing the innermost class 
    // that encloses the declaration of the current class.
    class_idx: u16,
    // If the current class is not immediately enclosed by a method or constructor,
    // Then this must be zero. Otherwise points to a ConstantNameAndTypeInfo 
    // representing the method referenced by the class_idx above.
    method_idx: u16,
}

// A class member that doesn't appear in the source code must have this attribute,
// or else have the AccSynthetic flag set, the only exceptions are compiler 
// generated methods, like Enum::valueOf().
Synthetic :: struct {}

// Records generic signature info for any class, interface constructor or class member.
Signature :: struct {
    // Points to a ConstantUtf8Info representing a class signature.
    signature_idx: u16,
}

// An optional classfile attribute, acting as a filename marker.
SourceFile :: struct {
    // points to a ConstantUtf8Info representing the name of the source file
    // from which this class was compiled.
    sourcefile_idx: u16,
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
    name_idx: u16,
    // Points to a ConstantUtf8Info representing a field descriptor.
    descriptor_idx: u16,
    // Index into the local variable array of the current frame.
    idx: u16,
}

// A table that may be used by debuggers to determine the value of a given
// local variable during the execution of a method.
LocalVariableTypeTable :: struct {
    local_variable_type_table: []LocalVariableTypeTableEntry,
}

// See LocalVariableTypeTable.
// TODO: this could be an alias for LocalVariableTableEntry
LocalVariableTypeTableEntry :: struct {
    start_pc: u16,
    length: u16,
    // Points to a ConstantUtf8Info representing a valid unqualified name.
    name_idx: u16,
    // Points to a ConstantUtf8Info structure, representing
    // a field type signature encoding the type of the local variable.
    signature_idx: u16,
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
    // Points to a ConstantUtf8Info, representing a field descriptor for the annotation type.
    type_idx: u16,
    element_value_pairs: []ElementValuePair,
}

// Represents a single element-value pair in an annotation.
// E.g. x = "y" in @Annotation(x = "y").
ElementValuePair :: struct {
    // Points to a ConstantUtf8Info representing a field descriptor that denotes 
    // the name of the annotation type element value.
    element_name_idx: u16,
    // The element value.
    value: ElementValue,
}

// Discriminated union representing the value of an element-value pair.
// It is used to represent element values in all attributes that describe annotations
// (Runtime(In)VisibleAnnotations and, Runtime(In)VisibleParameterAnnotations.
ElementValue :: struct {
    // The type of the element-value pair.
    // The letters B, C, D, F, I, J, S and Z indicate a primitive type
    // to be interpreted as if they were field descriptors.
    // Other legal values can be found below:

    // | tag | type            |
    // |-----|-----------------|
    // | s   | String          |
    // | e   | enum constant   |
    // | c   | class           |
    // | @   | annotation type |
    // | [   | array           |
    tag: u8,
    value: ElementValueInner,
}

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
    type_name_idx: u16,
    // Points to a ConstantUtf8Info representing the simple name of the enum constant.
    const_name_idx: u16,
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
    bootstrap_method_ref: u16,
    // Each entry must point to a ConstantStringInfo, Class, Integer, Long, 
    // Float, Double, MethodHandle or ConstantMethodTypeInfo.
    bootstrap_args: []u16,
}

// Records the nest host of the nest to which
// the current class or interface claims to belong.
NestHost :: struct {
    // Constant pool index to a ConstantClassInfo.
    host_class_idx: u16,
}

// Records the classes and interfaces that are authorized to claim membership 
// in the nest hosted by the current class or interface.
NestMembers :: struct {
    // A number of indices pointing to a ConstantClassInfo which represents 
    // a class or interface which is a member of the nest,
    // hosted by the current class or interface.
    classes: []u16,
}
