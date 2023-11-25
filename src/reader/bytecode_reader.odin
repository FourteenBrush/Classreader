package reader

import "core:reflect"

import "../bytecode"

read_opcode :: proc(creader: ^ClassFileReader) -> (opcode: bytecode.Opcode, err: Error) {
    byte := read_unsigned_byte(creader) or_return
    assert(reflect.enum_string(bytecode.Opcode(byte)) != "", "invalid opcode")
    return bytecode.Opcode(byte), .None
}
