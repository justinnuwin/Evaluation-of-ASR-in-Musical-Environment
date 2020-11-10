PROJECT_ROOT=$(pwd)
DRY_RUN=true

pushd espnet/egs/wsj/asr1

for song_dir in $PROJECT_ROOT/Mixtures/*
do
    echo "$song_dir"

    if $DRY_RUN
    then
        echo "./run.sh --stage 0.5 --stop_stage 1 --ngpu 0 \
            --noise_file=\"$song_dir/mixture.wav\" \
            --mix_snr 3 \
            --noise_timestamp=15.0 "
        pushd exp/train_si284_pytorch_train_no_preprocess
        echo "mv -r decode_* $song_dir/"
        popd
    else
        ./run.sh --stage 0.5 --stop_stage 1 --ngpu 0 \
            --noise_file="$song_dir/mixture.wav" \
            --mix_snr 3 \
            --noise_timestamp=15.0 

        pushd exp/train_si284_pytorch_train_no_preprocess
        mv -r decode_* $song_dir/
        popd
    fi

done

popd
