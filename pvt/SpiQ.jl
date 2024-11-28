#!/usr/bin/env julia
# -*- coding: utf-8 -*-

# The script is part of the QSpiQ project.
#
# Nov 2024, M. Giugliano (mgiugliano@gmail.com)
# github.com/mgiugliano


module SpiQ

using HDF5, DSP, Statistics, JLD2, DelimitedFiles # Pkgs on ALL workers


function bandpass(data::Array{Float64,1}, lowcut::Float64, highcut::Float64, fs::Float64)
    nyquist = 0.5 * fs;
    low = lowcut / nyquist;
    high = highcut / nyquist;
    TYPE = Bandpass(low, high);
    DESIGN = Elliptic(2, 0.1, 40);
    filt = digitalfilter(TYPE, DESIGN);
    return filtfilt(filt, data);
end # bandpass -----------------------------------



function lowpass_and_dec(data::Array{Float64,1}, cutoff::Float64, rate::Float64, fs::Float64)
    nyquist = 0.5 * fs;
    low = cutoff / nyquist;
    TYPE   = Lowpass(low);
    DESIGN = Butterworth(5);
    filt   = digitalfilter(TYPE, DESIGN);
    xf = filtfilt(filt, data);
    decimate = Int(ceil(fs / rate));
    return xf[1:decimate:end];
end # lowpass_and_dec ----------------------------



function extract_peaks(xf::Array{Float64,1}, thr::Float64, dpre::Float64, dpost::Float64, ref::Float64, event::Int64, srate::Float64)
        #idx   = zeros(Int64,0);                    # Indx of events
        idx = Vector{Vector{Float64}}()             # Indx of events and polarity

        wpre  = Int64(ceil(1e-3 * dpre  * srate));   # Pre window, in samples
        wpost = Int64(ceil(1e-3 * dpost * srate));   # Post window, in samples
        rref  = Int64(ceil(1e-3 * ref  * srate));    # Refr/dead period, in samples
        href  = Int64(ceil(1e-3 * 0.5 * ref  * srate)); # Half refr/dead period, in samples

        if event == 1       # "positive" threshold crossings
            y = findall(xf[wpre+2:end-wpost-2] .> thr) .+ (wpre+1) # indx of elms > thr
        elseif event == -1  # "negative" threshold crossings
            y = findall(xf[wpre+2:end-wpost-2] .< -thr) .+ (wpre+1) # indx of elms < thr
        else                # "both" threshold crossings
            y = findall(abs.(xf[wpre+2:end-wpost-2]) .> thr) .+ (wpre+1) # indx of elms > thr
        end

	    last = 0;                          # indx last event detected so far
        for i in 1:length(y)               # over all threshold crossings (indexes)
	        if y[i] >= last + rref         # current event, after last refractory/dead period
                A = xf[y[i]:y[i]+href-1]   # extract n samples = to half refr/dead period (volt)
                A = abs.(A)                # take their abs (so I can always use "maximum" below)
                iaux = findall(A .== maximum(A)) # introduces alignment: takes indx of max (indx)
                index = y[i] + iaux[1] - 1  # indx of max value in original signal (xf)
                polar = sign(xf[index])     # polarity of max value (xf)
                #append!(idx, iaux .+ (y[i] -1)); # append indx of max to events list (indx)
                push!(idx, [index, polar])  # append indx of max to events list (indx)
                last = index;               # update indx of last event detected so far
	        end
	    end

        #return idx
        return reduce(vcat, idx')
    end # extract_peaks ----------------------------



function preproc_chan(fname, chan, s)
        #srate, c, d, fmin_d, fmax_d, fmin_s, fmax_s, fmax, rate, stdmin, stdmax, dpre, dpost, ref, event, OUTPUT)
    file = h5open(fname, "r");                                        # Open .h5 file (on each worker)
    data = file["Data/Recording_0/AnalogStream/Stream_0/ChannelData"];# Get the dataset
    @info "Chan $(chan) - $(size(data)) samples read.";

    c = s.c;
    d = s.d;
    tmp = 2. / s.srate;
    # LFP extraction -------------------------------------
    if s.LFP
        xf = lowpass_and_dec(c .* data[:, chan] .+ d, s.fmax, s.rate, s.srate);
        outname = joinpath(s.OUTPUT, "lfp_$(chan).jld2");
        open(outname, "w") do f
            write(f, "lfp", xf);
        end
        @info "LFP: Chan $(chan) done!";
    end # LFP --------------------------------------------

    # Spike detection ------------------------------------
    if s.detect
        xf = bandpass(c .* data[:, chan] .+ d, s.fmin_d, s.fmax_d, s.srate);
        #@info "Chan $(chan) - filtering done.";

        noise_std = median(abs.(xf) / 0.6745);
        thr    = s.stdmin * noise_std;
        thrmax = s.stdmax * noise_std;

        #@info "Chan $(chan) - detecting spikes...";
        idx = extract_peaks(xf, thr, s.dpre, s.dpost, s.ref, s.event, s.srate);
        tspk = idx;
        tspk[:,1] = tspk[:,1] / s.srate;

        outname = joinpath(s.OUTPUT, "spk_$(chan).txt");
        writedlm(outname, tspk);
        @info "MUA: Chan $(chan) done! $(length(idx)) events detected.";
    end # Spike detection --------------------------------


    if s.shapes
        if s.fmin_s != s.fmin_d || s.fmax_s != s.fmax_d
            #@warn "Different filters for spike detection and shapes!";
            xf = bandpass(c .* data[:, chan] .+ d, s.fmin_s, s.fmax_s, s.srate);
            #@info "Chan $(chan) - filtering done.";

            #noise_std = median(abs.(xf) / 0.6745);
            #thr    = stdmin * noise_std;
            #thrmax = stdmax * noise_std;
        end

        wpre  = Int64(ceil(1e-3 * s.dpre  * s.srate));   # Pre window, in samples
        wpost = Int64(ceil(1e-3 * s.dpost * s.srate));   # Post window, in samples

        outname = joinpath(s.OUTPUT, "spk_shapes_c$(chan).jld2");
        open(outname, "w") do f
            for i in 1:length(idx[:,1])
            if idx[i,1] - wpre > 0 && idx[i] + wpost < length(xf)
                wave = xf[idx[i,1] - wpre:idx[i,1] + wpost];
                write(f, "wav_$(i)", wave);
            end # if
            end # for
        end # open
        @info "WAVES: Chan $(chan) done!";
    end # Shapes ----------------------------------------

    # Close the file within each worker
    close(file)
end # preproc_chan
#----------------------------------------------

export preproc_chan # Make it available outside the module

end  # End of module definition

