package classreader

import "core:strings"

@private
BINARY_CLASS_NAME_CHARS := get_binary_class_name_chars()

@private
get_binary_class_name_chars :: proc() -> strings.Ascii_Set {
    VALID_CHARS :: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ/"
    set, ok := strings.ascii_set_make(VALID_CHARS)
    assert(ok)
    return set
}

validate_field_descriptor :: proc(desc: string, start_idx := 0, partial := false) -> bool {
    switch desc[start_idx] {
        case 'B', 'C', 'D', 'F', 'I', 'J', 'S', 'Z': return partial || len(desc) == 1
        case 'L':
            if desc[len(desc) - 1] != ';' do return false
            // account for leading L and trailing ;
            for i := start_idx + 1; i < len(desc) - 1; i += 1 {
                byte := byte(desc[i])
                if !strings.ascii_set_contains(BINARY_CLASS_NAME_CHARS, byte) {
                    return false
                }
            }
            return true
        case '[':
            MAX_ARRAY_DEPTH :: 255
            array_depth := 1
            for desc[array_depth] == '[' {
                array_depth += 1
                if array_depth > MAX_ARRAY_DEPTH do return false
            }
            return validate_field_descriptor(desc, array_depth, partial=true) 
        case: return false
    }
}

validate_method_descriptor :: proc(desc: string) -> bool {
    if desc[0] != '(' do return false
    panic("todo") 
}
