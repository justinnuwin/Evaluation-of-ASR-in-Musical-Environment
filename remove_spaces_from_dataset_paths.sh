# Helpful script to remove spaces from the SIGSEP dataset
# First argument shall be path to the ROOT of the dataset following this structure:
#
# DATASET_ROOT/
# ├─ 001 - Artists Name - Song Title/
# │  ├─ some.wav
# │  ├─ another.wav
# ├─ 002 - Artists Name - Song Title/
# │  ├─ some.wav
# │  ├─ another.wav
# ...
# 
# This script will strip the name of the artist and song from the folder path, leaving
# only the ID (and no spaces). This script will then write a file called info to each
# renamed folder containing the artist and song name.

if [ $# -ne 1 ]
then
    echo "Path to the dataset root is the only required argument"
    exit 1
fi

DATASET_ROOT=$1
DELIMITER=" - "

for song_dir in $DATASET_ROOT/*
do
    str="$song_dir"
    s=$str$DELIMITER
    array=();
    while [[ $s ]]
    do
        array+=( "${s%%"$DELIMITER"*}" );
        s=${s#*"$DELIMITER"};
    done;

    path=${array[0]}    # Path by id => NO SPACES >:(
    id=$(basename $path)
    artist=${array[1]}
    song=${array[2]}

    mv "$song_dir" $path
    echo "artist: $artist" >> $path/info
    echo "song: $song" >> $path/info
done
