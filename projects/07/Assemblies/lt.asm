// implements VM lt (x<y) instruction
// todo: must change names of label per call
@SP
M=M-1
A=M
D=M
@SP
A=M-1
D=D-M
@LT.__VAR1__
D;JLT
D=0
@GE.__VAR1__
0;JMP
(LT.__VAR1__)
D=1
(GE.__VAR1__)
@SP
A=M-1
M=D
