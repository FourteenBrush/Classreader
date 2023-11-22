package common

// Each stack map frame specifies (either explicitly or implicitly) a bytecode offset,
// the verification types for the local variables, and the verification types for the operand stack.
StackMapFrame :: union {
    SameFrame,
    SameLocals1StackItemFrame,
    SameLocals1StackItemFrameExtended,
    ChopFrame,
    SameFrameExtended,
    AppendFrame,
    FullFrame,
}

// StackMapFrame destructor.
stack_map_frame_destroy :: proc(frame: StackMapFrame) {
    #partial switch &frame in frame {
        case AppendFrame:
            delete(frame.locals)
        case FullFrame:
            delete(frame.locals)
            delete(frame.stack)
    }
}

// The frame has exactly the same locals as the previous stack map frame 
// and the number of stack items is zero.
// Represented by tags in the range [0, 63].
SameFrame :: struct {}

// The frame has exactly the same locals as the previous stack map frame
// and the number of stack items is 1.
// Represented by tags in the range [64, 127].
SameLocals1StackItemFrame :: struct {
    stack: VerificationTypeInfo,
}

// The frame has exactly the same locals as the previous stack map frame 
// and the number of stack items is 1.
// Represented by the tag 247.
SameLocals1StackItemFrameExtended :: struct {
    offset_delta: u16,
    stack: VerificationTypeInfo,
}


// The operand stack is empty and the current locals are the same as the locals in the previous frame,
// except that the k last locals are absent.
// The value of k is given by the formula 251 (FRAME_LOCALS_OFFSET) - frame_type.
// Represented by tags in the range [248-250].
ChopFrame :: struct {
    offset_delta: u16,
}

// The frame has exactly the same locals as the previous stack map frame and
// the number of stack items is zero.
// Represented by the tag value 251.
SameFrameExtended :: struct {
    offset_delta: u16,
}

FRAME_LOCALS_OFFSET :: 251

// the operand stack is empty and the current locals are the same as the locals in the previous frame, except that k additional locals are defined.
// The value of k is given by the formula frame_type - 251.
// Represented by tags in the range [252-254].
AppendFrame :: struct {
    offset_delta: u16,
    // size: frame_type - FRAME_LOCALS_OFFSET
    locals: []VerificationTypeInfo,
}

// Represented by the tag value 255.
FullFrame :: struct {
    offset_delta: u16,
    locals: []VerificationTypeInfo,
    stack: []VerificationTypeInfo,
}

// Each verification_type_info structure specifies the verification type of one or two locations.
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

// Indicates that the local variable has the verification type top.
TopVariableInfo     :: struct {}
// Indicates that the location contains the verification type int.
IntegerVariableInfo :: struct {}
// Iindicates that the location contains the verification type float.
FloatVariableInfo   :: struct {}
// Indicates that the location contains the verification type long. 
LongVariableInfo    :: struct {}
// Indicates that the location contains the verification type double.
DoubleVariableInfo  :: struct {}
// Indicates that location contains the verification type null.
NullVariableInfo    :: struct {}
// Indicates that the location contains the verification type uninitializedThis. 
UninitializedThisVariableInfo :: struct {}

// Indicates that the location contains an instance of the class 
// represented by the ConstantClassInfo structure at the index given by cp_idx.
ObjectVariableInfo :: struct {
    cp_idx: u16,
}

// Indicates that the location contains the verification type uninitialized(offset).
// The offset item indicates the offset, in the code array of the Code attribute
// that contains this StackMapTable attribute, of the new instruction
// that created the object being stored in the location.
UninitializedVariableInfo :: struct {
    offset: u16,
}
