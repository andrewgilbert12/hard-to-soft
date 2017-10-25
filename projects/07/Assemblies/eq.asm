// implements VM eq (x==0) instruction
// todo: must change names label per call
@SP
A=M-1
D=M
@ZERO.__VAR1__
D;JEQ
D=0
@DONE.__VAR1__
0;JMP
(ZERO.__VAR1__)
D=1
(DONE.__VAR1__)
@SP
A=M-1
M=D
