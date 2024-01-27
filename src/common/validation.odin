package common

import "core:strings"

@private
BINARY_CLASS_NAME_CHARS := get_binary_class_name_chars()

@private
get_binary_class_name_chars :: proc() -> strings.Ascii_Set {
    VALID_CHARS :: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ/"
    set, ok := strings.ascii_set_make(VALID_CHARS)
    assert(ok, "sanity check")
    return set
}

/*
Validates a field descriptor string.

Inputs:
- desc: the string
- partial: whether or not the desc is part of a bigger string
  (e.g. for parsing method descriptors), and thus is not a valid field descriptor on its own.
*/
validate_field_descriptor :: proc(desc: string, partial := false) -> bool {
    switch desc[0] {
    case 'B', 'C', 'D', 'F', 'I', 'J', 'S', 'Z': return partial || len(desc) == 1
    case 'L':
        if desc[len(desc) - 1] != ';' do return false
        // account for leading L and trailing ;
        for i in 1..<len(desc) -1 {
            if !strings.ascii_set_contains(BINARY_CLASS_NAME_CHARS, desc[i]) {
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
        return validate_field_descriptor(desc[:array_depth], partial=true) 
    case: return false
    }
}

validate_method_descriptor :: proc(desc: string) -> bool {
    if len(desc) == 0 || desc[0] != '(' do return false

    for i in 1..<len(desc) {
        switch desc[i] {
        case 'B', 'C', 'D', 'F', 'I', 'J', 'S', 'Z':
            unimplemented()
        } 
    }

    return true
}
