// implements VM eq (x==0) instruction
// todo: must change names label per call
@SP
A=M-1
D=M
@ZERO
D;JEQ
D=0
@DONE
0;JMP
(ZERO)
D=1
(DONE)
@SP
A=M-1
M=D
