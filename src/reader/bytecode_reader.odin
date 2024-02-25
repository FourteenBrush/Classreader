package reader

import "../bytecode"

read_opcode :: proc(
	creader: ^ClassFileReader,
) -> (
	opcode: bytecode.Opcode,
	err := Error.UnknownOpcode,
) {
	byte := read_u8(creader) or_return
	return bytecode.opcode_lookup(byte).?, .None
}
