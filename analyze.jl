#!/usr/bin/env julia
# -*- coding: utf-8 -*-

# analyze.jl - sample script to postprocess data produced by crunch.jl
#
# SpQEphysTools - QSpike Tools reinvented - electrophysiology extracellular multichannel batch and parallel preprocessor
#    Copyright (C) 2024 Michele GIUGLIANO <michele.giugliano@unimore.it> and contributors.
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>

using Distributed

#-- FILE HANDLING & START-UP ------------------
if length(ARGS) != 1 #  Check if the user has provided the input file
    @error "USAGE: analyze.jl /path/to/*.dat files"
    println("")
    println("SpQ - Copyright (C) 2024 Michele GIUGLIANO")
    println("This program comes with ABSOLUTELY NO WARRANTY.")
    println("This is free software, and you are welcome to")
    println("redistribute it under certain conditions;")
    println("see the GNU GPLv3 LICENSE file.")
    println("")
    exit(1)
end

if !isdir(ARGS[1]) # Check if the input folder exists
    @error "$(ARGS[1]) not found!"
    exit(1)
else
    pathname = ARGS[1]
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
@everywhere using SpQEphysTools                # Import SpQ in all workers
using SpQEphysTools                            # Import SpQ in the main process
@everywhere include("postprocessing.jl")          # Import postprocess.jl in all workers
include("postprocessing.jl")                      # Import postprocess.jl in the main process

#-- DATA ANALYSIS -----------------------------
@info "Starting postprocessing analysis...";
@info "Processing $(pathname) folder...";

# Let's put in a vector, the name of the (sub)folders ending with *.dat
subfolders = [joinpath(pathname, x) for x in readdir(pathname) if occursin(r".dat", x)];
nExps = length(subfolders);

@info "Number of *.dat found: $(nExps)";
@info "distributed over $(n_workers) workers...";

K = Int(ceil(nExps / n_workers)); # *.dat per worker

# Parallel loop over the workers - each worker will process K files
@sync @distributed for i = 1:n_workers
    start = (i - 1) * K + 1
    stop = min(i * K, nExps)
    for j = start:stop # Loop over the *.dat subfolders
        fname = subfolders[j]
        #fname = joinpath(pathname, readdir(pathname)[j]);
        @info "Processing $(fname) on worker $(i)"
        cp("./config.toml", joinpath(fname, "config.toml"), force=true)
        rm(joinpath(fname, "analysed.txt"), force=true) # Remove the analysed.txt file
        n = active_el(fname, 0.02)
        @info "Number of active electrodes: $(n)"
        m, btimes = extract_bursts(fname, n, 20.0)
        @info "Number of bursts: $(m)"
        if m > 0
            #plot_raster(fname, 1.0, false, btimes) # was 0.15
            plot_raster(fname, 0.2, false) # was 0.15
        else
           plot_raster(fname, 0.2, false) # was 0.15
       end
        plot_frequencies(fname, 0.2, false)

        #SpQEphysTools.analyze(fname);
    end
end
#@time for i = 1:n_workers
#    start = (i-1)*K + 1;
#    stop = min(i*K, nExps);
#    for j = start:stop # Loop over the *.dat subfolders
#        fname = joinpath(pathname, readdir(pathname)[j]);
#        @info "Processing $(fname) on worker $(i)";
#        plot_raster(fname, 0.25, true);
#        #SpQEphysTools.analyze(fname);
#    end
#end
@info "Postprocessing analysis completed.";

#----------------------------------------------
#-- TIDE UP ANALYSIS --------------------------
@info "Tiding up...";

# Create a CSV file with the results
csv = joinpath(pathname, "results.csv");
@info "Creating $(csv)...";
fff = open(csv, "w");

for (index, folder) in enumerate(subfolders)
    analysed = joinpath(folder, "analysed.txt")
    if isfile(analysed)
        #@info "Loading $(analysed)..."
        f = open(analysed, "r")
        lines = readlines(f)
        close(f)

        # Let's create a dictionary with the pairs field-value
        results = Dict()
        for (i, line) in enumerate(lines)
            field, value = split(line, " = ")
            results[field] = value
        end

        if index == 1
            # Let's write all field names as the first row (header)
            write(fff, "Experiment,$(join(keys(results), ","))\n")
        end

        # Let's write the values of the dictionary in the CSV file
        write(fff, "$(basename(folder)),$(join(values(results), ","))\n")

    else # if isfile
        @warn "No analysed.txt found in $(folder)!"
        continue
    end # if
end # for
close(fff);
#----------------------------------------------



