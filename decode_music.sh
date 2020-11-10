PROJECT_ROOT=$(pwd)
MIX_SNR=9
MIX_LEVEL=0
NOISE_START=15
OUTPUT_DIR=results-mix-snr${MIX_SNR}-lv${MIX_LEVEL}-start${NOISE_START}
DRY_RUN=false

pushd espnet/egs/wsj/asr1

$PROJECT_ROOT/reset_wavscp.sh

for song_dir in $PROJECT_ROOT/Mixtures/*
do

    echo -e "\n\n================================================================="
    echo "$(date)            $song_dir"

    if $DRY_RUN
    then
        echo "./run.sh --stage 0.5 --stop_stage 1 --ngpu 0 \
            --noise_file \"$song_dir/mixture.wav\" \
            --mix_snr $MIX_SNR \
            --mix_level $MIX_LEVEL \
            --noise_timestamp $NOISE_START"
        echo "./run.sh --stage 5"
        pushd exp/train_si284_pytorch_train_no_preprocess
        echo "mkdir $song_dir/$OUTPUT_DIR"
        echo "mv decode_* $song_dir/$OUTPUT_DIR"
        popd
    else
        ./run.sh --stage 0.5 --stop_stage 1 --ngpu 0 \
            --noise_file "$song_dir/mixture.wav" \
            --mix_snr $MIX_SNR \
            --mix_level $MIX_LEVEL \
            --noise_timestamp $NOISE_START
        ./run.sh --stage 5

        pushd exp/train_si284_pytorch_train_no_preprocess
        mkdir $song_dir/$OUTPUT_DIR
        mv decode_* $song_dir/$OUTPUT_DIR
        popd

        $PROJECT_ROOT/reset_wavscp.sh
    fi

done

popd
