#!/bin/env bash

#SOFTWARE_DIR=$HOME/sw
SOFTWARE_DIR=./swTestInstall

# Check whether julia is already installed
if command -v julia &> /dev/null
then
    echo "Julia found! Version: $(julia --version)"
    mkdir -p $SOFTWARE_DIR/julia/bin
    JULIA_PATH=$(command -v julia)
    ln -s $JULIA_PATH $SOFTWARE_DIR/julia/bin/julia
else
    echo "Julia not found! Installing it!"
   # Long-term support release: v1.10.6 (Oct 28, 2024)
    #if [[ "$OSTYPE" == "linux-gnu" ]]; then
    #    JULIA_LTS="https://julialang-s3.julialang.org/bin/linux/x64/1.10/julia-1.10.6-linux-x86_64.tar.gz"
    #else
    #    echo "ERROR: installer meant for Linux only!"
    #fi
    JULIA_LTS="https://julialang-s3.julialang.org/bin/linux/x64/1.10/julia-1.10.6-linux-x86_64.tar.gz"

    # Check whether wget and git are installed ------------------
    if ! command -v wget &> /dev/null
    then
        echo "ERROR: wget not found! Install it please."
        exit
    fi

   # Install julia
    mkdir -p $SOFTWARE_DIR/julia
    wget -q -O - $JULIA_LTS | tar -xzf - -C $SOFTWARE_DIR/julia --strip-components=1
fi
#------------------------------------------------------------

# Get SpiQ from github

if ! command -v git &> /dev/null
then
    echo "ERROR: git not found! Install it please."
    exit
fi

echo "Cloning SpiQ from github..."
git clone https://github.com/mgiugliano/SpiQ $SOFTWARE_DIR/SpiQ

echo "Installation completed!"


