#!/bin/bash
# Sextractor for HPC
# usage: run-sextractor.sge {input_fits} {weight_fits}
#
# By Francisco Forster and Juan-Carlos Maureira
# CMM. University of Chile
#############################################################
#SBATCH -n 1                    
#SBATCH --exclusive
#SBATCH -J sextractor
#SBATCH -o sextractor.%j.out 
#SBATCH -e sextractor.%j.err
#SBATCH -p levque

# load the proper enviroment module
module load astro

# check for arguments
if [ $# != 2 ]; then
   echo "usage: $0 {input_fits} {weight_fits}"
   exit 1
fi

# get the input arguments (see usage)
INPUT_FITS=$1
WEIGHT_FITS=$2

if [ ! -f "$INPUT_FITS" ] || [ ! -f "$WEIGHT_FITS" ]; then
   echo "input files not found."
   exit 1
fi

# write some useful information
echo "Running at `hostname -s`"
echo "Starting time : `date '+%c'`"

# read the INPUT_FITS with the noise map WEIGHT_FITS and create a catalogue of stars 
# in the file catalogue.cat
sex $INPUT_FITS -c etc/default.sex -CATALOG_NAME catalogue.cat -WEIGHT_IMAGE $WEIGHT_FITS

echo "Ending time : `date '+%c'`"

echo "done"
