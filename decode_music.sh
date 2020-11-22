PROJECT_ROOT=$(pwd)             # Location of this script. Shouldn't need to change
MIX_SNR=15                      # Relative SNR between utterance and noise
MIX_LEVEL=0                     # Output level of mix
NOISE_START=15                  # Number of seconds into the noise source to start mixing
DATASET_DIR=SIGSEP/11-21_Select-Sources_Trial     # Path to the dataset
NOISE_FILE_EXT=wav              # Used to search for audio files


# Name of the directory to put the results in. The output directory is placed in the
# same folder as the noise source that was mixed
OUTPUT_DIR=results-mix-snr${MIX_SNR}-lv${MIX_LEVEL}-start${NOISE_START}



pushd espnet/egs/wsj/asr1
for song_dir in $PROJECT_ROOT/$DATASET_DIR/*
do
    echo -e "\n\n================================================================="
    echo "$(date)            $song_dir"

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
