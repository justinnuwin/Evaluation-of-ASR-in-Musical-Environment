rm -vf data/*wav.scp.* data/augmented_wav.scp
rm -vf data/utt2dur.*
rm -vf data/noise_utt_map.* data/noise_utt_map
find noise | grep --color=never -E "lv.+wav$" | xargs -I {} rm -vf 
