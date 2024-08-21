package bytecode

import "core:fmt"
import "base:intrinsics"

// Tries to convert a byte to an Opcode
opcode_lookup :: proc(op: u8) -> (opcode: Opcode, ok: bool) {
    // We don't handle reserved opcodes (0xca to 0xff)
    // And the range breaks there too, 0xcb, 0xcc and 0xcd don't exist
    if op < u8(Opcode.Breakpoint) {
        opcode, ok = Opcode(op), true
    }
    return
}

Instruction :: struct {
    opcode:   Opcode,
    operands: []u8,
}

Stream :: struct {
    codeblob: []u8,
    pos: uint,
}

make_instruction_stream :: proc(codeblob: []u8) -> Stream {
    return Stream{codeblob, 0}
}

// Returns a stream of Instructions, will panic if a reserved instruction is being used.
instruction_stream :: proc(stream: ^Stream) -> (instr: Instruction, ok: bool) {
    if stream.pos >= len(stream.codeblob) do return

    instr.opcode = opcode_lookup(stream.codeblob[stream.pos]) or_return
    stream.pos += 1
    operand_byte_count := find_operand_byte_count(instr.opcode, stream) or_return

    ensure_readable(stream, operand_byte_count) or_return
    #no_bounds_check instr.operands = stream.codeblob[stream.pos:][:operand_byte_count]

    stream.pos += uint(operand_byte_count)
    return instr, true
}

@(private)
find_operand_byte_count :: proc(opcode: Opcode, stream: ^Stream) -> (count: int, ok: bool) {
    #no_bounds_check count = operand_count_lookup[opcode]
    fmt.assertf(unlikely(count == RESERVED_OPCODE_OPERAND_COUNT), "reserved opcode (%s) used in a bytecode.Stream", opcode)
    
    if count != OPERAND_COUNT_REQUIRES_FURTHER_INSPECTION do return count, true

    #partial switch opcode {
    case .TableSwitch:
        padding := stream.pos & 3
        advance_to(stream, align_up_to_u32(stream.pos)) or_return

        _ = peek(u32, stream) or_return // default
        low := peek(u32, stream, 4) or_return
        high := peek(u32, stream, 8) or_return
        noffsets := high - low + 1
        
        offset_size :: 4
        ensure_readable(stream, noffsets * offset_size) or_return
        count = int(padding) + 4 + 4 + 4 + int(noffsets) * offset_size
    case .LookupSwitch:
        padding := stream.pos & 3
        advance_to(stream, align_up_to_u32(stream.pos)) or_return

        _ = peek(u32, stream) or_return // default
        npairs := peek(u32, stream, 4) or_return

        pair_size :: 4 + 4
        ensure_readable(stream, npairs * pair_size) or_return
        count = int(padding) + 4 + 4 + int(npairs) * pair_size
    case .Wide:
        modified_opcode := peek(Opcode, stream) or_return
        count = 4 if modified_opcode == .Iinc else 2
    case: unreachable()
    }

    return
}

@(private, require_results)
read :: proc($T: typeid, s: ^Stream) -> (T, bool) {
    if s.pos + size_of(T) > len(s.codeblob) {
        return {}, false
    }
    buf: [size_of(T)]u8
    copy(buf[:], s.codeblob[s.pos:])
    s.pos += size_of(T)
    return transmute(T) buf, true
}

@(private, require_results)
peek :: proc($T: typeid, s: ^Stream, start := uint(0)) -> (T, bool) {
    if s.pos + start + size_of(T) > len(s.codeblob) {
        return {}, false
    }
    buf: [size_of(T)]u8
    copy(buf[:], s.codeblob[s.pos + start:])
    return transmute(T) buf, true
}

@(private, require_results)
advance_to :: proc(s: ^Stream, pos: uint) -> bool {
    if pos >= len(s.codeblob) do return false
    s.pos = pos
    return true
}

@(private, require_results)
ensure_readable :: proc(s: ^Stream, #any_int nbytes: uint) -> bool {
    return s.pos + nbytes <= len(s.codeblob)
}

@(private)
align_up_to_u32 :: proc(x: uint) -> uint {
    x := x
    mod := x & (4 - 1)
    if mod != 0 {
        x += 4 - mod
    }
    return x
}

@(private)
unlikely :: #force_inline proc(cond: bool) -> bool {
    return !intrinsics.expect(cond, false)
}

OPERAND_COUNT_REQUIRES_FURTHER_INSPECTION :: -1
RESERVED_OPCODE_OPERAND_COUNT :: -2

// opcode to amount of bytes following
@(private, rodata)
operand_count_lookup := #sparse[Opcode]int {
    .Nop             = 0,
    .AconstNull      = 0,
    .IconstM1        = 0,
    .Iconst0         = 0,
    .Iconst1         = 0,
    .Iconst2         = 0,
    .Iconst3         = 0,
    .Iconst4         = 0,
    .Iconst5         = 0,
    .Lconst0         = 0,
    .Lconst1         = 0,
    .Fconst0         = 0,
    .Fconst1         = 0,
    .Fconst2         = 0,
    .Dconst0         = 0,
    .Dconst1         = 0,
    .Bipush          = 1,
    .Sipush          = 2,
    .Ldc             = 1,
    .LdcW            = 2,
    .Ldc2W           = 2,
    .Iload           = 1,
    .Lload           = 1,
    .Fload           = 1,
    .Dload           = 1,
    .Aload           = 1,
    .Iload0          = 0,
    .Iload1          = 0,
    .Iload2          = 0,
    .Iload3          = 0,
    .Lload0          = 0,
    .Lload1          = 0,
    .Lload2          = 0,
    .Lload3          = 0,
    .Fload0          = 0,
    .Fload1          = 0,
    .Fload2          = 0,
    .Fload3          = 0,
    .Dload0          = 0,
    .Dload1          = 0,
    .Dload2          = 0,
    .Dload3          = 0,
    .Aload0          = 0,
    .Aload1          = 0,
    .Aload2          = 0,
    .Aload3          = 0,
    .Iaload          = 0,
    .Laload          = 0,
    .Faload          = 0,
    .Daload          = 0,
    .Aaload          = 0,
    .Baload          = 0,
    .Caload          = 0,
    .Saload          = 0,
    .Istore          = 1,
    .Lstore          = 1,
    .Fstore          = 1,
    .Dstore          = 1,
    .Astore          = 1,
    .Istore0         = 0,
    .Istore1         = 0,
    .Istore2         = 0,
    .Istore3         = 0,
    .Lstore0         = 0,
    .Lstore1         = 0,
    .Lstore2         = 0,
    .Lstore3         = 0,
    .Fstore0         = 0,
    .Fstore1         = 0,
    .Fstore2         = 0,
    .Fstore3         = 0,
    .Dstore0         = 0,
    .Dstore1         = 0,
    .Dstore2         = 0,
    .Dstore3         = 0,
    .Astore0         = 0,
    .Astore1         = 0,
    .Astore2         = 0,
    .Astore3         = 0,
    .Iastore         = 0,
    .Lastore         = 0,
    .Fastore         = 0,
    .Dastore         = 0,
    .Aastore         = 0,
    .Bastore         = 0,
    .Castore         = 0,
    .Sastore         = 0,
    .Pop             = 0,
    .Pop2            = 0,
    .Dup             = 0,
    .DupX1           = 0,
    .DupX2           = 0,
    .Dup2            = 0,
    .Dup2X1          = 0,
    .Dup2X2          = 0,
    .Swap            = 0,
    .Iadd            = 0,
    .Ladd            = 0,
    .Fadd            = 0,
    .Dadd            = 0,
    .Isub            = 0,
    .Lsub            = 0,
    .Fsub            = 0,
    .Dsub            = 0,
    .Imul            = 0,
    .Lmul            = 0,
    .Fmul            = 0,
    .Dmul            = 0,
    .Idiv            = 0,
    .Ldiv            = 0,
    .Fdiv            = 0,
    .Ddiv            = 0,
    .Irem            = 0,
    .Lrem            = 0,
    .Frem            = 0,
    .Drem            = 0,
    .Ineg            = 0,
    .Lneg            = 0,
    .Fneg            = 0,
    .Dneg            = 0,
    .Ishl            = 0,
    .Lshl            = 0,
    .Ishr            = 0,
    .Lshr            = 0,
    .Iushr           = 0,
    .Lushr           = 0,
    .Iand            = 0,
    .Land            = 0,
    .Ior             = 0,
    .Lor             = 0,
    .Ixor            = 0,
    .Lxor            = 0,
    .Iinc            = 0,
    .I2l             = 0,
    .I2f             = 0,
    .I2d             = 0,
    .L2i             = 0,
    .L2l             = 0,
    .L2f             = 0,
    .D2i             = 0,
    .D2l             = 0,
    .D2f             = 0,
    .F2i             = 0,
    .F2l             = 0,
    .F2d             = 0,
    .I2b             = 0,
    .I2c             = 0,
    .I2s             = 0,
    .Lcmp            = 0,
    .Fcmpl           = 0,
    .Fcmpg           = 0,
    .Dcmpl           = 0,
    .Dcmpg           = 0,
    .IfEq            = 2,
    .IfNe            = 2,
    .IfLt            = 2,
    .IfGe            = 2,
    .IfGt            = 2,
    .IfLe            = 2,
    .IfIcmpEq        = 2,
    .IfIcmpNe        = 2,
    .IfIcmpLt        = 2,
    .IfIcmpGe        = 2,
    .IfIcmpGt        = 2,
    .IfIcmpLe        = 2,
    .IfAcmpEq        = 2,
    .IfAcmpNe        = 2,
    .Goto            = 2,
    .Jsr             = 4,
    .Ret             = 1,
    .TableSwitch     = OPERAND_COUNT_REQUIRES_FURTHER_INSPECTION,
    .LookupSwitch    = OPERAND_COUNT_REQUIRES_FURTHER_INSPECTION,
    .Ireturn         = 0,
    .Lreturn         = 0,
    .Freturn         = 0,
    .Dreturn         = 0,
    .Areturn         = 0,
    .Return          = 0,
    .GetStatic       = 2,
    .PutStatic       = 2,
    .GetField        = 2,
    .PutField        = 2,
    .InvokeVirtual   = 2,
    .InvokeSpecial   = 2,
    .InvokeStatic    = 2,
    .InvokeInterface = 2,
    .InvokeDynamic   = 4, // 2 + 2 bytes set to zero
    .New             = 2,
    .NewArray        = 2,
    .ANewArray       = 2,
    .ArrayLength     = 0,
    .Athrow          = 0,
    .CheckCast       = 2,
    .Instanceof      = 2,
    .MonitorEnter    = 0,
    .MonitorExit     = 0,
    .Wide            = OPERAND_COUNT_REQUIRES_FURTHER_INSPECTION,
    .MultiANewArray  = 3,
    .IfNull          = 2,
    .IfNonNull       = 2,
    .GotoW           = 4,
    .JsrW            = 2,
    .Breakpoint      = RESERVED_OPCODE_OPERAND_COUNT,
    .ImpDep1         = RESERVED_OPCODE_OPERAND_COUNT,
    .ImpDep2         = RESERVED_OPCODE_OPERAND_COUNT,
}

// https://docs.oracle.com/javase/specs/jvms/se21/html/jvms-6.html
// https://docs.oracle.com/javase/specs/jvms/se21/html/jvms-7.html 
Opcode :: enum u8 {
    // Constants
    Nop             = 0x00,
    AconstNull      = 0x01,
    IconstM1        = 0x02,
    Iconst0         = 0x03,
    Iconst1         = 0x04,
    Iconst2         = 0x05,
    Iconst3         = 0x06,
    Iconst4         = 0x07,
    Iconst5         = 0x08,
    Lconst0         = 0x09,
    Lconst1         = 0x0a,
    Fconst0         = 0x0b,
    Fconst1         = 0x0c,
    Fconst2         = 0x0d,
    Dconst0         = 0x0e,
    Dconst1         = 0x0f,
    Bipush          = 0x10,
    Sipush          = 0x11,
    Ldc             = 0x12,
    LdcW            = 0x13,
    Ldc2W           = 0x14,
    // Loads
    Iload           = 0x15,
    Lload           = 0x16,
    Fload           = 0x17,
    Dload           = 0x18,
    Aload           = 0x19,
    Iload0          = 0x1a,
    Iload1          = 0x1b,
    Iload2          = 0x1c,
    Iload3          = 0x1d,
    Lload0          = 0x1e,
    Lload1          = 0x1f,
    Lload2          = 0x20,
    Lload3          = 0x21,
    Fload0          = 0x22,
    Fload1          = 0x23,
    Fload2          = 0x24,
    Fload3          = 0x25,
    Dload0          = 0x26,
    Dload1          = 0x27,
    Dload2          = 0x28,
    Dload3          = 0x29,
    Aload0          = 0x2a,
    Aload1          = 0x2b,
    Aload2          = 0x2c,
    Aload3          = 0x2d,
    Iaload          = 0x2e,
    Laload          = 0x2f,
    Faload          = 0x30,
    Daload          = 0x31,
    Aaload          = 0x32,
    Baload          = 0x33,
    Caload          = 0x34,
    Saload          = 0x35,
    // Stores
    Istore          = 0x36,
    Lstore          = 0x37,
    Fstore          = 0x38,
    Dstore          = 0x39,
    Astore          = 0x3a,
    Istore0         = 0x3b,
    Istore1         = 0x3c,
    Istore2         = 0x3d,
    Istore3         = 0x3e,
    Lstore0         = 0x3f,
    Lstore1         = 0x40,
    Lstore2         = 0x41,
    Lstore3         = 0x42,
    Fstore0         = 0x43,
    Fstore1         = 0x44,
    Fstore2         = 0x45,
    Fstore3         = 0x46,
    Dstore0         = 0x47,
    Dstore1         = 0x48,
    Dstore2         = 0x49,
    Dstore3         = 0x4a,
    Astore0         = 0x4b,
    Astore1         = 0x4c,
    Astore2         = 0x4d,
    Astore3         = 0x4e,
    Iastore         = 0x4f,
    Lastore         = 0x50,
    Fastore         = 0x51,
    Dastore         = 0x52,
    Aastore         = 0x53,
    Bastore         = 0x54,
    Castore         = 0x55,
    Sastore         = 0x56,
    // Stack
    Pop             = 0x57,
    Pop2            = 0x58,
    Dup             = 0x59,
    DupX1           = 0x5a,
    DupX2           = 0x5b,
    Dup2            = 0x5c,
    Dup2X1          = 0x5d,
    Dup2X2          = 0x5e,
    Swap            = 0x5f,
    // Math
    Iadd            = 0x60,
    Ladd            = 0x61,
    Fadd            = 0x62,
    Dadd            = 0x63,
    Isub            = 0x64,
    Lsub            = 0x65,
    Fsub            = 0x66,
    Dsub            = 0x67,
    Imul            = 0x68,
    Lmul            = 0x69,
    Fmul            = 0x6a,
    Dmul            = 0x6b,
    Idiv            = 0x6c,
    Ldiv            = 0x6d,
    Fdiv            = 0x6e,
    Ddiv            = 0x6f,
    Irem            = 0x70,
    Lrem            = 0x71,
    Frem            = 0x72,
    Drem            = 0x73,
    Ineg            = 0x74,
    Lneg            = 0x75,
    Fneg            = 0x76,
    Dneg            = 0x77,
    Ishl            = 0x78,
    Lshl            = 0x79,
    Ishr            = 0x7a,
    Lshr            = 0x7b,
    Iushr           = 0x7c,
    Lushr           = 0x7d,
    Iand            = 0x7e,
    Land            = 0x7f,
    Ior             = 0x80,
    Lor             = 0x81,
    Ixor            = 0x82,
    Lxor            = 0x83,
    Iinc            = 0x84,
    // Conversions
    I2l             = 0x85,
    I2f             = 0x86,
    I2d             = 0x87,
    L2i             = 0x88,
    L2l             = 0x89,
    L2f             = 0x8a,
    D2i             = 0x8b,
    D2l             = 0x8c,
    D2f             = 0x8d,
    F2i             = 0x8e,
    F2l             = 0x8f,
    F2d             = 0x90,
    I2b             = 0x91,
    I2c             = 0x92,
    I2s             = 0x93,
    // Comparisons
    Lcmp            = 0x94,
    Fcmpl           = 0x95,
    Fcmpg           = 0x96,
    Dcmpl           = 0x97,
    Dcmpg           = 0x98,
    IfEq            = 0x99,
    IfNe            = 0x9a,
    IfLt            = 0x9b,
    IfGe            = 0x9c,
    IfGt            = 0x9d,
    IfLe            = 0x9e,
    IfIcmpEq        = 0x9f,
    IfIcmpNe        = 0xa0,
    IfIcmpLt        = 0xa1,
    IfIcmpGe        = 0xa2,
    IfIcmpGt        = 0xa3,
    IfIcmpLe        = 0xa4,
    IfAcmpEq        = 0xa5,
    IfAcmpNe        = 0xa6,
    // Control
    Goto            = 0xa7,
    Jsr             = 0xa8,
    Ret             = 0xa9,
    TableSwitch     = 0xaa,
    LookupSwitch    = 0xab,
    Ireturn         = 0xac,
    Lreturn         = 0xad,
    Freturn         = 0xae,
    Dreturn         = 0xaf,
    Areturn         = 0xb0,
    Return          = 0xb1,
    // References
    GetStatic       = 0xb2,
    PutStatic       = 0xb3,
    GetField        = 0xb4,
    PutField        = 0xb5,
    InvokeVirtual   = 0xb6,
    InvokeSpecial   = 0xb7,
    InvokeStatic    = 0xb8,
    InvokeInterface = 0xb9,
    InvokeDynamic   = 0xba,
    New             = 0xbb,
    NewArray        = 0xbc,
    ANewArray       = 0xbd,
    ArrayLength     = 0xbe,
    Athrow          = 0xbf,
    CheckCast       = 0xc0,
    Instanceof      = 0xc1,
    MonitorEnter    = 0xc2,
    MonitorExit     = 0xc3,
    // Extended
    Wide            = 0xc4,
    MultiANewArray  = 0xc5,
    IfNull          = 0xc6,
    IfNonNull       = 0xc7,
    GotoW           = 0xc8,
    JsrW            = 0xc9,
    // Reserved
    Breakpoint      = 0xca,
    ImpDep1         = 0xfe,
    ImpDep2         = 0xff,
}
