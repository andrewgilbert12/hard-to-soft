@256 // initialize stack pointer
D=A
@SP
M=D
@300 // initialize local pointer
D=A
@LCL
M=D
@400 // initialize argument pointer
D=A
@ARG
M=D
@3000 // initialize this pointer
D=A
@THIS
M=D
@3010 // initialize that pointer
D=A
@THAT
M=D
// above isn't necessarily correct? but good enough for testing I suppose
