// implements VM lt (x<y) instruction
// todo: must change names of label per call
@SP
M=M-1
A=M
D=M
@SP
A=M-1
D=D-M
@LT
D;JLT
D=0
@GE
0;JMP
(LT)
D=1
(GE)
@SP
A=M-1
M=D
