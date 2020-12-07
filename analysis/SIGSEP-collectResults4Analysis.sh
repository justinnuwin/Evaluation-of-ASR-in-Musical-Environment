#!/bin/bash
# Script to generate the sorted results and mixes for for analysis for the SIGSEP dataset
# This dataset is formatted by $DATASET_DIR/$instruments/$RESULTS_DIR_BASENAME
# The DATASET_DIR and RESULTS_DIR_BASENAME are fixed, but each trial is performed over
# different instruments. This script can be adapted for use on other datasets if the 
# directory structure matches. The instruments variable will need to be updated to
# reflect the directory names of the dataset.

if [ $# != 3 ]
then
    >&2 echo "usage: $0 DATASET_DIR RESULTS_DIR_BASENAME OUTPUT_DIR"
    exit 1
fi

DATASET_DIR=$1              # Should match decode_music.sh
RESULTS_DIR_BASENAME=$2     # Follows the format: results-mix-snrXX-lvXX-startXX
OUTPUT_DIR=$3

instruments="bass drums other vocals"   # The variable directory name
decode_type="char word"
test_set="eval dev"

mkdir -p $OUTPUT_DIR

for instr in $instruments
do

    for type in $decode_type
    do
        for ts in $test_set
        do
            results_dir=$DATASET_DIR/$instr/$RESULTS_DIR_BASENAME   # Support wildcards
            results_dir_basename=$(basename $results_dir)
            echo $results_dir
            python3 sort_results.py $results_dir $type $ts \
                --output-dir $OUTPUT_DIR/sorted-$type-$ts-${instr}__$results_dir_basename
        done
    done


#   python3 gen_mixes.py --sph2pipe ../kaldi/tools/sph2pipe_v2.5/ --outputFmt mp3 \
#       --output-dir $OUTPUT_DIR/$instr-mixes $DATASET_DIR/$instr/$RESULTS_DIR_BASENAME/test_dev93_wav.scp
#   python3 gen_mixes.py --sph2pipe ../kaldi/tools/sph2pipe_v2.5/ --outputFmt mp3 \
#       --output-dir $OUTPUT_DIR/$instr-mixes $DATASET_DIR/$instr/$RESULTS_DIR_BASENAME/test_eval92_wav.scp

done
