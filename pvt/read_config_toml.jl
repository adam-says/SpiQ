#!/usr/bin/env julia
# -*- coding: utf-8 -*-

# The script is part of the QSpiQ project.
#
# Nov 2024, M. Giugliano (mgiugliano@gmail.com)
# github.com/mgiugliano

using TOML

#-- TOML --------------------------------------
config = joinpath(OUTPUT, "config.toml")

if !isfile(config)
    @error "$config not found."
    exit(1)
end

configfile  = TOML.parsefile(config)
fmin_d = configfile["detection"]["fmin"]
fmax_d = configfile["detection"]["fmax"]
stdmin = configfile["detection"]["stdmin"]
stdmax = configfile["detection"]["stdmax"]
event  = configfile["detection"]["type"] == "both" ? 0 : configfile["detection"]["type"] == "pos" ? 1 : -1
ref    = configfile["detection"]["refractory"]          # ms

fmin_s = configfile["sorting"]["fmin"]
fmax_s = configfile["sorting"]["fmax"]
dpre   = configfile["sorting"]["delta_pre"]             # ms
dpost  = configfile["sorting"]["delta_post"]            # ms
factor = configfile["sorting"]["interpolation_factor"]
spline = configfile["sorting"]["cubic_spline"] == "y"
shapes = configfile["sorting"]["save_shapes"] == "y"
#----------------------------------------------


