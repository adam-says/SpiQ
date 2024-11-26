#!/usr/bin/env julia
# -*- coding: utf-8 -*-

# The script is part of the QSpiQ project.
#
# Nov 2024, M. Giugliano (mgiugliano@gmail.com)
# github.com/mgiugliano

using HDF5, Distributed, TOML, DSP, Statistics, JLD2, DelimitedFiles


#-- FILE HANDLING & START-UP ------------------
if length(ARGS) != 1 # Check input arguments.
    @warn "Usage: process.jl /path/to/MCS_h5file.h5";
    exit(1);
end

if !isfile(ARGS[1]) # Check if the file exists
    @error "$(ARGS[1]) not found!";
    exit(1);
else
    filename = ARGS[1];
    path = dirname(filename); # Path to the file
end

#-- OUTPUT FOLDER -----------------------------
OUTPUT = replace(filename, ".h5" => ".dat")
if isdir(OUTPUT)     # OUTPUT folder already exists
    rm(OUTPUT, recursive=true);
end
# Sleep for 20 seconds to allow the deletion of the folder
mkdir(OUTPUT);
#-- METADATA ----------------------------------
run(`bash ./pvt/get_info.sh $filename`)
metafile = replace(filename, ".h5" => ".toml")
base = basename(metafile)
run(`mv ./$base $OUTPUT/meta.toml`)
run(`cp ./config.toml $OUTPUT/config.toml`)
#----------------------------------------------

@info "Preprocessing started..."

#-- CORES AND WORKERS -------------------------
nCores = Sys.CPU_THREADS; # CPU threads available
@info "$(nCores) CPU threads available.";
addprocs(nCores);         # Add workers
#addprocs(0);
w = workers();            # Get the list of workers
n_workers = length(w);    # Number of workers available
@info "Number of workers: $(nworkers())";
#@everywhere using HDF5, DSP, Statistics, JLD2, DelimitedFiles # Pkgs on ALL workers
#----------------------------------------------


#-- TOML --------------------------------------
include("./pvt/read_toml.jl")    # Read config.toml and meta.toml
@info "TOML info and config files acquired!";
#----------------------------------------------

#-- FUNCTION DEFINITIONS -----------------------
@everywhere include("./pvt/SpiQ.jl");
#----------------------------------------------


#-- MAIN LOOP ----------------------------------
M = Int(ceil(Nchans / n_workers))

@info "$(Nchans) chans for $(n_workers) workers."

Nchans = n_workers # Just to test
@time @sync @distributed for i in 1:n_workers
        start_chan = (i - 1) * Int(ceil(Nchans / n_workers)) + 1
        end_chan = min(i * Int(ceil(Nchans / n_workers)), Nchans)

        for chan in start_chan:end_chan
            SpiQ.preproc_chan(filename, chan, s)
            #preproc_chan(filename, chan, srate, c, d, fmin_d, fmax_d, fmin_s, fmax_s, fmax, rate, stdmin, stdmax, dpre, dpost, ref, event, OUTPUT)
        end
    end


