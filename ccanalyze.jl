#!/usr/bin/env julia
# -*- coding: utf-8 -*-

# ccanalyze.jl - sample script to postprocess data produced by....
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

using Distributed, JLD2, Clustering

#-- FILE HANDLING & START-UP ------------------
if length(ARGS) != 1 #  Check if the user has provided the input file
    @error "USAGE: ccanalyze.jl /path/to/*.dat files"
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
@everywhere include("cc_analysis.jl")          # Import postprocess.jl in all workers
include("cc_analysis.jl")                      # Import postprocess.jl in the main process
@everywhere using Plots, JLD2, Clustering

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

        # Let's create a file in the fname folder, named: peaks.txt
        fp = open(joinpath(fname, "peaks.txt"), "w");

        for chanA in 1:60, chanB in 1:60
            if chanB > chanA
                MAX, AMAX, edges, cc = cross_correlogram(fname, chanA, chanB, 500., 3.);
                if isnan(MAX)
                    continue
                else
                    UP, DOWN = significance_levels(fname, chanA, chanB, 500., 3., 3, 3.);
                    indx = argmax(cc);                      # Index of the maximum peak
                    if is_significant(indx, cc, UP, DOWN)
                        @info "Significant CCG found for $(fname) - $(chanA) - $(chanB), peak = $(MAX)"
                        println(fp, "$(chanA) $(chanB) $(MAX) $(AMAX) $(edges[indx])")
                    end
                end
            end
        end
        close(fp);
end
@info "ccanalysis_NEW completed.";
end

