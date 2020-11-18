PROJECT_ROOT=$(pwd)
DRY_RUN=false

pushd espnet/egs/wsj/asr1

pushd data/test_dev93
cp wav.scp.vanilla wav.scp
cp wav.scp wav.scp.orig
popd

pushd data/test_eval92
cp wav.scp.vanilla wav.scp
cp wav.scp wav.scp.orig
popd

for song_dir in $PROJECT_ROOT/Dataset/*
do
    
    for song in $song_dir/*
    do

        echo "\n\n====================================================================="
        echo "$(date)            $song_dir"

        fullname=$(basename $song)
        songname=$(echo $fullname|cut -d . -f1)
        prefix="mix-snr3_timestamp15-"
        dirname=$prefix$songname
        echo $song
        
        if $DRY_RUN
        then
            echo "./run.sh --stage 0.5 --stop_stage 1 --ngpu 0 \
                --noise_file \"$song\" \
                --mix_snr 3 \
                --noise_timestamp 15.0 "
            echo "./run.sh --stage 5"
            pushd exp/train_si284_pytorch_train_no_preprocess
            echo "mkdir $song_dir/$dirname"
            echo "mv decode_* $song_dir/$dirname"
            popd
        else
            ./run.sh --stage 0.5 --stop_stage 1 --ngpu 0 \
                --noise_file "$song" \
                --mix_snr 3 \
                --noise_timestamp 15.0 
            ./run.sh --stage 5

            pushd exp/train_si284_pytorch_train_no_preprocess
            mkdir $song_dir/$dirname
            mv decode_* $song_dir/$dirname
            popd

            pushd data/test_dev93
            cp wav.scp.orig wav.scp
            popd

            pushd data/test_eval92
            cp wav.scp.orig wav.scp
            popd
        fi
    done

done

popd