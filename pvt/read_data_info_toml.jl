#!/usr/bin/env julia
# -*- coding: utf-8 -*-

# The script is part of the QSpiQ project.
#
# Nov 2024, M. Giugliano (mgiugliano@gmail.com)
# github.com/mgiugliano

using TOML

#-- TOML --------------------------------------
#tomlfile = replace(filename, ".h5" => ".toml")
meta = joinpath(OUTPUT, "meta.toml")
if !isfile(meta)
    @error "$meta not found."
    exit(1)
end

infofile = TOML.parsefile(meta)
Nchans   = infofile["info"]["Nchans"]     # Number of channels
Nsamples = infofile["info"]["Nsamples"]   # Number of samples per channel

Tick     = infofile["chans"]["Tick"]      # Sampling interval in us
ADZero   = infofile["chans"]["ADZero"]    # ADZero
ConversionFactor = infofile["chans"]["ConversionFactor"] # D/A conversion factor
Exponent = infofile["chans"]["Exponent"]  # Exponent for the conversion factor
#----------------------------------------------
srate = 1E6 / Tick                          # Sampling rate in Hz
c     = ConversionFactor * 10. ^ Exponent;  # Conversion from AD to physical units (V)
d     = - ADZero * c;                       # Conversion from AD to physical units (V)
#----------------------------------------------


