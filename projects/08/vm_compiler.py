#!/usr/bin/env python3
# compiles VM code into ASM
import os
import re
import argparse


class Parser():
    def __init__(self, file):
        with open(file, 'r') as f:
            lines = f.readlines()
        lines = map(self._cleanLine, lines)
        self.lines = list(filter(None, lines))  # remove lines with no code
        self.current_line = 0
        self.dict = {
            "C_ARITHMETIC": "(add|and|neg|not|or|sub|eq|gt|lt)",
            "C_LABEL": "label ([\w_.][\d\w_.]*)",
            "C_GOTO": "goto ([\w_.][\d\w_.]*)",
            "C_IF": "if-goto ([\w_.][\d\w_.]*)",
            "C_PUSH": "push (local|argument|this|that|temp|pointer|static|constant) (\d+)",
            "C_POP": "pop (local|argument|this|that|temp|pointer|static|constant) (\d+)",
            "C_FUNCTION": "function ([\w_.][\d\w_.]*) (\d+)",
            "C_CALL": "call ([\w_.][\d\w_.]*) (\d)+",
            "C_RETURN": "return"
        }


    @staticmethod
    def _cleanLine(line):
        # remove the following:
        line = re.sub('^\s*', '', line)  # leading spaces
        line = re.sub('\s\s*', ' ', line)  # duplicated spaces
        line = re.sub('//.*$', '', line)  # in-line comments
        return line


    def hasMoreCommands(self):
        """Returns whether there are still commands to be processed by the parser."""
        return self.current_line < len(self.lines)


    def advance(self):
        """Advances the parser one line forward."""
        self.current_line += 1


    def commandType(self):
        """Returns the command type of the current line, which will be one of:
        C_ARITHMETIC, C_PUSH, C_POP, C_LABEL, C_GOTO, C_IF, C_FUNCTION, C_RETURN, C_CALL"""
        for cmd, regex in self.dict.items():
            if re.match(regex, self.lines[self.current_line]):
                return cmd


    def arg1(self):
        """Returns first argument of the command on the current line.
        If the current line is a C_ARITHMETIC command, returns the name of the command itself."""
        cmd = self.commandType()
        return re.match(self.dict[cmd], self.lines[self.current_line]).group(1)


    def arg2(self):
        """Returns the second argument of the command on the current line.
        Returns None for any command other than C_PUSH, C_POP, C_FUNCTION, C_CALL."""
        cmd = self.commandType()
        try:
            return re.match(self.dict[cmd], self.lines[self.current_line]).group(2)
        except IndexError:
            return None


class CodeWriter():
    def __init__(self, outFile):
        self.outFile = open(outFile, 'w')
        self.cmpcount = 0
        self.current_function = ""  # global scope at start
        self.mem_dict = {
            "local": "LCL",
            "argument": "ARG",
            "this": "THIS",
            "that": "THAT",
            "pointer": "THIS",
            "temp": "5"
        }
        self.call_count = 0


    def setFileName(self, fileName):
        """Informs codewriter that translation of new vm file is started,
        and sets the name of the current file."""
        self.fileName = fileName


    def writeInit(self):
        """Output bootstrap code needed to interface with OS.
        Sets up the stack and runs Sys.init."""
        # push 256 to SP
        self._writeAsm(["@256",
                        "D=A",
                        "@SP",
                        "M=D"])
        self.writeCall("Sys.init", 0)


    def writeArithmetic(self, command):
        """Writes the arithmetic command specified by command.
        command must be one of "add", "and", "or", "not", "neg", "eq", "lt", "gt"."""
        assert(command in ["add", "and", "or", "not", "neg", "eq", "lt", "gt"])
        
        if command in ["not", "neg"]:
            cmd = {"not": "!", "neg": "-"}[command]
            self._writeAsm(["@SP",
                            "A=M-1",
                            "M=" + cmd + "M"])
        elif command in ["eq", "lt", "gt"]:
            self.cmpcount += 1
            jmp = {"eq": "JEQ", "lt": "JLT", "gt": "JGT"}[command]
            self._popFromStack()
            self._writeAsm(["A=A-1",
                            "D=M-D",
                            "@" + command + str(self.cmpcount),
                            "D;" + jmp,
                            "D=0",
                            "@DONE." + str(self.cmpcount),
                            "0;JMP",
                            "(" + command + str(self.cmpcount) + ")",
                            "D=-1",
                            "(DONE." + str(self.cmpcount) + ")",
                            "@SP",
                            "A=M-1",
                            "M=D"])
        else:
            cmd = {"add": "+", "and": "&", "or": "|", "eq": "-", "lt": "-", "gt": "-", "sub": "-"}[command]
            self._popFromStack()
            self._writeAsm(["@SP",
                            "A=M-1",
                            "M=M" + cmd + "D"])


    def writePushPop(self, command, segment, index):
        """Write a push/pop statement to the specified memory location.
        command must be one of "push","pop".
        segment must be on of "local","argument","this","that","temp","pointer","static","constant".
        index must be a non-negative integer."""
        assert(command in ["push", "pop"])
        assert(segment in ["local", "argument", "this", "that", "temp", "pointer", "static", "constant"])
        
        if segment == "constant":
            self._writePushConstant(index)
        elif segment == "static":
            if command == "push":
                self._writePushStatic(index)
            elif command == "pop":
                self._writePopStatic(index)
        elif segment in ["temp", "pointer", "static"]:
            mem = self.mem_dict[segment]
            addr = "A"
            if command == "push":
                self._writePush(mem, index, addr)
            elif command == "pop":
                self._writePop(mem, index, addr)
        else:
            mem = self.mem_dict[segment]
            addr = "M"
            if command == "push":
                self._writePush(mem, index, addr)
            elif command == "pop":
                self._writePop(mem, index, addr)


    def _writeLabel(self, label):
        self._writeAsm(["(" + label + ")"])


    def writeLabel(self, label):
        """Writes the specified label."""
        self._writeLabel(self._localLabel(label))


    def _writeGoto(self, label):
        self._setAddress(label)
        self.outFile.write("0;JMP\n")


    def writeGoto(self, label):
        """Write an unconditional goto that jumps to label."""
        self._writeGoto(self._localLabel(label))


    def _writeIf(self, label):
        self._popFromStack()
        self._setAddress(label)
        self.outFile.write("D;JNE\n")


    def writeIf(self, label):
        """Write a conditional jump to label."""
        self._writeIf(self._localLabel(label))


    def writeCall(self, functionName, numArgs):
        """Writes a call to the function functionName, with numArgs arguments currently on the stack."""
        self.call_count += 1

        return_address = "call$" + functionName + "." + str(self.call_count)
        self._setAddress(return_address)
        self._saveAddress()
        self._pushToStack() # push return address

        self._setAddress("LCL")
        self._saveMemory()
        self._pushToStack()

        self._setAddress("ARG")
        self._saveMemory()
        self._pushToStack()

        self._setAddress("THIS")
        self._saveMemory()
        self._pushToStack()

        self._setAddress("THAT")
        self._saveMemory()
        self._pushToStack()

        self._setAddress("SP")
        self._saveMemory()
        self._setAddress("LCL")
        self._setMemory() # set LCL = SP
        arg_shift = str(numArgs + 5)
        self._setAddress(arg_shift)
        self._writeAsm(["D=D-A"])
        self._setAddress("ARG")
        self._setMemory() # set ARG = SP - n - 5

        self._writeGoto(functionName)
        self._writeLabel(return_address)


    def writeFunction(self, functionName, numLocals):
        """Writes the beginning of the function with the name functionName, and numLocals local variables."""
        self._writeLabel(functionName)

        for _ in range(numLocals):
            self._setAddress("0")
            self._saveAddress()
            self._pushToStack()


    def writeReturn(self):
        """Write a return instruction.
        
        todo: code size for a function with several returns could be optimized
        by writing only one return statement for each function at the end, and then only
        writing a goto to that return statement here."""
        
        # FRAME = LCL
        self._setAddress("LCL")
        self._saveMemory()
        self._setAddress("R13")
        self._setMemory()

        # RET = *(FRAME-5)
        self._setAddress("5")
        self._writeAsm(["D=D-A"])
        self._setAddress()
        self._saveMemory()
        self._setAddress("R14")
        self._setMemory()

        # *ARG = pop()
        self._popFromStack()
        self._setAddress("ARG")
        self._dereference()
        self._setMemory()

        # SP = ARG+1
        self._setAddress("ARG")
        self._writeAsm(["D=M+1"])
        self._setAddress("SP")
        self._setMemory()

        # THAT = *(FRAME-1)
        self._setAddress("R13")
        self._saveMemory()
        self._setAddress("1")
        self._writeAsm(["D=D-A"])
        self._setAddress()
        self._saveMemory()
        self._setAddress("THAT")
        self._setMemory()

        # THIS = *(FRAME-2)
        self._setAddress("R13")
        self._saveMemory()
        self._setAddress("2")
        self._writeAsm(["D=D-A"])
        self._setAddress()
        self._saveMemory()
        self._setAddress("THIS")
        self._setMemory()

        # ARG = *(FRAME-3)
        self._setAddress("R13")
        self._saveMemory()
        self._setAddress("3")
        self._writeAsm(["D=D-A"])
        self._setAddress()
        self._saveMemory()
        self._setAddress("ARG")
        self._setMemory()

        # LCL = *(FRAME-4)
        self._setAddress("R13")
        self._saveMemory()
        self._setAddress("4")
        self._writeAsm(["D=D-A"])
        self._setAddress()
        self._saveMemory()
        self._setAddress("LCL")
        self._setMemory()

        # goto RIP
        self._setAddress("R14")
        self._dereference()
        self._writeAsm(["0;JMP"])


    def close(self):
        """Closes the output file and performs all other necessary end of compile tasks."""
        self.outFile.close()


    def _saveMemory(self):
        self._writeAsm(["D=M"])


    def _setMemory(self):
        self._writeAsm(["M=D"])


    def _localLabel(self, label):
        return self.current_function + "." + label


    def _pushToStack(self):
        """Pushes the value in D onto the stack"""
        self._writeAsm(["@SP",
                        "M=M+1",
                        "A=M-1",
                        "M=D"])


    def _popFromStack(self):
        """Pops value of stack into D"""
        self._writeAsm(["@SP",
                        "M=M-1",
                        "A=M",
                        "D=M"])


    def _dereference(self):
        self._writeAsm(["A=M"])


    def _setAddress(self, addr=None):
        """Updates memory to specified constant/label, or D if none is specified"""
        if addr is None:
            self._writeAsm(["A=D"])
        else:
            self._writeAsm(["@" + addr])


    def _saveAddress(self):
        self._writeAsm(["D=A"])


    def _staticName(self, index):
        return self.fileName + "." + str(index)


    def _writeAsm(self, lines):
        for line in lines:
            self.
            .write(line + "\n")


    def _writePushConstant(self, val):
        self._writeAsm(["@" + val,
                        "D=A"])
        self._pushToStack()


    def _writePushStatic(self, index):
        label = self._staticName(index)
        self._writeAsm(["@" + label,
                        "D=M"])
        self._pushToStack()


    def _writePopStatic(self, index):
        label = self._staticName(index)
        self._popFromStack()
        self._writeAsm(["@" + label,
                        "M=D"])


    def _writePush(self, mem, index, addr):
        self._writeAsm(["@" + mem,
                        "D=" + addr,
                        "@" + str(index),
                        "A=D+A",
                        "D=M"])
        self._pushToStack()


    def _writePop(self, mem, index, addr):
        self._writeAsm(["@" + mem,
                        "D=" + addr,
                        "@" + str(index),
                        "D=D+A",  # addr we pop to
                        "@R13",
                        "M=D"])  # save dest addr in R13
        self._popFromStack()
        self._writeAsm(["@R13",
                        "A=M",
                        "M=D"])


def _compile(parser, writer):
    while parser.hasMoreCommands():
        c_type = parser.commandType()
        if c_type == "C_ARITHMETIC":
            writer.writeArithmetic(parser.arg1())
        if c_type == "C_PUSH":
            writer.writePushPop("push", parser.arg1(), parser.arg2())
        if c_type == "C_POP":
            writer.writePushPop("pop", parser.arg1(), parser.arg2())
        if c_type == "C_LABEL":
            writer.writeLabel(parser.arg1())
        if c_type == "C_GOTO":
            writer.writeGoto(parser.arg1())
        if c_type == "C_IF":
            writer.writeIf(parser.arg1())
        if c_type == "C_FUNCTION":
            writer.writeFunction(parser.arg1(), int(parser.arg2()))
        if c_type == "C_CALL":
            writer.writeCall(parser.arg1(), int(parser.arg2()))
        if c_type == "C_RETURN":
            writer.writeReturn()
        parser.advance()


def compile(target, bootstrap=False):
    """Compiles the target specified, optionally appending bootstrap code.
    
    If the target path is a directory, we compile all files in the directory 
    with the extension ".vm" and write the output to a single assembly file.
    This file is placed in (and has the same name as) the target directory.
    
    If the target path is a file, we compile it and write the output
    to a file with the same name and the extension ".asm".
    """
    if os.path.isdir(target):
        outFile = os.path.join(target,
                               os.path.basename(os.path.dirname(target)) + ".asm")
        codeWriter = CodeWriter(outFile)
        if bootstrap: codeWriter.writeInit()

        for file in os.listdir(target):
            if os.path.splitext(file)[1] == ".vm":
                file = os.path.join(target, file)
                parser = Parser(file)
                codeWriter.setFileName(os.path.basename(file))
                _compile(parser, codeWriter)

        if bootstrap: codeWriter.close()

    else:
        outFile = os.path.splitext(target)[0] + ".asm"
        if outFile == target:
            # We only enforce that the file cannot end in ".asm,"
            # because by opening our output file we would erase the input.
            print("Cannot compile files ending in '.asm'")
            exit(1)

        codeWriter = CodeWriter(outFile)
        if bootstrap: codeWriter.writeInit()  # write bootstrap code needed to load OS
        parser = Parser(target)
        codeWriter.setFileName(os.path.basename(target))
        _compile(parser, codeWriter)
        codeWriter.close()


def main():
    parser = argparse.ArgumentParser(description='Translates VM bytecode to assembly')
    parser.add_argument("files", nargs="+")
    parser.add_argument("-b", help="Add bootstrap code", action="store_true")
    args = parser.parse_args()
    targets = args.files
    if len(targets) == 0:
        parser.print_help()
        exit(1)
    for target in targets:
        compile(target, args.b)
    exit(0)

if __name__ == '__main__':
    main()
