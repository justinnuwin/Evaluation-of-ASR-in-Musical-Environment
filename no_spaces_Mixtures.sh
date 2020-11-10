
for song_dir in $(pwd)/Mixtures/*
do

    str="$song_dir"
    delimiter=" - "
    s=$str$delimiter
    array=();
    while [[ $s ]]
    do
        array+=( "${s%%"$delimiter"*}" );
        s=${s#*"$delimiter"};
    done;

    path=${array[0]}    # Path by id => NO SPACES >:(
    id=$(basename $path)
    artist=${array[1]}
    song=${array[2]}

    mv "$song_dir" $path
    echo "artist: $artist" >> $path/info
    echo "song: $song" >> $path/info


done
