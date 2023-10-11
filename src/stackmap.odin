package main

StackMapFrame :: union {
    SameFrame,
    SaleLocals1StackItemFrame,
    SameLocals1StackItemFrameExtended,
    ChopFrame,
    SameFrameExtended,
    AppendFrame,
    FullFrame,
}

SameFrame :: struct {
    frame_type: u8,
}

SaleLocals1StackItemFrame :: struct {
    frame_type: u8,
    stack: [1]VerificationTypeInfo,
}

SameLocals1StackItemFrameExtended :: struct {
    frame_type: u8,
    offset_delta: u16,
    stack: [1]VerificationTypeInfo,
}

ChopFrame :: struct {
    frame_type: u8,
    offset_delta: u16,
}

SameFrameExtended :: struct {
    frame_type: u8,
    offset_delta: u16,
}

AppendFrame :: struct {
    frame_type: u8,
    offset_delta: u16,
    // size: frame_type - 251
    locals: []VerificationTypeInfo,
}

FullFrame :: struct {
    frame_type: u8,
    offset_delta: u16,
    number_of_locals: u16,
    locals: []VerificationTypeInfo,
    number_of_stack_items: u16,
    stack: []VerificationTypeInfo,
}

// TODO: type aliases?
VerificationTypeInfo :: union {
    TopVariableInfo,
    IntegerVariableInfo,
    FloatVariableInfo,
    LongVariableInfo,
    DoubleVariableInfo,
    NullVariableInfo,
    UninitializedThisVariableInfo,
    ObjectVariableInfo,
    UninitializedVariableInfo,
}

TopVariableInfo :: struct {
    tag: u8,
}

IntegerVariableInfo :: struct {
    tag: u8,
}

FloatVariableInfo :: struct {
    tag: u8,
}

LongVariableInfo :: struct {
    tag: u8,
}

DoubleVariableInfo :: struct {
    tag: u8,
}

NullVariableInfo :: struct {
    tag: u8,
}

UninitializedThisVariableInfo :: struct {
    tag: u8,
}

ObjectVariableInfo :: struct {
    tag: u8,
    cp_idx: u16,
}

UninitializedVariableInfo :: struct {
    tag: u8,
    offset: u16,
}

AttributeBase :: struct {
    attribute_name_idx: u16,
    attribute_length: u16,
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
    inner_name_idx: u16,
    inner_class_access_flags: u16,
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
}

BootstrapMethod :: struct {
    bootstrap_method_ref: u16, 
    num_bootstrap_arguments: u16,
    bootstrap_arguments: []u16,
}


