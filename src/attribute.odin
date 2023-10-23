package classreader

// Used by a ClassFile, FieldInfo, MethodInfo, and CodeAttribute
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
            delete(attrib.attributes)
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

ConstantValue :: struct {
    constantvalue_idx: u16,
}

Code :: struct {
    max_stack: u16,
    max_locals: u16,
    code_length: u32,
    code: []u8,
    exception_table_length: u16,
    exception_table: []ExceptionHandler,
    attributes_count: u16,
    attributes: []AttributeInfo,
}

ExceptionHandler :: struct {
    start_pc: u16,
    end_pc: u16,
    handler_pc: u16,
    catch_type: u16,
}

StackMapTable :: struct {
    number_of_entries: u16,
    entries: []StackMapFrame,
}

Exceptions :: struct {
    number_of_exceptions: u16,
    exception_idx_table: []u16,
}

InnerClasses :: struct {
    number_of_classes: u16,
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
    line_number_table_length: u16,
    line_number_table: []LineNumberTableEntry,
}

LineNumberTableEntry :: struct {
    start_pc: u16,
    line_number: u16,
}

LocalVariableTable :: struct {
    local_variable_table_length: u16,
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
    local_variable_type_table_length: u16,
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
    num_annotations: u16,
    annotations: []Annotation,
}

Annotation :: struct {
    type_idx: u16,
    num_element_value_pairs: u16,
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
    num_values: u16,
    values: []ElementValue,
}

RuntimeInvisibleAnnotations :: struct {
    num_annotations: u16,
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
    num_annotations: u16,
    annotations: []Annotation,
}

AnnotationDefault :: struct {
    default_value: ElementValue,
}

BootstrapMethods :: struct {
    num_bootstrap_methods: u16,
    bootstrap_methods: []BootstrapMethod,
}

BootstrapMethod :: struct {
    bootstrap_method_ref: u16, 
    num_bootstrap_arguments: u16,
    bootstrap_arguments: []u16,
}