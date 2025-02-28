using DelimitedFiles, StatsBase, Plots, TOML, Statistics

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

"""
    report(text::String, filename::String)

This function writes a string to a file. If the file does not exist, it is created.
If the file already exists, the string is appended to it.

### Arguments
- text (String): the string to be written to the file.
- filename (String): the name of the file to write to.

### Author(s)
- Michele Giugliano - michele.giugliano@unimore.it
"""

function report(text::String, filename::String)
    f = open(filename, "a")    # Open the file in append mode (if it does not exist, it is created)
    write(f, text)             # Write the string to the file
    write(f, "\n")
    close(f)                   # Close the file
end # report



"""
	active_el()

This function calculates the number of "active electrodes" given the preprocessed recorded (spike timing) data.
Following the work of Prof. Dr. Shimon Marom (Technion, Haifa), an "active electrode" is conventionally defined as an electrode that records at least one spike every 50 seconds (i.e., active with a frequency >0.02 Hz).

### Arguments
- fname of preprocessed data file, containing the spike times (i.e. *.dat/spk.txt) (String)
- threshold (in Hz) to define an active electrode (Float64)

### Author(s)
- Michele Giugliano - michele.giugliano@unimore.it
"""

function active_el(pathname::String, threshold::Float64)::Int
    filename = joinpath(pathname, "spk.txt") # Spike times file (spk.txt)

    if !isfile(filename)
        @error "Active El: spk.txt file not found."
        return -1
    end

    spk = readdlm(filename)     # Load the spike times

    if size(spk, 1) == 0          # If the file is empty,
        return 0                 # return 0 active electrodes.
    end

    t = spk[:, 1]                          # Extract the spike times
    e = Int.(abs.(spk[:, 2]))              # Extract the electrode numbers
    spk = nothing                          # Clear the spike times from memory

    Nrows = size(t, 1)             # Total number of events, across all electrodes.
    Nel = maximum(e)             # Num electrodes, inferred from the data
    T = maximum(t)             # Duration of the recording, inferred from the data.

    Nmin = Int(round(threshold * T))      # Minimum number of spikes to define an active electrode

    event_frequencies = zeros(Int, Nel)    # Initialize the array to store the number of spikes per electrode.
    # Nel might be lower than the actual number of electrodes, but that's fine.
    # The array will be zero-padded. So if an electrode does not appear in the data
    # (i.e., it is not active), its corresponding entry will remain zero.

    for i in 1:Nrows                        # Loop over all the spike times...
        event_frequencies[e[i]] += 1        # ... and count the number of spikes per electrode.
    end

    active = findall(x -> x > Nmin, event_frequencies)   # Find the electrodes with more than Nmin spikes.
    top = maximum(event_frequencies)                   # Find the electrode with the highest number of spikes.
    top_el = argmax(event_frequencies)                 # Find the electrode with the highest number of spikes.

    outname = joinpath(dirname(filename), "analysed.txt")      # Define the output file name
    report("N_spikes = $(Nrows)", outname)                     # Write the total number of spikes to a file.
    report("N_Active_electrodes = $(length(active))", outname) # Write the number of active electrodes to a file.
    report("Top_Active_electrode = $(top_el)", outname)        # Write the electrode with the highest number of spikes to a file.
    report("Highest_Rate = $(top/T)", outname)                 # Write the highest spike rate to a file.

    @info "Post: active el. analysed!"

    return length(active)              # Return the number of active electrodes.
end # active_el


"""
extract_bursts(pathname::String, nActiveEl::Int)::Int

Detect the bursts as in Van Pelt et al., 2004; IEEE Trans. Biomed. Eng., 51(11):2051-62.
Alternatively, it uses a fixed threshold to detect the bursts, ignoring combined effect of an increase in the firing rate and an increase in the number of channels simultaneously active.

### Arguments
- `pathname::String` : path to the folder containing the spike times and the configuration files (the pre-processed *.dat folder)
- `nActiveEl::Int` : number of active electrodes

### Author(s)
- Michele Giugliano - michele.giugliano@unimore.it
"""
function extract_bursts(pathname::String, nActiveEl::Int, ref::Float64)

    # Let's get some pars from the config and meta files.
    config = joinpath(pathname, "config.toml")
    meta = joinpath(pathname, "meta.toml")

    if !isfile(config) || !isfile(meta)
        @error "config.toml or meta.toml not found."
        exit(1)
    end

    configfile = TOML.parsefile(config)
    metafile = TOML.parsefile(meta)

    Nchans = metafile["info"]["Nchans"]
    Nsamples = metafile["info"]["Nsamples"]
    srate = 1E6 / metafile["chans"]["Tick"] # Hz
    T = Nsamples / srate # s - total recording time

    bin = configfile["bursting"]["burst_bin"] / 1000.0 # s - e.g. 25 ms / 1000 = 0.025
    pelt = configfile["bursting"]["pelt_factor"]      # e.g. 0.05 (start & stop of a burst defined as 5% of its peak amplitude)
    th_sn = configfile["bursting"]["sn_ratio_threshold"]
    th_mode = configfile["bursting"]["burst_th_mode"]
    threshold = configfile["bursting"]["burst_threshold"]
    min_threshold = configfile["bursting"]["minimal_threshold"]
    # ---------------------------------------------

    rref = Int64(ceil(1e-3 * ref * srate))    # Refr/dead period, in samples
    href = Int64(ceil(1e-3 * 0.5 * ref * srate)) # Half refr/dead period, in samples

    # The n of active electrodes must be at least 1/6th of the total
    if nActiveEl <= (Nchans / 6)
        @warn "Burst Analysis: not enough active electrodes."
        return 0, Float64[]
    end # if

    # Start analyzing the spike times, to detect synchronous bursting epochs.
    filename = joinpath(pathname, "spk.txt")

    if !isfile(filename)
        @error "Burst analysis: spk.txt file not found."
        return 0, Float64[]
    end

    spk = readdlm(filename)     # Load ALL spike times (i.e. spk.txt file) in s

    if size(spk, 1) == 0          # If the file is empty,
        @warn "Burst Analysis: no spikes found!"
        return 0, Float64[]
    end # if

    # Let's define the edges of the PSTH
    @info "Burst Analysis: detecting... (th_mode = $th_mode)"

    edges = 0:bin:T
    result = fit(Histogram, spk[:, 1], edges) # Hist of spike times (PSTH), all chans

    if th_mode == "fix" # Fixed threshold for burst detection, detection on PSTH
        # Threshold for burst detection as specified by the user (in the config file)
        psth = result.weights                    # Histogram of spike times

    else # th_mode == "dyn" or th_mode == "syn" or th_mode == "amo"

        psth = result.weights                    # Histogram of spike times

        # Instantaneous synchronous activity index estimation ----------------
        nbin = length(edges) - 1
        active = Vector{Float32}(undef, nbin)  # Mem alloc for active

        # Let's load spike times, for each channel, individually.
        tmq = false                 # Flag to check if it is the first channel
        for i in 1:Nchans                           # Loop over each channels
            filename = joinpath(pathname, "SPK/spk_$i.txt") # spk times, i-th chan
            if isfile(filename)                             # Check if exists
                tmp = readdlm(filename)                     # Load it
                result = fit(Histogram, tmp[:, 1], edges)   # PSTH, i-th chan
                if tmq == false                             # If it is first chan
                    active = Int.(result.weights .> 0)      # store as {0,1} array
                    tmq = true                              # Set the flag
                else                     # If not first chan, accumulate results
                    active = active .+ Int.(result.weights .> 0)
                    # for each bin, active how many chans with (any) activity at that time.
                end
            end
        end # End of the loop over the channels -------------------------------------------

        if th_mode == "dyn" # adaptive thr, detection on synch activity x PSTH
            threshold = th_sn * mean(psth) * mean(active) # Dynamic threshold
            #threshold = th_sn * median(abs.(sync) / 0.6745); Use median estimator of the std??
            if threshold < min_threshold    # If below the minimal threshold
                threshold = min_threshold   # Set it to the minimal threshold
                @warn "Burst Analysis: dynamic threshold set to minimal value."
            end
            psth = psth .* active # PSTH multiplied by synch activity

        elseif th_mode == "syn" # detection on synch activity only
            # Threshold as specified by the user (in the config file)
            psth = active  # Complete replacement of psth with synch activity

        else # th_mode == "amo" # Amo's method, detection on synch activity x PSTH
            tmp_idx = findall(active .< (25.0 / 100.0 * nActiveEl))
            psth = psth .* active .* 100.0 ./ nActiveEl
            psth[tmp_idx] .= 0.0 # Set to zero the bins with less than 25% of active electrodes
        end
    end # End of the if th_mode == "fix"

    # Now we set threshold and the detection algorithm, we proceed acting on
    # the vector psth (which takes different meanings depending on the th_mode)

    # Let's detect the bursts (on whatever method or threshold chosen)
    idx = Vector{Vector{Float32}}()    # Index of events and their peak amplitude

    y = findall(psth .> threshold)     # Find the bursts over "psth" vector

    last = 0.0                         # Initialize the last burst time
    for i in eachindex(y)              # over all threshold crossings
        if y[i] >= last + rref         # current event after last refractory/dead period
            if y[i] + href - 1 > length(psth) # if the end of the burst is beyond the psth
                A = psth[y[i]:end]     # extract n samples = to half refr/dead period (in psth)
            else
                A = psth[y[i]:y[i]+href-1]  # extract n samples = to half refr/dead period (in psth)
            end
            iaux = findall(A .== maximum(A)) # introduces alignment: takes indx of max (index)
            index = y[i] + iaux[1] - 1  # index of max value
            amply = psth[index]         # max value (peak amplitude)
            push!(idx, [index, amply])  # append index of max to events list (index)
            last = index                # update index of last event detected so far
        end # if
    end # for

    nbursts = length(idx)          # number of bursts detected

    outname = joinpath(pathname, "analysed.txt")      # Define the output file name
    report("N_bursts = $(nbursts)", outname)                     # Write the total number of spikes to a file.
    @info "Post: burst analysed!"


    # Return the number of bursts detected and the burst times, the latter as a vector of Float64
    if nbursts > 0
        btimes = Vector{Float64}(undef, nbursts)  # Mem alloc for active
        for i in 1:nbursts
            btimes[i] = idx[i][1] * bin
        end
        return nbursts, btimes
    else
            return 0, Float64[]
    end

end # End of the function extract_bursts


"""
plot_raster(pathname::String, fraction::Float64, title::Bool, btimes::Vector{Float64})

Plot the raster plot of the spike times, for each fraction of the total recording time.
The function generates one or more PDF figures, storing them in the folder `figs` within the input `pathname`. If fraction is set to 1.0, then only one figure is generated, containing the entire recording time. Otherwise, multiple figures are generated, each containing a fraction of the total recording time.

### Arguments
- `pathname::String` : path to the folder containing the spike times and the configuration files (the pre-processed *.dat folder)
- `fraction::Float64` : fraction of the total recording time (e.g. 0.1; must be in the range (0, 1)) (default: 1.0)
- `title::Bool` : if true, the title of the plot is the name of the folder (default: false)

### Author(s)
- Michele Giugliano - michele.giugliano@unimore.it
"""
function plot_raster(pathname::String, fraction::Float64=1.0, title::Bool=false, btimes::Vector{Float64}=Float64[])::Int
    # Spike marker - https://docs.juliaplots.org/v1.40/gallery/pgfplotsx/generated/pgfplotsx-ref021/
    spike_marker = [
        (0.0, -0.5),  # Bottom left
        (0.0, 0.5),   # Top left
        (0.0, 0.5),   # Top right
        (0.0, -0.5)   # Bottom right
    ] # This makes it possible to use plot(scatter) and it is ultra-fast!

    filename = joinpath(pathname, "spk.txt") # Spike times file (spk.txt)

    if !isfile(filename)
        @error "Raster plot: spk.txt file not found."
        return -1
    end

    spk = readdlm(filename)     # Load ALL spike times

    if size(spk, 1) == 0          # If the file is empty,
        @warn "Raster plot: no spikes found!"
        return -1
    end # if

    maxt = Int(ceil(maximum(spk[:, 1]), digits=0)) # Maximum time in spike times
    Nel = length(unique(abs.(spk[:, 2]))) # Number of electrodes

    start = 0.0 # Start time for the first fraction to plot
    stop = fraction * maxt # Stop time for the first fraction to plot

    count = 1# Counter for the figure(s) to generate

    while stop <= maxt# Loop over the fractions of the total recording time

        idx = findall(start .< spk[:, 1] .<= stop) # Find the spikes in the current fraction
        max = Int(ceil(stop, digits=0)) # Maximum time in the current fraction
        min = Int(floor(start, digits=0)) # Maximum time in the current fraction
        tspikes = spk[idx, 1]# Spike times
        electrodes = spk[idx, 2]# Electrodes

        if title
            mytitle = basename(pathname)[1:end-4] # Title of the plot (folder name)
        else
            mytitle = ""
        end

        # Plot the raster plot - spike times vs electrode number
        p = plot(tspikes, abs.(electrodes),
            seriestype=:scatter, # Scatter plot
            marker=(Shape(spike_marker), 8, :black), # Marker type, size, color
            ygrid=true,
            xgrid=false,
            #yticks=true,
            showxticks=true,
            showyticks=false,
            xaxis=false,
            yaxis=true,
            foreground_color_axis =false, #was :white
            yticks = [1; [j for j in 10:10:Nel]], [string(1); [string(i) for i in 10:10:Nel]],
            #showaxis=false,
            #xlabel="time [s]", # X-axis label
            ylabel="electrode #", # Y-axis label
            title=mytitle,
            box=:off, # Box around the plot
            legend=false, # No legend
            linealpha=0.0, # No line
            bgcolor=:white, # White background
            size=(800, 600), # Size of the plot in pixels
            left_margin=5Plots.mm,  # Increase left margin
            right_margin=10Plots.mm, # Increase right margin
            top_margin=5Plots.mm,   # Increase top margin
            bottom_margin=-3Plots.mm)  # Increase bottom margin

        if fraction < 1.0
            current_xticks = xticks(p)# Get the current xticks
            tmp, tmq = current_xticks[1] # Get the current xticks
            pushfirst!(tmq, string(min)) # Add the start time to the xticks
            push!(tmq, string(max)) # Add the maximum time to the xticks
            new_xticks = (sort(unique([min; tmp; max])), []) # Update the xticks
            plot!(p, xticks=new_xticks)# Update the xticks
        end
        plot!(p, xlim=(start, stop)) # Set the x-axis limits
        plot!(p, ylim=(0, Nel+1)) # Set the y-axis limits

        # Plot the histogram of the spike times (conventionally using 10 ms bins)
        bin = 0.1 # 10 ms bins
        edges = 0:bin:max
        result = fit(Histogram, spk[:, 1], edges) # Hist of spike times (PSTH), for all chans
        psth = result.weights / (bin * Nel)       # Histogram of spike times
        q = plot(edges, psth,
            seriestype=:bar,
            grid=true,
            xlabel="time [s]",
            ylabel="rate [Hz/elec]",
            legend=false,
            box=:off,
            foreground_color_axis =false, #was :white
            barcharacteristics=(0.8, :black),
            bgcolor=:white,
            size=(600, 600),
            left_margin=5Plots.mm,
            right_margin=10Plots.mm,
            top_margin=0Plots.mm,
            bottom_margin=0Plots.mm)

        if length(btimes) > 0
            @info "Raster plot: annotating bursts."
            for i in 1:length(btimes)
                plot!(q, [btimes[i], btimes[i]], [14.0, 15.0], color=:red, linewidth=4.0)
            end
        end

        if fraction < 1.0
            new_xticks = (sort(unique([min; tmp; max])), tmq) # Update the xticks
            plot!(q, xticks=new_xticks)# Update the xticks
        end
        plot!(q, xlim=(start, stop)) # Set the x-axis limits
        plot!(q, ylim=(0, 10.0)) # Set the y-axis limits

        # Let's plot both plots on the same figure
        l = @layout [a; b{0.2h}]
        o = plot(p, q, layout=l)

        # Create "figs" folder if it does not exist yet
        if !isdir(joinpath(pathname, "figs"))
            mkdir(joinpath(pathname, "figs"))
        end

        fname = joinpath(pathname, "figs/raster_plot_$(fraction*100)%_$(count).pdf")
        savefig(o, fname)  # Save as PDF
        #@info "Raster plot: $(fname) saved on disk."

        #display(p)  # Display the plot on the screen

        count += 1# Update the counter
        start = stop # Update the start time
        stop += fraction * maxt # Update the stop time
    end # while

    @info "Raster plot: $(count-1) figure(s) saved on disk."
    return 0 # Return 0 if everything went well
end # End of the function plot_raster



"""
plot_frequencies(pathname::String, fraction::Float64=1.0, title::Bool=false)::Int

Plot the distribution of firing rates, for each fraction of the total recording time.
The function generates one or more PDF figures, storing them in the folder `figs` within the input `pathname`. If fraction is set to 1.0, then only one figure is generated, containing the entire recording time. Otherwise, multiple figures are generated, each containing a fraction of the total recording time.

### Arguments
- `pathname::String` : path to the folder containing the spike times and the configuration files (the pre-processed *.dat folder)
- `fraction::Float64` : fraction of the total recording time (e.g. 0.1; must be in the range (0, 1)) (default: 1.0)
- `title::Bool` : if true, the title of the plot is the name of the folder (default: false)

### Author(s)
- Michele Giugliano - michele.giugliano@unimore.it
"""
function plot_frequencies(pathname::String, fraction::Float64=1.0, title::Bool=false)::Int

    filename = joinpath(pathname, "spk.txt") # Spike times file (spk.txt)

    if !isfile(filename)
        @error "Frequencies plot: spk.txt file not found."
        return -1
    end

    spk = readdlm(filename)     # Load ALL spike times

    if size(spk, 1) == 0          # If the file is empty,
        @warn "Frequencies plot: no spikes found!"
        return -1
    end # if

    maxt = Int(ceil(maximum(spk[:, 1]), digits=0)) # Maximum time in spike times
    Nel = length(unique(abs.(spk[:, 2]))) # Number of electrodes

    start = 0.0 # Start time for the first fraction to plot
    stop = fraction * maxt # Stop time for the first fraction to plot

    count = 1# Counter for the figure(s) to generate

    while stop <= maxt# Loop over the fractions of the total recording time

        idx = findall(start .< spk[:, 1] .<= stop) # Find the spikes in the current fraction
        electrodes = abs.(spk[idx, 2])# Electrodes

        if title
            mytitle = basename(pathname)[1:end-4] # Title of the plot (folder name)
        else
            mytitle = ""
        end

        # Calculate the firing rates for each electrode
        rates = zeros(Float32, Nel) # Initialize the array to store the firing rates
        for i in 1:Nel
            idx = findall(electrodes .== i) # Find the spikes on the i-th electrode
            rates[i] = length(idx) / (fraction * maxt) # Calculate the firing rate
        end

        bin = 2.5 # Hz
        edges = 0:bin:40 # Edges for the histogram

        # Plot the histogram of the firing rates
        results = fit(Histogram, rates, edges) # Hist of firing rates
        p = plot(edges, results.weights,
            seriestype=:bar,
            grid=true,
            xlabel="rate [Hz]",
            ylabel="elec count",
            legend=false,
            box=:on,
            linecolor=:black,
            fillcolor=:black,
            bgcolor=:white,
            size=(800, 600),
            left_margin=5Plots.mm,
            right_margin=10Plots.mm,
            top_margin=0Plots.mm,
            bottom_margin=0Plots.mm)

        # Let's evaluate the inter-spike interval distributions, for each electrode
        isi = zeros(Float32, 0) # Initialize the array to store the inter-spike intervals
        for i in 1:Nel
            idx = findall(electrodes .== i) # Find the spikes on the i-th electrode
            if length(idx) > 1
                isi = vcat(isi, diff(spk[idx, 1])) # Calculate the inter-spike intervals
            end
        end

        bin = 2.5 # ms
        edges = 0:bin:1000 # Edges for the histogram
        results = fit(Histogram, 1000.0 .* isi, edges) # Hist of inter-spike intervals
        q = plot(edges, results.weights,
            seriestype=:bar,
            grid=true,
            xlabel="ISI [ms]",
            ylabel="count",
            legend=false,
            box=:on,
            linecolor=:black,
            fillcolor=:black,
            bgcolor=:white,
            logy=true,
            logx=true,
            size=(800, 600),
            left_margin=5Plots.mm,
            right_margin=10Plots.mm,
            top_margin=0Plots.mm,
            bottom_margin=0Plots.mm)

        # Create "figs" folder if it does not exist yet
        if !isdir(joinpath(pathname, "figs"))
            mkdir(joinpath(pathname, "figs"))
        end

        l = @layout [a; b{0.5h}]
        o = plot(p, q, layout=l)


        fname = joinpath(pathname, "figs/rate_hist_plot_$(fraction*100)%_$(count).pdf")
        savefig(o, fname)  # Save as PDF
        #display(p)  # Display the plot on the screen

        count += 1# Update the counter
        start = stop # Update the start time
        stop += fraction * maxt # Update the stop time
    end # while

    @info "Frequencies plot: $(count-1) figure(s) saved on disk."
    return 0 # Return 0 if everything went well
end # End of the function plot_frequencies


