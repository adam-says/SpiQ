
using JLD2, Plots

include("read_config_toml.jl")
include("read_data_info_toml.jl")

# The user provided the name of the data folder (i.e. .dat)
# Therein are the data files, in jld2 format.

analysis_folder = ARGS[1]

# Let's create a figure to plot the raster plot
fig = plot()

# List all the jld2 files in it
files = filter(x -> endswith(x, ".jld2"), readdir(analysis_folder))

for file in files
    # Load the file
    data = load(file)
    # Get the spikes
    spikes = data["spikes"]

    println("File: $file")
end


# Load the data
for (i, file) in enumerate(files)
    data = read_toml_files(file)
    println("File $i: $file")
    println("Number of spikes: $(length(data))")
end
