# Resets the wav.scp file to its original state after stage 0
# This should be run between songs and after decode_music.sh
# especially if it was interrupted/errored-out half way 

# TODO: Check if im'm already in this directory!
pushd espnet/egs/wsj/asr1

data_dirs="train_si284 test_dev93 test_eval92"

for dir in ${data_dirs}
do
    pushd data/$dir
    if [ ! -f wav.scp.original ]
    then
        cp -v wav.scp wav.scp.original
    fi
    cp -v wav.scp.original wav.scp
    popd
done

popd
