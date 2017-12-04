#!/usr/bin/env python3
import re

_dest_table = {
    None  : "000",
    "M"   : "001",
    "D"   : "010",
    "MD"  : "011",
    "A"   : "100",
    "AM"  : "101",
    "AD"  : "110",
    "AMD" : "111"
}

_comp_table = {
    "0"   : "0101010",
    "1"   : "0111111",
    "-1"  : "0111010",
    "D"   : "0001100",
    "A"   : "0110000",
    "!D"  : "0001101",
    "!A"  : "0110001",
    "-D"  : "0001111",
    "-A"  : "0110011",
    "D+1" : "0011111",
    "A+1" : "0110111",
    "D-1" : "0001110",
    "A-1" : "0110010",
    "D+A" : "0000010",
    "D-A" : "0010011",
    "A-D" : "0000111",
    "D&A" : "0000000",
    "D|A" : "0010101",
    "M"   : "1110000",
    "!M"  : "1110001",
    "-M"  : "1110011",
    "M+1" : "1110111",
    "M-1" : "1110010",
    "D+M" : "1000010",
    "D-M" : "1010011",
    "M-D" : "1000111",
    "D&M" : "1000000",
    "D|M" : "1010101"}

_jump_table = {
    None : "000",
    "JGT": "001",
    "JEQ": "010",
    "JGE": "011",
    "JLT": "100",
    "JNE": "101",
    "JLE": "110",
    "JMP": "111"}

def _default_symbols():
    return {
        "R0"     : 0,
        "R1"     : 1,
        "R2"     : 2,
        "R3"     : 3,
        "R4"     : 4,
        "R5"     : 5,
        "R6"     : 6,
        "R7"     : 7,
        "R8"     : 8,
        "R9"     : 9,
        "R10"    : 10,
        "R11"    : 11,
        "R12"    : 12,
        "R13"    : 13,
        "R14"    : 14,
        "R15"    : 15,
        "SCREEN" : 16384,
        "KBD"    : 24576,
        "SP"     : 0,
        "LCL"    : 1,
        "ARG"    : 2,
        "THIS"   : 3,
        "THAT"   : 4}

def _die_with_err_msg(in_line_ct, msg):
    raise RuntimeError("Line %d:\n\t%s" % (in_line_ct, msg))

def _isBlankLine(line):
    return re.match(r'^\s*(?://.*)?$',
                    line)

def _isLabel(line):
    return re.match(r'^\s*\(([\w$._:][\w$._:\d]*)\)\s*(?://.*)?$',
                    line)

def _isA(line):
    return re.match(r'^\s*@([^\s]+)\s*(?://.*)?$',
                    line)

def _processA(aExp, sym, newsymaddr):
    val = aExp.group(1)
    if val.isnumeric():
        out = val
    else:
        if val not in sym:
            sym[val] = newsymaddr
            newsymaddr += 1
        out = sym[val]
    return bin(int(out))[2:].zfill(16), newsymaddr  # decimal to binary

def _isC(line):
    return re.match(r'^(?:\s*(A?M?D?)\s*=)?\s*' +
                    r'(0|1|-1|[!-]?[ADM]|(?:A|D|M)[\+\-&|](?:A|D|M|1))' +
                    r'\s*(?:;\s*(JLT|JEQ|JGT|JLE|JGE|JNE|JMP))?' +
                    r'\s*(?://.*)?$',
                    line)

def _processC(cExp):
    dest, comp, jump = cExp.group(1), cExp.group(2), cExp.group(3)
    return "111" + \
           _dest_table[dest] + \
           _comp_table[comp] + \
           _jump_table[jump]

def _build_sym_table(f, sym):
    in_line_ct = 0
    out_line_ct = 0
    for line in f:
        in_line_ct += 1
        if not _isBlankLine(line):
            out_line_ct += 1
        m = _isLabel(line)
        if m:
            label = m.group(1)
            if label in sym:
                _die_with_err_msg(in_line_ct,
                                  "label %s already defined!" %
                                  line)
            sym[label] = out_line_ct + 1
    f.seek(0)

def _assemble(f, sym):
    out = []
    linect = 0
    newsymaddr = 16 # past R15, per specification
    for line in f:
        linect += 1
        if _isBlankLine(line) or _isLabel(line):
            continue # labels already processed in _build_sym_table
        elif _isA(line):
            aExp = _isA(line)
            try:
                nextout, newsymaddr = _processA(aExp, sym, newsymaddr)
                out.append(nextout)
            except:
                _die_with_err_msg(linect,
                                  "invalid A expression!\n\t%s" %
                                  line)
        else:
            cExp = _isC(line)
            try:
                out.append(_processC(cExp))
            except:
                _die_with_err_msg(linect,
                                  "invalid C expression!\n\t%s" %
                                  line)
    return "\n".join(out)

def assemble(file, outfile=None, loghook=None):
    if loghook:
        from time import time
        start = time()
    if outfile is None:
        import os
        outfile = os.path.splitext(file)[0] + ".hack"
    with open(file, 'r') as f:
        try:
            if loghook: loghook("opened %s" % file)
            sym = _default_symbols()
            if loghook: loghook("loaded default symbols")
            _build_sym_table(f, sym)
            if loghook: loghook("built symbol table, now assembling")
            out = _assemble(f, sym) # currently
        except RuntimeError as err:
            if loghook: loghook(err.args[0])
            exit(-1)
        if loghook: loghook("finished building, writing to %s" % outfile)
    with open(outfile, 'w') as f:
        f.write(out)
    if loghook: total_time = (time() - start) / 1000
    if loghook: loghook("done with %s in %0.6fs" % (file, total_time))

if __name__ == '__main__':
    from sys import argv, stderr
    from os.path import basename, splitext
    if len(argv) < 2 or re.match(r'-h', argv[1]):
        print("Usage: %s [file...]" %
              splitext(basename(argv[0]))[0],
              file=stderr)
    else:
        for file in argv[1:]:
            assemble(file, loghook=lambda str: print(str, file=stderr))
    exit(0)
