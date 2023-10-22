package classreader

StackMapFrame :: union {
    SameFrame,
    SameLocals1StackItemFrame,
    SameLocals1StackItemFrameExtended,
    ChopFrame,
    SameFrameExtended,
    AppendFrame,
    FullFrame,
}

SameFrame :: struct {}

SameLocals1StackItemFrame :: struct {
    stack: VerificationTypeInfo,
}

SameLocals1StackItemFrameExtended :: struct {
    offset_delta: u16,
    stack: VerificationTypeInfo,
}

ChopFrame :: struct {
    offset_delta: u16,
}

SameFrameExtended :: struct {
    offset_delta: u16,
}

AppendFrame :: struct {
    offset_delta: u16,
    // size: frame_type - 251
    locals: []VerificationTypeInfo,
}

FullFrame :: struct {
    offset_delta: u16,
    number_of_locals: u16,
    locals: []VerificationTypeInfo,
    number_of_stack_items: u16,
    stack: []VerificationTypeInfo,
}

// TODO: type aliases?
VerificationTypeInfo :: union {
    TopVariableInfo,                // 0
    IntegerVariableInfo,            // 1
    FloatVariableInfo,              // 2
    LongVariableInfo,               // 4
    DoubleVariableInfo,             // 3
    NullVariableInfo,               // 5
    UninitializedThisVariableInfo,  // 6
    ObjectVariableInfo,             // 7
    UninitializedVariableInfo,      // 8
}

// TODO: type aliases?
TopVariableInfo :: struct {}

IntegerVariableInfo :: struct {}

FloatVariableInfo :: struct {}

LongVariableInfo :: struct {}

DoubleVariableInfo :: struct {}

NullVariableInfo :: struct {}

UninitializedThisVariableInfo :: struct {}

ObjectVariableInfo :: struct {
    cp_idx: u16,
}

UninitializedVariableInfo :: struct {
    offset: u16,
}

AttributeBase :: struct {
    name_idx: u16,
    length: u32,
}

Exceptions :: struct {
    using base: AttributeBase,
    number_of_exceptions: u16,
    exception_idx_table: []u16,
}

InnerClasses :: struct {
    using base: AttributeBase,
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
    AccPublic = 0x0001,     // 0b0000 0000 0000 0001
    AccPrivate = 0x0002,    // 0b0000 0000 0000 0010
    AccProteced = 0x0004,   // 0b0000 0000 0000 0100
    AccStatic = 0x0008,     // 0b0000 0000 0000 1000
    AccFinal = 0x0010,      // 0b0000 0000 0001 0000 
    AccInterface = 0x0200,  // 0b0000 0010 0000 0000 
    AccAbstract = 0x0400,   // 0b0000 0100 0000 0000 
    AccSynthetic = 0x1000,  // 0b0001 0000 0000 0000 
    AccAnnotation = 0x2000, // 0b0010 0000 0000 0000 
    AccEnum = 0x4000,       // 0b0100 0000 0000 0000 
}

EnclosingMethod :: struct {
    using base: AttributeBase,
    class_idx: u16,
    method_idx: u16,
}

Synthetic :: struct {
    using base: AttributeBase,
}

Signature :: struct {
    using base: AttributeBase,
    signature_idx: u16,
}

SourceFile :: struct {
    using base: AttributeBase,
    sourcefile_idx: u16,
}

SourceDebugExtension :: struct {
    using base: AttributeBase,
    debug_extension: []u8,
}

LineNumberTable :: struct {
    using base: AttributeBase,
    line_number_table_length: u16,
    line_number_table: []LineNumberTableEntry,
}

LineNumberTableEntry :: struct {
    start_pc: u16,
    line_number: u16,
}

LocalVariableTable :: struct {
    using base: AttributeBase,
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
    using base: AttributeBase,
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

Deprecated :: struct {
    using base: AttributeBase,
}

RuntimeVisibleAnnotations :: struct {
    using base: AttributeBase,
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
    value: ActualElementValue,
}

// TODO: rename
ActualElementValue :: struct #raw_union {
    const_value_idx: u16,
    enum_const_value: EnumConstValue,
    class_info_idx: u16,
    annotation_value: Annotation,
    array_value: ArrayValue,
}

EnumConstValue :: struct {
    type_name_idx: u16,
    const_name_idx: u16,
}

ArrayValue :: struct {
    num_values: u16,
    values: []ElementValue,
}

RuntimeInvisibleAnnotations :: struct {
    using base: AttributeBase,
    num_annotations: u16,
    annotations: []Annotation,
}

RuntimeVisibleParameterAnnotations :: struct {
    using base: AttributeBase,
    num_parameters: u8,
    parameter_annotations: []ParameterAnnotation,
}

RuntimeInvisibleParameterAnnotations :: struct {
    using base: AttributeBase,
    num_parameters: u8,
    parameter_annotations: []ParameterAnnotation,
}

ParameterAnnotation :: struct {
    num_annotations: u16,
    annotations: []Annotation,
}

AnnotationDefault :: struct {
    using base: AttributeBase,
    default_value: ElementValue,
}

BootstrapMethods :: struct {
    using base: AttributeBase,
    num_bootstrap_methods: u16,
    bootstrap_methods: []BootstrapMethod,
}

BootstrapMethod :: struct {
    bootstrap_method_ref: u16, 
    num_bootstrap_arguments: u16,
    bootstrap_arguments: []u16,
}