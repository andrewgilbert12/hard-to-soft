// This file is part of www.nand2tetris.org
// and the book "The Elements of Computing Systems"
// by Nisan and Schocken, MIT Press.
// File name: projects/04/Fill.asm

// Runs an infinite loop that listens to the keyboard input.
// When a key is pressed (any key), the program blackens the screen,
// i.e. writes "black" in every pixel;
// the screen should remain fully black as long as the key is pressed. 
// When no key is pressed, the program clears the screen, i.e. writes
// "white" in every pixel;
// the screen should remain fully clear as long as no key is pressed.

(CHECK)
@SCREEN // set R0 to start of screen - 1
D=A
@0
M=D-1
@KBD // set R1 to end of screen - 1
D=A
@1
M=D-1
M=M-1
@KBD // determine if keyboard is being pressed or not
D=M
@NOTPRESSED // jump to the appropriate action
D;JEQ

(PRESSED)
@0
A=M
A=A+1 // increment
M=-1
D=A
@0
M=D
@1
D=D-M
@PRESSED
D;JLT
@CHECK // when we're done filling go back and check again
0;JMP

(NOTPRESSED)
@0
A=M
A=A+1 // increment
M=0
D=A
@0
M=D
@1
D=D-M
@NOTPRESSED
D;JLT
@CHECK // when we're done filling go back and check again
0;JMP
