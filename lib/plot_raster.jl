
using Plots, DelimitedFiles

# The user provided the name of the data folder (i.e. .dat)
# Therein are the data files, in text format, one value per line.
gr()

analysis_folder = ARGS[1]

# Function to create vertical bar markers
function vertical_bar(x, y; bar_height=0.8)
    return Shape([x, x], [y - bar_height/2, y + bar_height/2])
end


# Let's create a figure to plot the raster plot
# Create the raster plot
plot(
    [], [],  # Empty initial plot
    xlabel="time [ms]", ylabel="Channel #",
    legend=false,
    #ylims=(0.5, length(spike_times) + 0.5)
)

# List all the txt files in it
files = filter(x -> endswith(x, ".txt"), readdir(analysis_folder))

# Filenames are like spk_t_c5.txt, where c5 is the channel number
for file in files
    @info "Processing $file"
    tmp = split(file, "_")[end];
    tmp = split(tmp, ".")[1];
    chan= parse(Int, tmp[2:end])

    fname = joinpath(analysis_folder, file)
    spks = readdlm(fname)

    for t in spks
        plot!(vertical_bar(t, chan), color=:black, linewidth=1)
    end
end

display(plot!())

# save the figure
savefig(joinpath(analysis_folder, "raster.pdf"))
