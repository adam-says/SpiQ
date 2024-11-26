
# The script is part of the QSpiQ project.
#
# Nov 2024, M. Giugliano (mgiugliano@gmail.com)
# github.com/mgiugliano

using TOML


struct settings # settings struct
  OUTPUT::String
  LFP::Bool
  fmax::Float64
  rate::Float64

  detect::Bool
  fmin_d::Float64
  fmax_d::Float64
  stdmin::Float64
  stdmax::Float64
  event::Int
  ref::Float64

  shapes::Bool
  fmin_s::Float64
  fmax_s::Float64
  dpre::Float64
  dpost::Float64
  factor::Int
  spline::Bool

  Nchans::Int
  Nsamples::Int

  Tick::Float64
  ADZero::Float64
  ConversionFactor::Float64
  Exponent::Float64
  srate::Float64
  c::Float64
  d::Float64
end


# Add the struct definition to all workers
@everywhere struct settings # settings struct
  OUTPUT::String
  LFP::Bool
  fmax::Float64
  rate::Float64

  detect::Bool
  fmin_d::Float64
  fmax_d::Float64
  stdmin::Float64
  stdmax::Float64
  event::Int
  ref::Float64

  shapes::Bool
  fmin_s::Float64
  fmax_s::Float64
  dpre::Float64
  dpost::Float64
  factor::Int
  spline::Bool

  Nchans::Int
  Nsamples::Int

  Tick::Float64
  ADZero::Float64
  ConversionFactor::Float64
  Exponent::Float64
  srate::Float64
  c::Float64
  d::Float64
end


#-- TOML --------------------------------------
config = joinpath(OUTPUT, "config.toml")

if !isfile(config)
    @error "$config not found."
    exit(1)
end

configfile  = TOML.parsefile(config)
LFP    = configfile["lfp"]["save_lfp"] == "y"
fmax   = configfile["lfp"]["fmax"]
rate   = configfile["lfp"]["rate"]

detect = configfile["detection"]["detect"] == "y"
fmin_d = configfile["detection"]["fmin"]
fmax_d = configfile["detection"]["fmax"]
stdmin = configfile["detection"]["stdmin"]
stdmax = configfile["detection"]["stdmax"]
event  = configfile["detection"]["type"] == "both" ? 0 : configfile["detection"]["type"] == "pos" ? 1 : -1
ref    = configfile["detection"]["refractory"]          # ms

shapes = configfile["sorting"]["save_shapes"] == "n"
fmin_s = configfile["sorting"]["fmin"]
fmax_s = configfile["sorting"]["fmax"]
dpre   = configfile["sorting"]["delta_pre"]             # ms
dpost  = configfile["sorting"]["delta_post"]            # ms
factor = configfile["sorting"]["interpolation_factor"]
spline = configfile["sorting"]["cubic_spline"] == "y"
#----------------------------------------------


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


#-- Settings struct ---------------------------
s = settings(OUTPUT, LFP, fmax, rate, detect, fmin_d, fmax_d, stdmin, stdmax, event, ref, shapes, fmin_s, fmax_s, dpre, dpost, factor, spline, Nchans, Nsamples, Tick, ADZero, ConversionFactor, Exponent, srate, c, d);

@everywhere global s = $s;       # Send s to all workers
@everywhere global OUTPUT = $OUTPUT;       # Send s to all workers

