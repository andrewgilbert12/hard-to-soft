#!/usr/bin/env bash
# takes one file path as input
# for directories, compile all jack files in the directory
# for jack files, compile that file only
if [ -d $1 ]; then
    for file in `ls "$1" | grep ".jack"`; do
        echo "Compiling $1$file"
        ./compiler <"$1/$file" >"$1/${file%.jack}.vm"
    done
elif [ -f $1 ]; then
    echo "Compiling $1"
    ./compiler <"$1" >"${1%.jack}.vm"
fi
