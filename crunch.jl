#!/usr/bin/env julia
# -*- coding: utf-8 -*-

# crunch.jl - sample script to preprocess electrophysiological data
#
# SpQ - QSpike Tools reinvented - electrophysiology extracellular multichannel batch and parallel preprocessor
#    Copyright (C) 2024 Michele GIUGLIANO <michele.giugliano@unimore.it> and contributors.
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>

using Distributed
#using ProfileView      # Uncomment to profile the code
#using Cthulhu          # Uncomment to profile the code

#-- FILE HANDLING & START-UP ------------------
if length(ARGS) != 1 #  Check if the user has provided the input file
    @error "USAGE: crunch.jl /path/to/DATA_file.h5/.brw";
    println("");
    println("SpQ - Copyright (C) 2024 Michele GIUGLIANO");
    println("This program comes with ABSOLUTELY NO WARRANTY.")
    println("This is free software, and you are welcome to")
    println("redistribute it under certain conditions;")
    println("see the GNU GPLv3 LICENSE file.");
    println("");
    exit(1)
end

if !isfile(ARGS[1]) # Check if the input file exists
    @error "$(ARGS[1]) not found!";
    exit(1);
else
    filename = ARGS[1];
    path = dirname(filename); # Path to the file
end
#----------------------------------------------


#-- CORES AND WORKERS -------------------------
nCores = Sys.CPU_THREADS; # CPU threads available
@info "$(nCores) CPU threads available.";
addprocs(nCores);         # Add workers
w = workers();            # Get the list of workers
n_workers = length(w);    # Number of workers available
@info "Number of workers: $(n_workers)";
#----------------------------------------------

# Now that we have the workers, we can import SpQ...
@everywhere using SpQ                # Import SpQ in all workers
using SpQ                            # Import SpQ in the main process

#-- OUTPUT FOLDER -----------------------------
ext = splitext(filename)[2]               # e.g. ".h5" or ".brw" - extension
OUTPUT = replace(filename, ext => ".dat") # Output folder
if isdir(OUTPUT)                          # OUTPUT folder already exists
    rm(OUTPUT, recursive=true);
end
mkpath(OUTPUT);

#-- METADATA ----------------------------------
if ext == ".h5" # .h5 (MCS)
    run(`bash ./src/get_info_mcs.sh $filename`)
else # .brw (3BRAIN)
    run(`bash ./src/get_info_brw.sh $filename`)
end
metafile = replace(filename, ext => ".toml")
base = basename(metafile)
mv(base, OUTPUT * "/meta.toml")
cp("config.toml", OUTPUT * "/config.toml", force=true)
#----------------------------------------------


#-- TOML --------------------------------------
tmp = SpQ.parse_toml_files(OUTPUT);  # Parse config.toml and meta.toml
@everywhere SpQ.s = $tmp;         # Send s to all workers
@info "TOMLs acquired and broadcasted!";

if ext == ".h5" # Set the dataset name according to the file extension (MCS vs 3BRAINS)
    datasetname = "Data/Recording_0/AnalogStream/Stream_0/ChannelData";
else
    datasetname = "Data"; # check this
end
#----------------------------------------------

#MEM = SpQ.meminfo_julia();
@info "Preprocessing started..."
#@info "$(MEM) GB in use"
#-- MAIN LOOP ----------------------------------
Nchans = SpQ.s.Nchans;                      # Number of channels
#Nchans = 1 # Just to test

@info "$(Nchans) chans distributed over $(n_workers) workers."
K = Int(ceil(Nchans / n_workers));          # Channels per worker

# Parallel loop over the workers - each worker processes K channels
@sync @distributed for i in 1:n_workers
        start_chan = (i - 1) * K + 1;
        end_chan = min((i * K), Nchans);
        for chan in start_chan:end_chan     # Loop over the channels assigned to that worker
            SpQ.preproc_chan(filename, chan, datasetname);
            GC.gc(); # Force garbage collection
            #MEM = SpQ.meminfo_julia()
            #@info "$(MEM) GB in use"
        end
    end

# DEBUGGING ONLY - uncomment to test the loop in the main process without parallelization
#@ProfileView.@profview @time for i in 1:n_workers
#        start_chan = (i - 1) * K + 1;
#        end_chan = min((i * K), Nchans);
#        for chan in start_chan:end_chan     # Loop over the channels assigned to that worker
#            SpQ.preproc_chan(filename, chan, datasetname);
#        end
#    end

@info "Tide-up output..."
SpQ.tideup_output(OUTPUT); # Merge, organise, and tide up all output files

#SpQ.meminfo_julia();

@info "Preprocessing completed."
