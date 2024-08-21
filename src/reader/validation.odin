package reader

import "core:strings"

// TODO: revision this below:
// https://docs.oracle.com/javase/specs/jvms/se21/html/jvms-4.html#jvms-4.2.1
// -------------------------------------------------- 
// Binary Class and Interface Names
// -------------------------------------------------- 
// - Fully qualified name (binary name): java.lang.Thread
//   May be drawn from the entire unicode codespace (where not further constrained).
// - Internal form (as found within a ConstantUtf8Info): java/lang/Thread.
//   All identifiers separated by forward slashes must be unqualified names.
// -------------------------------------------------- 


// -------------------------------------------------- 
// Unqualified Names
// -------------------------------------------------- 
// Names of methods, fields, local variables and
// formal parameters: must contain at least one
// unicode point, and must not contain any of .;[/
// Method names are further constrainted, they must
// not be <init>, <clinit> or contain a < or > char
// -------------------------------------------------- 


// -------------------------------------------------- 
// Module Names
// -------------------------------------------------- 
// Wrapped by a ConstantUtf8Info, module names are
// not stored in their binary name, meaning ascii
// periods are not replaced by forward slashes.
// A few constraints:
// - Names may not contain any char within the range 
//   '\u0000'..='\u001F'
// - Ascii backslash is used as an escape character,
// it must not appear unless it's followed by another
// backslash or any of the character :@
// - As mentioned above, : and @ must not appear unless
//   they are escaped
// -------------------------------------------------- 

MAX_ARRAY_DEPTH :: 255

// NOTE: we are including < and > because <init> and <clinit> are not validated here
@(private)
unqualified_name_invalid_chars := strings.ascii_set_make(".:[/<>") or_else panic("sanity check")

// FieldDescriptor = FieldType
// FieldType = BaseType | ObjectType | ArrayType
// BaseType = B | C | D | F | I | J | S | Z
// ObjectType = L ClassName ;
// (? ClassName is a binary class name encoded in internal form ?)
// ArrayType = {\[}+ ComponentType
// ComponentType = FieldType
is_valid_field_descriptor :: proc(desc: string) -> bool #no_bounds_check {
    if len(desc) == 0 do return false

    switch desc[0] {
    case 'B', 'C', 'D', 'F', 'I', 'J', 'S', 'Z': return len(desc) == 1
    case 'L':
        if len(desc) < 3 || desc[len(desc) - 1] != ';' do return false // Lx;
        return is_valid_object_type(desc[1:len(desc) - 1])
    case '[':
        array_depth := 1
        for array_depth < len(desc) && desc[array_depth] == '[' {
            array_depth += 1
            if array_depth > MAX_ARRAY_DEPTH do return false
        }
        return is_valid_field_descriptor(desc[array_depth:])
    }
    return false
}

// MethodDescriptor = \( {ParameterDescriptor}+ \) ReturnDescriptor
// ParameterDescriptor = FieldType
// ReturnDescriptor = FieldType | VoidDescriptor
// VoidDescriptor = V
is_valid_method_descriptor :: proc(desc: string) -> bool #no_bounds_check {
    if len(desc) < 4 || desc[0] != '(' do return false // shortest: (I)I 

    for i := 1; i < len(desc); {
        switch desc[i] {
        case 'B', 'C', 'D', 'F', 'I', 'J', 'S', 'Z', '[': i += 1
        case 'L':
            end := strings.index_byte(desc, ';')
            if end == -1 do return false // unterminated
            object_type := desc[i + 1:end - 1]
            if !is_valid_object_type(object_type) do return false
            i = end + 1
        }
    }

    return true
}

// Inputs:
//  s: an ObjectType with the 'L' and ';' stripped, e.g. "java/lang/Thread"
// Caller must guarantee len(s) > 0
@(private)
is_valid_object_type :: proc(s: string) -> bool {
    for i in 0..<len(s) {
        switch s[i] {
        case '/': if i == 0 || i == len(s) - 1 do return false
        case '.', ';', '[', '<', '>': return false
        }
    }
    return true
}
