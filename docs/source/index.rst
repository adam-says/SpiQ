.. SpiQ documentation master file, created by
   sphinx-quickstart on Tue Nov 26 10:47:13 2024.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

SpiQ documentation
==================

SpiQ is a Julia package for performing filtering, peak-detection, LFP/MUA extraction, and spike sorting.
It is still largely work in progress, but the goal is to provide a comprehensive set of tools for processing
suitable for electrophysiological data in our lab.

.. note::
   This is a work in progress. The documentation is incomplete and the package is still under development.

Add your content using ``reStructuredText`` syntax. See the
`reStructuredText <https://www.sphinx-doc.org/en/master/usage/restructuredtext/index.html>`_
documentation for details.


Code documentation
==================

The source code, available from GitHub, is composed of a number of modules, each of which is documented in the following sections. The code is still under development and the documentation is incomplete.

SpiQ.jl module

It defines the main types ('settings' struct) and functions for the package.

function parse_toml_files()
    - parses the config.toml and the meta.toml files
    - get the relevant information into the structure 's'

function allocate_Float64vector(num_elements::Int64)

function preproc_chan(fname::String, chan::Int, s::settings)
    - preprocess one specified channel by the following

    function prepare_bandpass(lowcut::Float64, highcut::Float64, fs::Float64)::ZPG

    function bandpass(data::Array{Float64,1}, filt::ZPG)

    function prepare_lowpass(cutoff::Float64, fs::Float64)

    function lowpass_and_dec(data::Array{Float64,1}, filt::ZPG, rate::Float64, fs::Float64)

    function extract_peaks(xf::Array{Float64,1}, thr::Float64, dpre::Float64, dpost::Float64, ref::Float64, event::Int64, srate::Float64)




.. toctree::
   :maxdepth: 2
   :caption: Contents:

