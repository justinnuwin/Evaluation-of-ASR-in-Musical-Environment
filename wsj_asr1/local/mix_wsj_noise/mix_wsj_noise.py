"""
Mix speech following the Kaldi file structures with noise at various levels.

usage: mix_wsj_noise.py [-h] [--mix-snr snr] [--speech-level db]
                        [--noise-level db] [--mix-level db]
                        [--noise-timestamp time] [--noiseROI filepath]
                        [--sph2pipe path/to/sph2pipe] [--job]
                        [--dry-run] [--noise-ext]dataPath noiseFile

Note mp3 codec is normally not installed by default:
$ sudo apt-get install libsox-fmt-mp3
SIGGEP dataset ROI begins at 15 seconds for everything
"""
import os
import sys
import argparse
from math import log10
import subprocess
from random import randint


BITDEPTH=16
ENCODING='signed-integer'


def build_parser():

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
    parser.add_argument('noiseFile', type=str,
            help='Path to the noise file or directory containing several noise files. \
                    If a file is given, all utterances will be mixed with the specified \
                    file. If a directory is given, the utterances will be mixed with a \
                    randomly selected noise source in this directory following a uniform \
                    distribution. When using a directory, to search for noise sources, the \
                    `--noise-ext` argument MUST be provided. A file will be generated mapping \
                    the utterance ID to the noise source. If `--noise-timestamp` is not given, \
                    or there is no ROI mapping file, or the specified file is not in the \
                    ROI map, then start mixing from beginning.')
    parser.add_argument('--noise-ext', type=str, metavar='ext',
            help='Used only when noiseFile is a directory. This is used to search for noise files \
                    of a specified extension in the noiseFile directory in case there are other \
                    files in that folder.')
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
    parser.add_argument('--mix-level', type=float, metavar='db',
            help='The level of the mix. Output level will match speech signal\
                    by default. This option does not support relative levels.')
    parser.add_argument('--noise-timestamp', type=float, metavar='time',
            help='The start timestamp to trim the noise source from to match \
                    the utterance length. This will override --noiseROI. The \
                    timestamp is in seconds from the start of the noise file.')
    parser.add_argument('--noiseROI', type=file_path, metavar='filepath',
            help='Path to the noise.roi file. This file contains the mapping from \
                    noise filename (unique) to a list of regions of interest (start\
                    /end times). This is superceded by --noise-timestamp. \
                    (ROI is region of interest)')
    parser.add_argument('--sph2pipe', type=file_path, metavar='path/to/sph2pipe',
            help='Path to sph2pipe if it is not on the path. This is needed to \
                    get the mix level of the final mix if --mix-level is not \
                    specified.')
    parser.add_argument('--job', type=int, metavar='xx',
            help='When --mix-level is not specified, output mix will be set at \
                    level of speech; this may take a while since `sox stats` must \
                    be called on every file in the dataset to get its level. \
                    This option will read a split wav.scp file following the \
                    GNU numeric split format:\n\
                    `$ split --numeric-suffixes -n l/njobs wav.scp wav.scp.`\n\
                    which outputs split files like: wav.scp.xx where xx is the \
                    split number. The suffix length is 2. Output will written \
                    to the matching augmented_wav.scp.xx')
    parser.add_argument('--dry-run', action='store_true',
            help='Perform a dry run. Write augmented wav.scp file to stdout rather\
                    than dataPath/augmented_wav.scp')
    return parser


def parse_level_str(s):
    if s[0] == '~':
        relative = True
        level = float(s[1:])
    else:
        relative = False
        level = float(s)
    return level, relative


# TODO: Make nchannels and srate dependent on the actual speech properties
def match_noise_properties_to_speech(noiseFile_path, noise_level_str=None, target_nchannels=1, target_srate=16000,
        target_bitdepth=BITDEPTH, target_encoding=ENCODING):
    if noise_level_str is not None:
        noise_level, relative = parse_level_str(noise_level_str)
        matched_filename = 'lv{}-{}.wav'.format(noise_level_str, os.path.splitext(os.path.basename(noiseFile_path))[0])
        matched_path = os.path.join(os.path.dirname(noiseFile_path), matched_filename)

        if relative:
            gain_effect = 'gain {}'.format(noise_level)
        else:
            gain_effect = 'gain -n {}'.format(noise_level)     # Normalizes peak to noise_level dB FSD (Full Scale Deflection)
    else:
        matched_filename = '{}.wav'.format(os.path.splitext(os.path.basename(noiseFile_path))[0])
        matched_path = os.path.join(os.path.dirname(noiseFile_path), matched_filename)
        gain_effect = 'gain -n'     # Normalize to 0db for 1:1 mixing.

    command = 'sox -V2 {infile} --type wav --channels={nchannels} --rate={srate} --bits {bits} --encoding {encoding} {outfile} {effect}'.format(
        infile=noiseFile_path, nchannels=target_nchannels, srate=target_srate, bits=target_bitdepth, encoding=target_encoding,
        outfile=matched_path, effect=gain_effect)
    return_code = subprocess.call(command, shell=True)
    if return_code != 0:
        raise Exception('code {} raised by: {}'.format(return_code, command))

    return matched_path


def get_peak_level(scp_cmd):
    # For some reason, sox outputs stats on stderr
    cmd = 'sox "|{}" --null stats'.format(scp_cmd)
    res = subprocess.run(cmd, shell=True, stderr=subprocess.PIPE)
    output = res.stderr.decode('utf-8')
    if res.returncode == 2 and 'sph2pipe' in output and 'not found' in output.lower():
        raise FileNotFoundError('sph2pipe not found. It is needed to get the desired mix leve since it was not ' \
                'provided. It is highly possible sph2pipe is not on the PATH. You can manually point to it by giving '\
                'the following flag:\n' \
                '\t\t--sph2pipe /path/possibly/kaldi/tools/sph2pipe\n\n' \
                'Original Error:\n{}'.format(output))
    elif res.returncode != 0:
        raise Exception('Error getting peak level from utterance since desired mix level was not specified.\n' \
                '\ncmd:\n{}\n\nerror:\n{}'.format(cmd, output))
    utterance_stats = output.strip().split('\n')
    for stat in utterance_stats:
        if 'Pk lev dB' in stat:
            return float(stat.replace('Pk lev dB', '').strip())
    raise KeyError('Did not get Pk lev dB from sox stats on utterance\n{}'.format(res))


def prepare_sources(noiseFile_path, mix_snr, speech_level_str, noise_level_str):
    if mix_snr is not None:
        speech_level_str = None
        noise_level_str = None
        try:
            mix_snr = float(mix_snr)
        except ValueError:
            signal_power, noise_power = mix_snr.split(':')
            mix_snr = 10 * log10(signal_power / noise_power)
        # Speech is normalize in this branch so attenuate "normalized" noise to get the desired SNR
        noiseWAV_path = match_noise_properties_to_speech(noiseFile_path, str(-1 * mix_snr))
    else:
        noiseWAV_path = match_noise_properties_to_speech(noiseFile_path, noise_level_str)

    """ This hasn't been tested yet
    command = 'soxi -D {}'.format(=noiseWAV_path)
    return_code = subprocess.run(command, shell=True)
    output = res.stdout.decode('utf-8')
    try:
        noise_length = float(output.strip())
    except Exception:
        raise ValueError('Could not get length of noise-source')
    """
    noise_length = None

    if speech_level_str is not None:
        speech_level, relative = parse_level_str(speech_level_str)
        if relative:
            speech_gain_effect = 'gain {}'.format(speech_level)
        else:
            speech_gain_effect = 'gain -n {}'.format(speech_level)
    else:
        speech_gain_effect = 'gain -n'

    return noiseWAV_path, speech_gain_effect, noise_length


def main(wavscp_path, utt2dur_path, noiseFile_path, noise_ext=None, mix_snr=None, speech_level_str=None, noise_level_str=None,
        mix_level=None, noise_timestamp=None, noiseROI_path=None, dry_run=False, sph2pipe=None):

    noiseWAV_path = []
    if noise_ext is not None:   # Directory mode
        noise_mode = 'directory'
        for song in sorted(os.listdir(noiseFile_path)):
            for filename in sorted(os.listdir(os.path.join(noiseFile_path, song))):
                if filename.endswith(noise_ext):
                    _noiseWAV_path, speech_gain_effect, noise_length = prepare_sources(os.path.join(noiseFile_path, song, filename),
                            mix_snr, speech_level_str, noise_level_str)
                    noiseWAV_path.append(_noiseWAV_path)
    else:
        noise_mode = 'file'
        _noiseWAV_path, speech_gain_effect, noise_length = prepare_sources(noiseFile_path, mix_snr, speech_level_str, noise_level_str)
        noiseWAV_path.append(_noiseWAV_path)

    if noiseROI_path is not None:
        raise NotImplementedError('noise.roi file has not been implemented yet!')   # TODO
    if noise_timestamp is None:
        noise_timestamp = 0

    wavscp_f = open(wavscp_path, 'r')
    utt2dur_f = open(utt2dur_path, 'r')
    if noise_mode == 'directory':
        noise_utt_map_path = os.path.join(os.path.dirname(wavscp_path), 'noise_utt_map')
        noise_utt_map_f = open(noise_utt_map_path, 'w')
        noise_utt_map_f.write(str(noiseWAV_path) + '\n')

    if not dry_run:
        new_wavscp_path = os.path.join(os.path.dirname(wavscp_path), 'augmented_{}'.format(
            os.path.basename(wavscp_path)))
        new_wavscp_f = open(new_wavscp_path, 'w')
    else:
        new_wavscp_f = sys.stdout

    for i, wavscp_line in enumerate(wavscp_f):
        utt2dur_line = next(utt2dur_f).strip()
        utt_id, duration = utt2dur_line.split()

        wavscp_line = wavscp_line.strip()
        scp_cmd = ' '.join(wavscp_line.split(' ')[1:-1])    # Remove utterance id and ending pipe symbol
        if sph2pipe is not None:
            scp_cmd = os.path.join(os.path.dirname(sph2pipe), scp_cmd)

        if mix_level is None:
            this_mix_level = get_peak_level(scp_cmd)
        else:
            this_mix_level = mix_level

        if noise_mode == 'file':
            noise_idx = 0
        elif noise_mode == 'directory':
            noise_idx = randint(0, len(noiseWAV_path) - 1)
            noise_utt_map_f.write('{uttID}\t{noiseIdx}\n'.format(uttID=utt_id, noiseIdx=noise_idx))

        # Mix both inputs at 1/n balance factor
        # -p is --sox-pipe, for some reason it won't take that version of the argument
        augmented_command = 'sox -t wav - -p {speechEffect} | ' \
                            'sox --combine mix -p "|sox {noisePath} -p trim {start} {duration}" ' \
                            '-t wav -b {bit} -e {enc} - gain -n {mixLevel} |'.format(
                speechEffect=speech_gain_effect, noisePath=noiseWAV_path[noise_idx], start=noise_timestamp,
                duration=duration, bit=BITDEPTH, enc=ENCODING, mixLevel=this_mix_level)

        augmented_wavscp_line = '{} {}\n'.format(wavscp_line, augmented_command)
        new_wavscp_f.write(augmented_wavscp_line)
        
    new_wavscp_f.close()
    wavscp_f.close()
    utt2dur_f.close()
    if noise_mode == 'directory':
        noise_utt_map_f.close()


if __name__ == '__main__':
    parser = build_parser()
    args = parser.parse_args()
    
    if args.job is not None:
        wavscp_path = os.path.join(args.dataPath, 'wav.scp.{:02d}'.format(args.job))
    else:
        wavscp_path = os.path.join(args.dataPath, 'wav.scp')
    utt2dur_path = os.path.join(args.dataPath, 'utt2dur')
    if not os.path.isfile(wavscp_path):
        raise FileNotFoundError('Could not find wav.scp in {}'.format(args.dataPath))
    if not os.path.isfile(utt2dur_path):
        raise FileNotFoundError('Could not find utt2dur in {}'.format(args.dataPath))
    
    if os.path.isdir(args.noiseFile):
        if args.noise_ext is None:
            raise ValueError('When noiseFile is a directory, the `--noise-ext` argument must be provided')
        else:
            if args.noise_ext[0] == '.':
                noise_ext = args.noise_ext[1:]
            else:
                noise_ext = args.noise_ext
            for song in os.listdir(args.noiseFile):
                has_audio = False
                for filename in os.listdir(os.path.join(args.noiseFile, song)):
                    if filename.endswith(noise_ext):
                        has_audio = True
                        break
                if not has_audio:
                    raise FileNotFoundError('No files with the {} extension were found in the noiseFile folder'.format(
                        noise_ext))
    elif os.path.isfile(args.noiseFile):
        noise_ext = None
    else:
        raise TypeError('Given noisePath was not a file nor a directory: {}'.format(args.noiseFile))

    main(wavscp_path, utt2dur_path, args.noiseFile, noise_ext=noise_ext, mix_snr=args.mix_snr,
            speech_level_str=args.speech_level, noise_level_str=args.noise_level,
            mix_level=args.mix_level, noise_timestamp=args.noise_timestamp,
            noiseROI_path=args.noiseROI, dry_run=args.dry_run, sph2pipe=args.sph2pipe)

