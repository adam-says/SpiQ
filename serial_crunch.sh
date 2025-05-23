#!/usr/bin/env bash

# serial_crunch.sh - Sistematically run crunch.jl on all files in a directory.
#
# Usage: serial_crunch.sh <directory>
#
# Apr 2025, A. Armada-Moreira
# github.com/adam-says
VER="0.1"
NAME="serail_crunch.sh (for SpiQ)" # Name of the script
# If no directory is provided as input, exit
if [ -z "$1" ]; then
    echo "USAGE: $NAME <directory>"
    exit
fi
[ -z "$1" ]
for file in /dir/*
do
  julia crunch.jl "$file" >> results.out
done
