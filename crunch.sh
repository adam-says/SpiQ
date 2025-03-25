#!/usr/bin/env bash

export JULIAEXE=/home/mgiuglia/sw/bin/julia
export SPQTOOLS=/home/mgiuglia/SpiQ
export INPUT_DIR=/scratch/mgiuglia/sara
export LOGDIR=/home/mgiuglia/LOGS

# Rename the files, replacing spaces with underscores, so that no
# problems arise when passing the filename as an argument later on.

cd $INPUT_DIR
for f in *.h5; do
  if [ -f "$f" ]; then
    newname=$(echo $f | tr ' ' '_')
    mv "$f" "$newname"
  fi
done

cd $SPQTOOLS


Files=$INPUT_DIR/*.h5 					# Full-path filenames...

Nfiles=$(echo $Files | wc -w | tr -d '[:space:]')   # Counting how many *.h5 files there are...

echo "Ready to process $Nfiles input *.h5 files..."

# Let's now loop over all the *.h5 files in INPUT_DIR
myCounter=1                                                 # Simple counter for diagnostic msgs
for f in $Files; do                                         # For each *.h5 file in INPUT_DIR..
  echo "Analysing file $f [$myCounter out of $Nfiles]"    # Print some diagnostic message
  $JULIAEXE --project=$SPQTOOLS/Project.toml $SPQTOOLS/crunch.jl $f # The actual job to be scheduled
  echo "Done with file $f"
  let "myCounter++" 1
done
# ==== END OF JOB COMMANDS ===== #

# Wait for processes, if any.
echo "Waiting for all the processes to finish..."


