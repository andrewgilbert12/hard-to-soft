// implements VM gt (x>y) instruction
// todo: must change names of label per call
@SP
M=M-1
A=M
D=M
@SP
A=M-1
D=D-M
@GT.__VAR1__
D;JGT
D=0
@LE.__VAR1__
0;JMP
(GT.__VAR1__)
D=1
(LE.__VAR1__)
@SP
A=M-1
M=D
