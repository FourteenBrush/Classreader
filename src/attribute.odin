package classreader

@(private="file") // got a redefinition
AttributeInfo :: struct {
    name_idx: u16,
    length: u32,
    info: []u8,
}

ConstantValue :: struct {
    name_idx: u16,
    attribute_length: u32,
    constantvalue_idx: u16,
}

Code :: struct {
    // Cp index pointing to a Utf8Info entry
    attribute_name_idx: u16,
    attribute_length: u32,
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
    attribute_name_idx: u16,
    attribubte_length: u32,
    number_of_entries: u16,
    entries: []StackMapFrame,
}