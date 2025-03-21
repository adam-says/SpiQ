# SπQ - SpiQ (extracellular raw voltages preprocessor)

SπQ is a batch and parallel preprocessor for electrophysiology extracellular multichannel datafiles. It is a collection of scripts and julia programs.

It leverages over the previous published work (QSpike Tools and WaveClus) and employs julia and hdf5 tools to quickly perform filtering, spike detection, extraction, and shape extraction.

It is well suited to be run on HPC infrastructures and aims at minimalism.
As in UNIX philosophy, it is supposed to perform a series of operation well, but as a collection of tools.

The documentation is [here](https://spiq.readthedocs.io/en/latest/), although still work in progress!

[![License: CC0-1.0](https://img.shields.io/badge/License-CC0_1.0-lightgrey.svg)](http://creativecommons.org/publicdomain/zero/1.0/)
<img src="/img/logo.png?raw=true" alt="SpQ logo" height="200px">

TEST FILE (for your eyes only, MCS format) [here](https://www.dropbox.com/scl/fi/k1gw5sckgigemr4dputcp/aaa.h5?rlkey=sy5n6pkjkwt0cxkplbohy4czc&dl=0n)

## Motivations

As expected, after many years and many generation of PhD students in the lab, QSpike Tools (our previous tool for routine data analysis) became hardly manageable and sloppy. We thus aimed at a complete rewriting, while exploiting hdf5 tools and julia HDF5 library.

## Libraries used

Julia packages (Distributed, HDF5, TOML, DSP, Statistics, JLD2, DelimitedFiles) are available from the standard library or otherwise instantiated from the Manifest.toml and Project.toml contained in the repository.

## Authors

- [@mgiugliano](https://www.github.com/mgiugliano)
- [@@alediclemente](https://www.github/com/alediclemente)

## Appendix

### Installing SπQ on a local PC

SpiQ is a collection of Julia scripts, calling the routines of the SpQEphysTools.jl library.

These are

- crunch.jl
- analyze.jl
- ccanalyze.jl

We assume we are under macOs, although very similar instructions apply for Linux OS.

We first install the HDF5-MPI library [1] to access HDF5 files (in parallel),
git [2] (a distributed version control system, used here to download SpiQ),
and finally awk [3] (a domain-specific language designed for text processing, used
here as a data extraction tool).

To install these packages
- open a terminal (/Applications/Utilities/Terminal.app  OR cmd + space + terminal)
- install brew, following the instructions available at https://brew.sh/
- then type (from the command line of the terminal)
	> brew install git hdf5-mpi awk

We then install Julia [4], using the juliaup [5] cross-platform installer and version
manager.

To install Julia,
- type (from he command line of the terminal)
 > brew install juliaup

 > juliaup add release

Finally, download the latest version of the SpiQ script collection [6], by using git.
We suggest creating a folder on your disk, dedicated to SpiQ (e.g. /Users/mikey/data_analysis).
Note: we assumed your login name (corresponding to an already existing folder on disk) is named
"mikey" (replace it to what your home folder is called).

To install SpiQ, we use git to "clone" its GitHub "repository"
- type (from the command line of the terminal)
 > mkdir -p /Users/mikey/data_analysis
 > cd /Users/mikey/data_analysis
 > git clone https://github.com/mgiugliano/SpiQ
 > cd SpiQ


# How to use SpiQ - crunch.jl

Configuring the parameters of each SpiQ script for the initial "pre-processing" or subsequent analysis,
requires editing the text file named config.toml. This files follows a special format, called Tom's
Obvious Minimal Language [7], and contains several sections referring to 1) LFP analysis (i.e. "lfp"),
2) peak detection (i.e. "detection"), 3) extraction of "event" waveforms for subsequent spike sorting
(i.e. "sorting"), 4) burst analysis (i.e., "bursting").

The first step of the analysis performed by SpiQ, thanks to the SpQEphysTools.jl library is
to perform filtering, peaks detection, and "events" extraction. It is called "crunching" and it is
one of the computationally intensive component of the extracellular raw voltage recording analysis.
It is also the prerequisite for any further post-processing of the data.

SpiQ's crunch.jl expects to find all .h5 raw data files all in one single folder, containing the
extracellular recordings from conventional or high-density MEAs experiments. It follows that each file
must have a unique filename. Say that the files are in the folder /Users/mikey/data/December2024.
SpiQ's crunch.jl will analyse each .h5 file independently, running in parallel across individual cores
of your CPU, and create for each .h5 file a folder with the same name and the suffix .dat. This folder
will contain several files and (sub)folders. In particular, it will contain a copy of the config.toml
file that was used for the analysis. In this way, it is very hard to loose track on how the analysis
was performed (e.g. settings for the high-pass filtering, signal-to-noise threshold, etc.).

SpiQ comes with a number of special bash scripts, in the ./src folder. Currently they are t
wo and
refers to the data file format of the MultiChannel Systems (mcs) and the 3BRAINs (brw) hardware
platforms and data acquisition software:
  - get_info_brw.sh
  - get_info_mcs.sh

These are automatically invoked by the SpiQ's script(s) and extract info from a given
hdf5 data file. These info is encoded in a .toml text file, both human and machine readable, that is
also saved in the destination. This file is called meta.toml and its information should NOT be altered
by the user.

Other files and (sub)folders are:

 - spk.txt
 - SPK/spk_1.txt
 - SPK/spk_2.txt
 - :
 -
 - LFP/lfp_1.txt
 - LFP/lfp_2.txt
 - :
 -
 - figs/raster_plot_25.0%.pdf
 -
 - CCG/
 -
 - config.toml
 - meta.toml


 The SPK and LFP folders are created if the corresponding sections exist in the config.toml file.
 The former contains a text file for each "channel" found in the .h5 file, named with the hardware
 channel name (i.e. NOT the decorated MEA microelectrode identifier). This text file is a tab delimited
 data file, with two columns: time (in ms???) and the +1 or -1, depending of the polarity of the
 peal event detected, as in an elementary spike-sorting algorithm. This is in fact the fastest and
 easiest preliminary unit classification that we can do.

 The LFP folder instead contains, for each "channel" the low-passed (and decimated) version of the
 extracellular recording, enabling subsequent analysis of local field potentials.

 The file /spk.txt contains all the information contained individually in each of the SPK/spk_*.txt files
 but in a lumped form. Particularly, the format for the first of the two columns is as already described
 while for the second column the number of the channel is used. The polarity of the event is still captured
 by a + or minus sign attributed to the channel number.


### References - to learn more:
[1] https://www.hdfgroup.org/solutions/hdf5/
[2] https://git-scm.com/
[3] https://github.com/onetrueawk/awk
[4] https://julialang.org/
[5] https://github.com/JuliaLang/juliaup
[6] https://github.com/mgiugliano/SpiQ
[7] https://toml.io/en/





### Installing SπQ on a HPC

Work in progress. See the ```install.sh``` script.

Both the ```Manifest.toml``` and the ```Project.toml``` are included. This allows to install the project dependencies in a, hopefully, reproducible way. The command to perform the pre-compilation is also included.

```julia
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
```
Note: as we aim at reproducing rigorously a fixed state of all packages used by the project, we are also including the Manifest.toml besides the Project.toml.

## Operation and features

- SπQ is invoked as: ```julia process.jl datafile.h5```


## Funding

Partial financial support from the International School of Advanced Studies, the University of Modena and Reggio Emilia is kindly acknowledged. The development of SπQ has been supported by the eBRAINS-Italy PNRR Infrastructure project.

<img src="/img/EU.png?raw=true" alt="EU logo" height="70px"> <img src="/img/MUR.jpg?raw=true" alt="MUR logo" height="100px"> <img src="/img/PNRR.jpg?raw=true" alt="PNRR logo" height="100px">

<img src="/img/eBRAINSItaly.jpg?raw=true" alt="eBRAINS-Italy logo" height="100px">

