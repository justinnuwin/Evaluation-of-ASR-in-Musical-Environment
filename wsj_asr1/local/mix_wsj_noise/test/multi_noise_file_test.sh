NJOB=1      # Set to 1 for now, for some reason the split cmds below are not consistent btwn the two files
CLEAN=false

python3 ../mix_wsj_noise.py --help

split --numeric-suffixes -n l/$NJOB data/wav.scp data/wav.scp.
split --numeric-suffixes -n l/$NJOB data/utt2dur data/utt2dur.

for i in $(seq 0 `expr $NJOB - 1`)
do
    python3 ../mix_wsj_noise.py data noise \
        --noise-ext mp3 \
        --sph2pipe ../../../../kaldi/tools/sph2pipe_v2.5/sph2pipe \
        --mix-level 0 \
        --mix-snr 3 \
        --noise-timestamp 23.4 \
        --job $i &
done
wait

for filename in $(ls data/augmented_wav.scp.* | sort -g)
do
    cat $filename >> data/augmented_wav.scp
done

for filename in $(ls data/noise_utt_map.* | sort -g)
do
    cat $filename >> data/noise_utt_map
done


if $CLEAN
then
    rm -f data/*wav.scp.* data/utt2dur.* data/noise_utt_map.*
fi

