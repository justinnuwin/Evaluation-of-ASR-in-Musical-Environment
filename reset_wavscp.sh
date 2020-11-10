# Resets the wav.scp file
# This should be run between songs and after a decode_music
# is interrupted half way 

pushd espnet/egs/wsj/asr1

data_dirs="train_si284 test_dev93 test_eval92"

for dir in ${data_dirs}
do
    pushd data/$dir
    if [ ! -f wav.scp.original ]
    then
        cp wav.scp wav.scp.original
    fi
    cp wav.scp.original wav.scp
    popd
done
