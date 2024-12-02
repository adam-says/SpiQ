#!/usr/bin/env bash

# get_info.sh - MultiChannel System hdf5 file info extractor.
#
# Given a hdf5 file (MCS format), this script extracts data
# attributes and generates a .toml output file with them.
#
# Usage: get_info.sh <MCS hdf5 file>
#
# Nov 2024, M. Giugliano (mgiugliano at gmail.it)
# github.com/mgiugliano

VER="0.2"               # Version of the script
NAME="get_info.sh (MCS)" # Name of the script
DATE=$(date)            # Date when the script was run
USER=$(whoami)          # User who ran the script
HOST=$(hostname)        # Host where the script was run

# If no hdf5 file provided as input, exit
if [ -z "$1" ]; then
    echo "USAGE: $NAME <MCS hdf5 file>"
    exit
fi

# Let's check if the input file exists and is a hdf5 file.
if [ ! -f $1 ]; then
    echo "ERROR: $1 not found!!"
    exit
fi
#-----------------------------------------------------
# Requires h5dump, awk, and basename to be installed.
# Is h5dump installed?
if ! command -v h5dump &> /dev/null; then
    echo "ERROR: h5dump not found!! Install hdf5-tools." &&  exit
fi
# Is h5stat installed?
if ! command -v h5dump &> /dev/null; then
    echo "ERROR: h5stat not found!! Install hdf5-tools." &&  exit
fi
# Is awk installed?
if ! command -v awk &> /dev/null; then
    echo "ERROR: awk not found!!" && exit
fi
# Is basename installed?
if ! command -v basename &> /dev/null;then
    echo "ERROR: basename not found!!" && exit
fi
#-----------------------------------------------------

# Let's use h5stat to check if the file is a hdf5 file.
if ! h5stat $1 &> /dev/null; then
    echo "ERROR: $1 is not a hdf5 file!!"
    exit
fi

BYTES=$(h5stat $1 | grep "Total raw data size:" | awk -F': ' '{print $2}')
#-----------------------------------------------------
# The output file will be a .toml text file. It contains
# a "header" (as a comment). The .toml file will have the
# same name as the hdf5 file, but with a .toml extension.

OUTPUT=$(basename $1)       # e.g. "/PATH/TO/file.h5" --> "file.h5"
OUTPUT=${OUTPUT%.*}.toml    # e.g. --> "file.toml"

echo "#" > $OUTPUT
echo "# Script:     $NAME v $VER" >> $OUTPUT
echo "# Launched at $DATE" >> $OUTPUT
echo "# by          $USER@$HOST" >> $OUTPUT
echo "# on          $1" >> $OUTPUT
echo "# ---------------------------------" >> $OUTPUT
echo "" >> $OUTPUT
echo "[info]" >> $OUTPUT
#-----------------------------------------------------

echo "type = MCS" >> $OUTPUT

# Extracting the desired attributes from the hdf5 file requires a bit of
# bash-fu. We will use h5dump to extract the attributes, and awk to
# process the output. We will then write the attributes to a .toml file.
# The attributes we are interested in are listed in the KEYS variable.
# NOTE: The KEYS variable is a space-separated string, not a bash array of strings.

# This is MCS-specific. The keys are the attributes we are interested in.
KEYS="GeneratingApplicationName \
    GeneratingApplicationVersion \
    McsDataToolsVersion \
    McsHdf5ProtocolType \
    McsHdf5ProtocolVersion \
    Data/Comment \
    Data/Date \
    Data/MeaLayout \
    Data/MeaName \
    Data/MeaSN \
    Data/ProgramName \
    Data/ProgramVersion \
    Data/Recording_0/Comment \
    Data/Recording_0/Duration \
    Data/Recording_0/Label \
    Data/Recording_0/AnalogStream/Stream_0/DataSubType \
    Data/Recording_0/AnalogStream/Stream_0/Label \
    Data/Recording_0/AnalogStream/Stream_0/StreamType"

# UNUSED BY MY CHOICE (I MIGHT RECONSIDER IN THE FUTURE)
#    Data/Recording_0/RecordingID \
#    Data/Recording_0/RecordingType \
#    Data/Recording_0/TimeStamp \
#    Data/Recording_0/AnalogStream/Stream_0/SourceStreamGUID \
#    Data/Recording_0/AnalogStream/Stream_0/StreamGUID \
#    Data/Recording_0/AnalogStream/Stream_0/StreamInfoVersion \

# For the sole sake of writing in the output file the keys in a more readable way,
# let's now simplify them, removing their "path".
#simpleKEYS=$(echo "$KEYS" | awk '{
#for (i = 1; i <= NF; i++) {
#    gsub(/.*\//, "", $i)  # Remove everything up to the last slash
#    printf "%s ", $i
#  }
#}')

# Let's instead replace the / with a _ in the keys.
simpleKEYS=$(echo "$KEYS" | awk '{
  for (i = 1; i <= NF; i++) {
    gsub(/\//, "_", $i)  # Replace / with _
    printf "%s ", $i
  }
}')

# Let's then format a list of attributes for h5dump. In fact,
# h5dump does allow to specify multiple attributes with the -a flag.
ATTRIBUTES=$(echo "$KEYS" | awk '{
  for (i = 1; i <= NF; i++) {
    printf "-a %s ", $i
  }
}')

# We finally use again awk to extract the values of the attributes
# from the output of h5dump, and write them to the output file.
h5dump ${ATTRIBUTES[@]} -p $1 | awk -v MYKEYS="$simpleKEYS" '
BEGIN {
  i = 1;
  split(MYKEYS, a, " ");
}
/DATA {/ {
  getline;
  line = substr($0, 8);
  printf "%s = %s\n", a[i], line;
  i = i + 1;
}'  >> $OUTPUT

echo "Bytes = $BYTES" >> $OUTPUT

# Extracting the number of channels and the number of samples.
h5dump -H -d Data/Recording_0/AnalogStream/Stream_0/ChannelData $1 | grep DATASPACE | awk '{print "Nchans = " $5 "\nNsamples = " $6}' | sed 's/,//' >> $OUTPUT
#-----------------------------------------------------

echo "" >> $OUTPUT
#-----------------------------------------------------

# This is the second part of the script and it is MCS-specific.
# By using h5dump and awk again, we will extract the list of channels
# and their names from the hdf5 file. We will write them to the output file.
# We will use the -d flag to specify the dataset to dump
# and the -p flag to print the data values only (no metadata)
# We will use awk to extract the channel names and numbers
# and write them to the output file.
# We will also write the number of channels to the output file.

echo "[chans]" >> $OUTPUT

h5dump -d /Data/Recording_0/AnalogStream/Stream_0/InfoChannel -p $1 | awk '
BEGIN {
  i = 1;
}
/): {/ {
  getline;
  gsub(/^[ \t]+/, "", $0);   # Remove leading spaces
  # Remove commas
  gsub(/,/, "", $0);
  ChannelID = $0;

  getline;
  getline;
  getline;
  getline;

  gsub(/^[ \t]+/, "", $0);
  gsub(/,/, "", $0);
  ChannelLabel = $0;

  getline;
  getline;
  gsub(/^[ \t]+/, "", $0);
  gsub(/,/, "", $0);
  Unit = $0;

  getline;
  gsub(/^[ \t]+/, "", $0);
  gsub(/,/, "", $0);
  Exponent = $0;

  getline;
  gsub(/^[ \t]+/, "", $0);
  gsub(/,/, "", $0);
  ADZero = $0;

  getline;
  gsub(/^[ \t]+/, "", $0);
  gsub(/,/, "", $0);
  Tick = $0;

  getline;
  gsub(/^[ \t]+/, "", $0);
  gsub(/,/, "", $0);
  ConversionFactor = $0;

  getline;
  gsub(/^[ \t]+/, "", $0);
  gsub(/,/, "", $0);
  ADCBits = $0;

  getline;
  gsub(/^[ \t]+/, "", $0);
  gsub(/,/, "", $0);
  HighPassFilterType = $0;

  getline;
  gsub(/^[ \t]+/, "", $0);
  gsub(/,/, "", $0);
  HighPassCutOffFrequency = $0;

  getline;
  gsub(/^[ \t]+/, "", $0);
  gsub(/,/, "", $0);
  HighPassFilterOrder = $0;

  getline;
  gsub(/^[ \t]+/, "", $0);
  gsub(/,/, "", $0);
  LowPassFilterType = $0;

  getline;
  gsub(/^[ \t]+/, "", $0);
  gsub(/,/, "", $0);
  LowPassCutOffFrequency = $0;

  getline;
  gsub(/^[ \t]+/, "", $0);
  gsub(/,/, "", $0);
  LowPassFilterOrder = $0;

  if (i == 1) {
   printf "Unit = %s\n", Unit;
   printf "Exponent = %s\n", Exponent;
   printf "ADZero = %s\n", ADZero;
   printf "Tick = %s\n", Tick;
   printf "ConversionFactor = %s\n", ConversionFactor;
   printf "ADCBits = %s\n", ADCBits;
   printf "HighPassFilterType = %s\n", HighPassFilterType;
   printf "HighPassCutOffFrequency = %s\n", HighPassCutOffFrequency;
   printf "HighPassFilterOrder = %s\n", HighPassFilterOrder;
   printf "LowPassFilterType = %s\n", LowPassFilterType;
   printf "LowPassCutOffFrequency = %s\n", LowPassCutOffFrequency;
   printf "LowPassFilterOrder = %s\n", LowPassFilterOrder;
   printf "\n\n";
   printf "[channels_names]\n";
  }
  printf "ID_%s = %s\n", ChannelID, ChannelLabel;
  i = i + 1;
}' >> $OUTPUT

echo "" >> $OUTPUT

#-----------------------------------------------------

echo "Output written to $OUTPUT. Done."

