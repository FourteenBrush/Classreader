package classreader

// Used by a ClassFile, FieldInfo, MethodInfo, and CodeAttribute
AttributeInfo :: struct {
    name_idx: u16,
    length: u32,
    info: AttributeInfoInner,
}

// TODO: rename
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
    using base: AttributeBase,
    constantvalue_idx: u16,
}

Code :: struct {
    using base: AttributeBase,
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
    using base: AttributeBase,
    number_of_entries: u16,
    entries: []StackMapFrame,
}