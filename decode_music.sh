# This script follows this directory structure:
# DATASET_ROOT/
# ├─ song_1/
# │  ├─ some.wav
# │  ├─ another.wav
# ├─ song_2/
# │  ├─ test.wav
# │  ├─ cool.wav
# ...
#
# If DATASET_DIR is set to DATASET_ROOT, then this script will run a trial (a complete mixing and decoding
# of the speech dataset) for each directory under DATASET_ROOT, randomly mixing the audio files under
# each directory with the speech following a uniform distribution.
#
# If DATASET_DIR is set to a directory in DATASET_ROOT (song_2 for example), this script will run a 
# separate trial for each song in the directory (i.e. test.wav, cool.wav).
#
# If there are spaces in the foldernames, use remove_spaces_from_dataset_paths.sh which looks for
# song folders under DATASET_ROOT matching the following schema
#
# DATASET_ROOT/
# ├─ SongID - Artist Name - Song Title/
# ├─ SongID - Artist Name - Song Title/
# ├─ SongID - Artist Name - Song Title/
# ...
# 


PROJECT_ROOT=$(pwd)             # Location of this script. Shouldn't need to change
MIX_SNR=15                      # Relative SNR between utterance and noise
MIX_LEVEL=0                     # Output level of mix
NOISE_START=15                  # Number of seconds into the noise source to start mixing
DATASET_DIR=SIGSEP/12-4_Other_12dBSNR_Start15
NOISE_FILE_EXT=wav              # Used to search for audio files


# Name of the directory to put the results in. The output directory is placed in the
# same folder as the noise source that was mixed
OUTPUT_DIR=results-mix-snr${MIX_SNR}-lv${MIX_LEVEL}-start${NOISE_START}



pushd espnet/egs/wsj/asr1
for song_dir in $PROJECT_ROOT/$DATASET_DIR/*
do
    echo -e "\n\n================================================================="
    echo "$(date)            $song_dir"


    if [ "$(basename $song_dir)" == "info" ]    # Skip info file which may exist in DATASET_DIR
    then
        continue
    fi

    $PROJECT_ROOT/reset_wavscp.sh   # Reset the wav.scp back to the original from stage 0

    # Augment data and extract features from the augmented data
    ./run.sh --stage 0.5 --stop_stage 1 --ngpu 0 \
        --noise_file "$song_dir" \
        --noise_ext $NOISE_FILE_EXT \
        --mix_snr $MIX_SNR \
        --mix_level $MIX_LEVEL \
        --noise_timestamp $NOISE_START
    # Decode
    ./run.sh --stage 5 --ngpu 0

    pushd exp/train_si284_pytorch_train_no_preprocess
    mkdir -v $song_dir/$OUTPUT_DIR
    mv -v decode_* $song_dir/$OUTPUT_DIR   # Save the decoding results in exp/train_si284_*
    popd

    pushd data

    pushd test_dev93
    cp -v wav.scp $song_dir/$OUTPUT_DIR/test_dev93_wav.scp     # Save the augmented wav.scp
    cp -v noise_utt_map $song_dir/$OUTPUT_DIR/test_dev93_noise_utt_map  
    popd

    pushd test_eval92
    cp -v wav.scp $song_dir/$OUTPUT_DIR/test_eval92_wav.scp    # Save the augmented wav.scp
    cp -v noise_utt_map $song_dir/$OUTPUT_DIR/test_eval92_noise_utt_map  
    popd

    popd
done
popd
