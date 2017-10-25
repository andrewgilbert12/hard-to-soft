#!/usr/bin/env python3
# todo: add static checks for stack over/underflow?

import os
import re
import glob

def _isComment(line):
    return re.match(r'^\s*(//.*)?$',line)

def _isConstant(line):
    return re.match(r'^\s*push constant (\d+)',line)

def _isPushPop(line):
    return re.match(r'^\s*(push|pop)\s+(local|argument|this|that|temp|pointer|static)\s+(\d+)\s*(//.*)?$',line)

def _isArith(line):
    return re.match(r'(add|and|neg|not|or|sub)',line)

def _isComp(line):
    return re.match(r'(eq|gt|lt)',line)

def _die_with_err_msg(in_line_ct, msg):
    raise RuntimeError("Line %d:\n\t%s" % (in_line_ct, msg))

class _builtins():
    def __init__(self, comments=False):
        self.builtins = {}
        for asm in glob.glob('Assemblies/*.asm'):
            name = os.path.splitext(os.path.basename(asm))[0]
            with open(asm, 'r') as f:
                cont = []
                for line in f:
                  if comments is True or \
                      not _isComment(line):
                    cont.append(line)
            self.builtins[name] = "".join(cont)
        self.define_mem_dict();

    def define_mem_dict(self):
        self.mem_dict = {
            "local" : "LCL",
            "argument" : "ARG",
            "this" : "THIS",
            "that" : "THAT",
            "pointer" : "THIS",
            "temp" : "5",
            "static" : "16"
        }

    def apply(self, linect, name, *args):
        varct = 0
        try:
            code = self.builtins[name]
        except:
            _die_with_err_msg(linect, "%s unimplemented!" % name)
        for var in args:
            varct += 1
            code = re.sub('__VAR' + str(varct) + '__', str(var), code)
        if re.search(r'__VAR(\d+)__', code):
            _die_with_err_msg(linect, "the %s builtin requires additional variables!" % name)
        return code

def _compile(f, builtins, bootstrap=False):
    out = []
    linect, compct = 0, 0
    if bootstrap: out.append(builtins.apply(linect,"bootstrap"))
    for line in f:
        linect += 1
        if _isComment(line):
            continue
        elif _isConstant(line):
            val = _isConstant(line).group(1)
            out.append(builtins.apply(linect, "pushConst", val))
        elif _isArith(line):
            name = _isArith(line).group(1)
            out.append(builtins.apply(linect, name))
        elif _isPushPop(line):
            op = _isPushPop(line).group(1)
            reg = _isPushPop(line).group(2)
            mem = builtins.mem_dict[reg]
            val = _isPushPop(line).group(3)
            if reg in ["temp","pointer","static"]: addr = "A"
            else: addr = "M" # all others
            out.append(builtins.apply(linect, op, mem, val, addr))
        elif _isComp(line):
            name = _isComp(line).group(1)
            out.append(builtins.apply(linect, name, compct))
            compct += 1
        else:
            _die_with_err_msg(linect, "illegal statement:\n\t%s" % line)
    out.append(builtins.apply(linect,"end"))
    return "\n".join(out)

def compile(file, outfile=None, loghook=None):
    if loghook:
        from time import time
        start = time()
    if outfile is None:
        import os
        outfile = os.path.splitext(file)[0] + ".asm"
    with open(file, 'r') as f:
        try:
            if loghook: loghook("opened %s" % file)
            builtins = _builtins()
            out = _compile(f, builtins)
            if loghook: loghook("compile complete")
        except RuntimeError as err:
            if loghook: loghook(err.args[0])
            exit(-1)
        if loghook: loghook("finished compiling, writing to %s" % outfile)
    with open(outfile, 'w') as f:
        f.write(out)
    if loghook: total_time = (time() - start) / 1000
    if loghook: loghook("done with %s in %0.6fs\n" % (file, total_time))

if __name__ == '__main__':
    from sys import argv, stderr
    from os.path import basename, splitext
    if len(argv) < 2 or re.match(r'-h', argv[1]):
        print("Usage: %s [file...]" %
              splitext(basename(argv[0]))[0],
              file=stderr)
    else:
        for file in argv[1:]:
            compile(file, loghook=lambda str: print(str, file=stderr))
    exit(0)
