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
- and contributors

## Appendix


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

