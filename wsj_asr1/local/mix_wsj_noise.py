"""
echo "$0 $@"
. utils/parse_options.sh || exit 1;
. ./path.sh || exit 1;

for x in test_eval92 test_eval93 
"""

# Note mp3 codec is not installed by default:
# $ sudo apt-get install libsox-fmt-mp3


import os
import sys
import argparse
from math import log10
import subprocess

def dir_path(string):
    if os.path.isdir(string):
        return string
    else:
        raise NotADirectoryError(string)


def file_path(string):
    if os.path.isfile(string):
        return string
    else:
        raise NotADirectoryError(string)


parser = argparse.ArgumentParser(description='Mix speech following the Kaldi \
        file structures with noise at various levels.')
parser.add_argument('dataPath', type=dir_path,
        help='Path to the dataset in the data directory (i.e. data/train_si284). \
                Required files in this directory is wav.scp and utt2dur.')
parser.add_argument('noiseWAV', type=file_path,
        help='Path to the noise file. If there is no ROI mapping file or the \
                specified file is not in the ROI map, then a random slice will \
                be taken.',)
parser.add_argument('--mix-snr', type=str, metavar='snr',
        help='Mix speech and noise at the specified SNR. snr can be given as db \
                or a ratio. i.e. "2:1" would mix the speech signal at 2x the \
                power of the noise. Default to mix at 1:1 (0dB). This overrides \
                all other level modifications.')
parser.add_argument('--speech-level', type=str, metavar='db',
        help='Adjust the speech mixing level. db can be a numeric value to \
                specify absolute level to adjust the speech to or ~ can be \
                prepended to the level to specify a relative change in level. \
                This is superceded by --mix-snr.')
parser.add_argument('--noise-level', type=str, metavar='db',
        help='Same as --speech-level, but adjusts the level that the noise \
                is mixed at. The noise level will be normalized to 0dB by \
                default to accomadate the default 1:1 mix snr. This is also \
                superceded by --mix-snr.')
parser.add_argument('--mix_level', type=float, metavar='db',
        help='The level of the mix. Output level will match speech signal\
                by default.')
parser.add_argument('--noiseROI', type=file_path, metavar='filepath',
        help='Path to the noise.roi file. This file contains the mapping from \
                noise filename (unique) to a list of regions of interest (start\
                /end times). (ROI is region of interest)')


"""
SIGGEP dataset ROI begins at 15 seconds for everything
"""


def parse_level_str(s):
    if s[0] == '~':
        relative = True
        level = float(s[1:])
    else:
        relative = False
        level = float(s)
    return level, relative


def match_noise_properties(noiseWAV_path, noise_level_str=None, target_nchannels=1, target_srate=16000):
    if noise_level_str is not None:
        noise_level, relative = parse_level_str(noise_level_str)
        matched_filename = 'lv{}-{}.wav'.format(noise_level_str, os.path.splitext(os.path.basename(noiseWAV_path))[0])
        matched_path = os.path.join(os.path.dirname(noiseWAV_path), matched_filename)

        if relative:
            gain_effect = 'gain {}'.format(noise_level)
        else:
            gain_effect = 'gain -n {}'.format(noise_level)     # Normalizes peak to noise_level dB FSD (Full Scale Deflection)
    else:
        matched_filename = '{}.wav'.format(os.path.splitext(os.path.basename(noiseWAV_path))[0])
        matched_path = os.path.join(os.path.dirname(noiseWAV_path), matched_filename)
        gain_effect = 'gain -n'     # Normalize to 0db for 1:1 mixing.

    command = 'sox -V2 {infile} --type wav --channels={nchannels} --rate={srate} {outfile} {effect}'.format(
        infile=noiseWAV_path, nchannels=target_nchannels, srate=target_srate, outfile=matched_path, effect=gain_effect)
    return_code = subprocess.call(command, shell=True)
    if return_code != 0:
        raise Exception('code {} raised by: {}'.format(return_code, command))

    return matched_path


def get_pk_level(scp_cmd):
    res = subprocess.run('sox "|{}" --null stats'.format(scp_cmd), shell=True, stderr=subprocess.PIPE)   # For some reason, sox outputs stats on stderr
    utterance_stats = res.stderr.decode('utf-8').strip().split('\n')
    for stat in utterance_stats:
        if 'Pk lev dB' in stat:
            return float(stat.replace('Pk lev dB', '').strip())


def main(wavscp_path, utt2dur_path, noiseWAV_path, mix_snr=None, speech_level_str=None, noise_level_str=None, mix_level=None, noiseROI_path=None):
    noiseWAV_path = match_noise_properties(noiseWAV_path, noise_level_str)

    if speech_level_str is not None:
        speech_level, relative = parse_level_str(speech_level_str)
        if relative:
            gain_effect = 'gain {}'.format(speech_level)
        else:
            gain_effect = 'gain -n {}'.format(speech_level)
    else:
        gain_effect = 'gain -n'

    if mix_snr is not None:
        try:
            mix_snr = float(mix_snr)
        except ValueError:
            signal_power, noise_power = mix_snr.split(':')
            mix_snr = 10 * log10(signal_power / noise_power)
    else:
        mix_snr = 0.


    wavscp_f = open(wavscp_path, 'r')
    utt2dur_f = open(utt2dur_path, 'r')

    for i, wavscp_line in enumerate(wavscp_f):
        utt2dur_line = next(utt2dur_f).strip()
        wavscp_line = wavscp_line.strip()
        scp_cmd = ' '.join(wavscp_line.split(' ')[1:-1])    # Remove utterance id and ending pipe symbol
        scp_cmd = '/mnt/Projects/18-781/18-781_Semester_Project/kaldi/tools/sph2pipe_v2.5/' + scp_cmd
        if mix_level is None:
            mix_level = get_pk_level(scp_cmd)

        # Mix both inputs at 1/n balance factor
        augmented_command = 'sox - --sox-pipe {speechEffect} | sox --combine mix --sox-pipe {noisePath} - gain -n {mixLevel} |'.format(
            speechEffect=gain_effect, noisePath=noiseWAV_path, mixLevel=mix_level)

        augmented_wavscp_line = '{} {}\n'.format(wavscp_line, augmented_command)
        print(augmented_wavscp_line)
        
    wavscp_f.close()
    utt2dur_f.close()
    


if __name__ == '__main__':
    args = parser.parse_args()
    print(args)
    
    wavscp_path = os.path.join(args.dataPath, 'wav.scp')
    utt2dur_path = os.path.join(args.dataPath, 'utt2dur')
    if not os.path.isfile(wavscp_path):
        raise FileNotFoundError('Could not find wav.scp in {}'.format(args.dataPath))
    if not os.path.isfile(utt2dur_path):
        raise FileNotFoundError('Could not find utt2dur in {}'.format(args.dataPath))

    main(wavscp_path, utt2dur_path, args.noiseWAV, mix_snr=args.mix_snr,
            speech_level_str=args.speech_level, noise_level_str=args.noise_level,
            mix_level=args.mix_level, noiseROI_path=args.noiseROI)

