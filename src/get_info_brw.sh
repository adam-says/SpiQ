#!/usr/bin/env bash

# get_info.sh - 3BRAINS hdf5 file info extractor.
#
# Given a hdf5 file (3BRAIN .brw format), this script extracts data
# attributes and generates a .toml output file with them.
#
# Usage: get_info.sh <3BRAIN .brw file>
#
# Nov 2024, M. Giugliano (mgiugliano at gmail.it)
# github.com/mgiugliano

VER="0.2"               # Version of the script
NAME="get_info.sh (3BRAIN)" # Name of the script
DATE=$(date)            # Date when the script was run
USER=$(whoami)          # User who ran the script
HOST=$(hostname)        # Host where the script was run

# If no hdf5 file provided as input, exit
if [ -z "$1" ]; then
    echo "USAGE: $NAME <3BRAIN brw file>"
    exit
fi

# Let's check if the input file exists and is a hdf5 file.
if [ ! -f $1 ]; then
    echo "ERROR: $1 not found!!"
    exit
fi
#-----------------------------------------------------
# Requires h5ls, h5stat, h5dump, awk, and basename to be installed.
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

# If the file extension is brw, then it is a 3brain file.
if [[ $1 == *.brw ]]; then
    echo 'type = "3BRAIN"' >> $OUTPUT
fi

# Extracting the desired attributes from the hdf5 file requires a bit of
# bash-fu. We will use h5dump to extract the attributes, and awk to
# process the output. We will then write the attributes to a .toml file.
# The attributes we are interested in are listed in the KEYS variable.
# NOTE: The KEYS variable is a space-separated string, not a bash array of strings.

# This is 3BRAIN-specific. The keys are the attributes we are interested in.
KEYS="MinAnalogValue\
      MaxAnalogValue \
      MaxDigitalValue \
      MinDigitalValue \
      ScaleFactor \
      FrameRate \
      ExperimentType \
      Description \
      HighPassFilterCutOffFrequency \
      HighPassFilterOrder \
      BiologicalModel \
      Model \
      ChipRoi \
      Serial \
      ExperimentDateTime"


# Let's instead replace the / with a _ in the keys.
simpleKEYS=$(echo "$KEYS" | awk '{
  for (i = 1; i <= NF; i++) {
    gsub(/\//, "_", $i)  # Replace / with _
    printf "%s ", $i
  }
}')

# We finally use again awk to extract the values of the attributes
# from the output of h5dump, and write them to the output file.
h5dump -d ExperimentSettings $1 | awk -v MYKEYS="$simpleKEYS" '
BEGIN {
  FS="[\"[:space:]:,{}]+"
  RS="\n"
  split(MYKEYS, keysArr, " ");
}
{
  for (i = 1; i <= length(keysArr); i++) {
    if ($0 ~ "\""keysArr[i]"\"") {
        print keysArr[i] " = " $3
      }
  }
}'  >> $OUTPUT

echo "Bytes = $BYTES" >> $OUTPUT

# Extracting the number of channels and the number of samples.
h5ls $1/Well_A1 | grep "StoredChIdxs             Dataset {" | awk -F"[{}/]" '{print "Nchans = " $2}' >> $OUTPUT
h5ls $1/Well_A1 | grep "Raw                      Dataset {" | awk -F"[{}/]" '{print "Nsamples = " $2}' >> $OUTPUT
#-----------------------------------------------------

echo "" >> $OUTPUT
#-----------------------------------------------------

# This is the second part of the script and it is 3BRAIN-specific.
# By using h5dump and awk again, we will extract the list of channels
# and their names from the hdf5 file. We will write them to the output file.
# We will use the -d flag to specify the dataset to dump
# and the -p flag to print the data values only (no metadata)
# We will use awk to extract the channel names and numbers
# and write them to the output file.
# We will also write the number of channels to the output file.

echo "" >> $OUTPUT

#-----------------------------------------------------

echo "[ Info: Output written to $OUTPUT. Done."

