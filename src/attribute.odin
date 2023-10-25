package classreader

AttributeInfo :: struct {
    name_idx: u16,
    length: u32,
    info: AttributeInfoInner,
}

attributes_destroy :: proc(attributes: []AttributeInfo) {
    for attrib in attributes {
        attribute_destroy(attrib)
    }
    delete(attributes)
}

attribute_destroy :: proc(using attrib: AttributeInfo) {
    #partial switch &attrib in info {
        case Code:
            delete(attrib.exception_table)
            attributes_destroy(attrib.attributes)
        case StackMapTable:
            for frame in attrib.entries {
                stack_map_frame_destroy(frame)
            }
        case Exceptions:
            delete(attrib.exception_idx_table)
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
            for param in attrib.parameter_annotations {
                annotations_destroy(param.annotations)
            }
            delete(attrib.parameter_annotations)
        case RuntimeInvisibleParameterAnnotations:
            for param in attrib.parameter_annotations {
                annotations_destroy(param.annotations)
            }
            delete(attrib.parameter_annotations)
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

annotation_destroy :: proc(annotation: Annotation) {
    for pair in annotation.element_value_pairs {
        element_value_destroy(pair.value.value)
    }
}

AttributeInfoInner :: union {
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
}

// Represents the value of a constant field
ConstantValue :: struct {
    // The constant_pool entry at this index gives the constant value represented by this attribute
    // Field Type 	                    Entry Type
    // long 	                        CONSTANT_Long
    // float 	                        CONSTANT_Float
    // double 	                        CONSTANT_Double
    // int, short, char, byte, boolean 	CONSTANT_Integer
    // String 	                        CONSTANT_String
    constantvalue_idx: u16,
}

// Contains the Java Virtual Machine instructions and auxiliary information for 
// a single method, instance initialization method, or class or interface initialization method
// If the method is either native or abstract, its method_info structure must not have a Code attribute.
// Otherwise, its method_info structure must have exactly one Code attribute.
Code :: struct {
    max_stack: u16,
    max_locals: u16,
    code: []u8,
    exception_table: []ExceptionHandler,
    attributes: []AttributeInfo,
}

// Describes one exception handler in the code array.
ExceptionHandler :: struct {
    start_pc: u16,
    end_pc: u16,
    handler_pc: u16,
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
    exception_idx_table: []u16,
}

InnerClasses :: struct {
    classes: []InnerClassEntry,
}

// TODO: rename to a more proper name
InnerClassEntry :: struct {
    inner_class_info_idx: u16,
    outer_class_info_idx: u16,
    name_idx: u16,
    access_flags: u16,
}

// don't confuse this with ClassAccessFlag
// Used in an InnerClassEntry
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

EnclosingMethod :: struct {
    class_idx: u16,
    method_idx: u16,
}

Synthetic :: struct {}

Signature :: struct {
    signature_idx: u16,
}

SourceFile :: struct {
    sourcefile_idx: u16,
}

SourceDebugExtension :: struct {
    debug_extension: []u8,
}

LineNumberTable :: struct {
    line_number_table: []LineNumberTableEntry,
}

LineNumberTableEntry :: struct {
    start_pc: u16,
    line_number: u16,
}

LocalVariableTable :: struct {
    local_variable_table: []LocalVariableTableEntry,
}

LocalVariableTableEntry :: struct {
    start_pc: u16,
    length: u16,
    name_idx: u16,
    descriptor_idx: u16,
    idx: u16,
}

LocalVariableTypeTable :: struct {
    local_variable_type_table: []LocalVariableTypeTableEntry,
}

LocalVariableTypeTableEntry :: struct {
    start_pc: u16,
    length: u16,
    name_idx: u16,
    signature_idx: u16,
    idx: u16,
}

Deprecated :: struct {}

RuntimeVisibleAnnotations :: struct {
    annotations: []Annotation,
}

Annotation :: struct {
    type_idx: u16,
    element_value_pairs: []ElementValuePair,
}

ElementValuePair :: struct {
    element_name_idx: u16,
    value: ElementValue,
}

// discriminated union representing the value of an element-value pair.
// It is used to represent element values in all attributes that describe annotations
// (RuntimeVisibleAnnotations, RuntimeInvisibleAnnotations, RuntimeVisibleParameterAnnotations, and RuntimeInvisibleParameterAnnotations
ElementValue :: struct {
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

// needed because we can't alias a u16 in a union twice
ConstValueIdx :: distinct u16
ClassInfoIdx :: distinct u16

EnumConstValue :: struct {
    type_name_idx: u16,
    const_name_idx: u16,
}

ArrayValue :: struct {
    values: []ElementValue,
}

RuntimeInvisibleAnnotations :: struct {
    annotations: []Annotation,
}

RuntimeVisibleParameterAnnotations :: struct {
    num_parameters: u8,
    parameter_annotations: []ParameterAnnotation,
}

RuntimeInvisibleParameterAnnotations :: struct {
    num_parameters: u8,
    parameter_annotations: []ParameterAnnotation,
}

ParameterAnnotation :: struct {
    annotations: []Annotation,
}

AnnotationDefault :: struct {
    default_value: ElementValue,
}

BootstrapMethods :: struct {
    bootstrap_methods: []BootstrapMethod,
}

BootstrapMethod :: struct {
    bootstrap_method_ref: u16,
    bootstrap_arguments: []u16,
}