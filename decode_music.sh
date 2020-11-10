PROJECT_ROOT=$(pwd)
DRY_RUN=false

pushd espnet/egs/wsj/asr1

./reset_wavscp.sh

for song_dir in $PROJECT_ROOT/Mixtures/*
do

    echo -e "\n\n================================================================="
    echo "$(date)            $song_dir"

    if $DRY_RUN
    then
        echo "./run.sh --stage 0.5 --stop_stage 1 --ngpu 0 \
            --noise_file \"$song_dir/mixture.wav\" \
            --mix_snr 3 \
            --noise_timestamp 15.0 "
        echo "./run.sh --stage 5"
        pushd exp/train_si284_pytorch_train_no_preprocess
        echo "mkdir $song_dir/mix-snr3_timestamp15"
        echo "mv decode_* $song_dir/mix-snr3_timestamp15"
        popd
    else
        ./run.sh --stage 0.5 --stop_stage 1 --ngpu 0 \
            --noise_file "$song_dir/mixture.wav" \
            --mix_snr 3 \
            --mix_level 0 \
            --noise_timestamp 15.0 
        ./run.sh --stage 5

        pushd exp/train_si284_pytorch_train_no_preprocess
        mkdir $song_dir/mix-snr3_timestamp15
        mv decode_* $song_dir/mix-snr3_timestamp15
        popd

        ./reset_wavscp.sh
    fi

done

popd
