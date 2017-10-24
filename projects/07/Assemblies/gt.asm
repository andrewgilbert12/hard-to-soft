// implements VM gt (x>y) instruction
// todo: must change names of label per call
@SP
M=M-1
A=M
D=M
@SP
A=M-1
D=D-M
@GT
D;JGT
D=0
@LE
0;JMP
(GT)
D=1
(LE)
@SP
A=M-1
M=D
