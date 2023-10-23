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

stack_map_frame_destroy :: proc(frame: StackMapFrame) {
    #partial switch &frame in frame {
        case AppendFrame:
            delete(frame.locals)
        case FullFrame:
            delete(frame.locals)
            delete(frame.stack)
    }
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

APPEND_FRAME_LOCALS_OFFSET :: 251

AppendFrame :: struct {
    offset_delta: u16,
    // size: frame_type - APPEND_FRAME_LOCALS_OFFSET
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
TopVariableInfo     :: struct {}
IntegerVariableInfo :: struct {}
FloatVariableInfo   :: struct {}
LongVariableInfo    :: struct {}
DoubleVariableInfo  :: struct {}
NullVariableInfo    :: struct {}
UninitializedThisVariableInfo :: struct {}

ObjectVariableInfo :: struct {
    cp_idx: u16,
}

UninitializedVariableInfo :: struct {
    offset: u16,
}