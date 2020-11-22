rm -f data/*wav.scp.* data/augmented_wav.scp
find noise | grep --color=never -E "lv.+wav$" | xargs -I {} rm -f 
