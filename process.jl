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
sleep(5)
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
@everywhere using HDF5, DSP, Statistics, JLD2, DelimitedFiles # Pkgs on ALL workers
#----------------------------------------------


#-- TOML --------------------------------------
include("./pvt/read_config_toml.jl")    # Read config.toml
include("./pvt/read_data_info_toml.jl") # Read TOML data file
@info "TOML info and config files acquired!";
#----------------------------------------------


#-- FILTER, DETECT SPIKE, EXTRACT SHAPES -------------------------------
@everywhere function preproc_chan(fname, chan, srate, c, d, fmin_d, fmax_d, stdmin, stdmax, dpre, dpost, ref, event, OUTPUT)
    file = h5open(fname, "r");                                        # Open .h5 file (on each worker)
    data = file["Data/Recording_0/AnalogStream/Stream_0/ChannelData"];# Get the dataset
    @info "Chan $(chan) - $(size(data)) samples read.";

    filt_d = digitalfilter(Bandpass(fmin_d * 2. / srate, fmax_d * 2. / srate), Elliptic(2, 0.1, 40))
    #filt_s = digitalfilter(Bandpass(fmin_s * 2. / srate, fmax_s*2./srate), Elliptic(2, 0.1, 40))
    xf_d = filtfilt(filt_d, c .* data[:, chan] .+ d);
    @info "Chan $(chan) - filtered!";
    #xf_s = filtfilt(filt_s, c .* data[:, chan] .+ d);

    #-- Detect spikes
    noise_std_d = median(abs.(xf_d) / 0.6745);
    #noise_std_s = median(abs.(xf_s) / 0.6745);
    thr    = stdmin * noise_std_d;
    thrmax = stdmax * noise_std_d;

    @info "Chan $(chan) - detecting spikes...";
    wpre  = Int64(ceil(1e-3 * dpre  * srate));   # Pre-spike window, in samples
    wpost = Int64(ceil(1e-3 * dpost * srate));   # Post-spike window, in samples
    rref  = Int64(ceil(1e-3 * ref  * srate));    # Refractory/dead period, in samples
    href  = Int64(ceil(1e-3 * 0.5 * ref  * srate)); # Half refractory/dead period, in samples
    idx   = zeros(Int64,0);                         # Indexes of detected events

    if event == 1       # "positive" threshold crossings
        y = findall(xf_d[wpre+2:end-wpost-2] .> thr)       .+ (wpre+1) # indexes of elements > threshold
    elseif event == -1  # "negative" threshold crossings
        y = findall(xf_d[wpre+2:end-wpost-2] .< -thr)      .+ (wpre+1) # indexes of elements < threshold
    else                # "both" threshold crossings
        y = findall(abs.(xf_d[wpre+2:end-wpost-2]) .> thr) .+ (wpre+1) # indexes of elements > threshold
    end

	    last = 0;   # index of the last event detected so far
        for i in 1:length(y)            # loop over all threshold crossings (indexes)
	        if y[i] >= last + rref      # current event after last refractory/dead period
                A = xf_d[y[i]:y[i]+href-1] # extract a number of samples equal to half refractory/dead period (voltages)
                A = abs.(A)                # take the absolute value of the voltages (so that I can always use "maximul" below)
                iaux = findall(A .== maximum(A)) # introduces alignment by taking the index of the maximum value (indexes)
	            append!(idx, iaux .+ (y[i] -1));  # append the index of the maximum value to the list of indexes
                last = idx[end];           # update the index of the last event detected so far
	        end
	    end

    # Save the detected spikes times (in s) on disk, as a text file
    outname = joinpath(OUTPUT, "spk_t_c$(chan).txt");
    writedlm(outname, idx ./ srate);
#    open(outname, "w") do f
#        for i in 1:length(idx)
#            println(f, idx[i] / srate);   # s
#        end
#    end

    # Save as a *.jld2 file the shape of each detected spike
    # (i.e., the voltage values in the pre-spike and post-spike windows)
    outname = joinpath(OUTPUT, "spk_shapes_c$(chan).jld2");
    open(outname, "w") do f
        for i in 1:length(idx)
            if idx[i] - wpre > 0 && idx[i] + wpost < length(xf_d)
                spike = xf_d[idx[i] - wpre:idx[i] + wpost];
                write(f, "spike_$(i)", spike);
            end
        end
    end

    @info "Chan $(chan) - $(length(idx)) spikes detected.";

    # Close the file within each worker
    close(file)
end


#----------------------------------------------

M = Int(ceil(Nchans / n_workers))
@info "Distributing $(Nchans) chans across $(n_workers) workers."
@info "i.e. $(M) chans per worker."

#Nchans = n_workers # Just to test
@time @sync @distributed for i in 1:n_workers
        start_chan = (i - 1) * Int(ceil(Nchans / n_workers)) + 1
        end_chan = min(i * Int(ceil(Nchans / n_workers)), Nchans)

        for chan in start_chan:end_chan
            preproc_chan(filename, chan, srate, c, d, fmin_d, fmax_d, stdmin, stdmax, dpre, dpost, ref, event, OUTPUT);
        end
end




