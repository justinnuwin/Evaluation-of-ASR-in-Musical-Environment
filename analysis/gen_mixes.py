"""
Note mp3 codec is normally not installed by default:
$ sudo apt-get install libsox-fmt-mp3
"""

import os
import sys
import re
import argparse
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
        raise FileNotFoundError(string)


parser = argparse.ArgumentParser(description='Generate the noise and utterance mixtures specified in the \
        data augmentation step (step 0.5 of run.sh).')
parser.add_argument('wavSCP', type=file_path, metavar='path',
        help='Path to the wav.scp.')
parser.add_argument('--sph2pipe', type=str, metavar='path',
        help='Path to the sph2pipe program if it is not on the system PATH. It is built by kaldi and can \
                usually be found at KALDI_ROOT/tools/sph2pipe_X.XX/sph2pipe. Either the path to the \
                executeable can be specified (program must be named sph2pipe) or a path to the \
                executable itself.')
parser.add_argument('--uttId', type=str, metavar='id',
        help='Generate only the mix for the speficied utterance Id.')
parser.add_argument('--output-dir', type=str, metavar='path',
        help='Where to place the generated mixes. If not specified, the mixes will be placed in a direcotry \
                called mixes in the same directory as the noise source that utterance was mixed with.')
parser.add_argument('--outputFmt', type=str, metavar='format', default='wav',
        help='The desired output format. Default is wave.')
parser.add_argument('--dry-run', action='store_true',
        help='Perform a dry run. Write the mix generaiton command to stdout.')


def get_unique_noise_source_name(path, utt_id):
    source_file = os.path.splitext(os.path.basename(path))[0]
    source_dir = os.path.basename(os.path.dirname(path))
    return '{}__{}__{}'.format(utt_id, source_dir, source_file)


def generate_mixes(wavSCP, sph2pipe_path=None, target_uttId=None, mix_fmt='wav', dry_run=False, output_dir=None,
                   output_name_fmt=get_unique_noise_source_name):
    with open(wavSCP, 'r') as f:
        for line in f:
            match = re.search('^([\w\d]+) (.+)?sph2pipe (.+)', line)
            uttId = match.group(1)
            sph2pipe_dirname = match.group(2)
            command_args = match.group(3)

            if target_uttId is not None and target_uttId != uttId:
                continue

            if sph2pipe_path is None:
                if sph2pipe_dirname is None:
                    command = ['sph2pipe']
                else:
                    command = [os.path.join(sph2pipe_dirname, 'sph2pipe')]
            else:
                command = [sph2pipe_path]

            command_args = command_args.split(' ')
            original_mix_filename = command_args[-16]
            output_name = '{}.{}'.format(output_name_fmt(original_mix_filename, uttId), mix_fmt)
            if output_dir is None:
                output_dir = os.path.dirname(original_mix_filename)
                output_dir = os.path.join(output_dir, 'mixes')
            output_path = os.path.join(output_dir, output_name)
            command_args = command_args[:-1]
            command_args[-4] = '-t'     # Replace '-' (sox output to stdout) with -t (sox output to file of type)
            command_args.insert(-3, mix_fmt)
            command_args.insert(-3, output_path)
            command += command_args

            if dry_run:
                print(' '.join(command))
            else:
                if not os.path.exists(output_dir):
                    os.mkdir(output_dir)
                subprocess.call(' '.join(command), shell=True)
            
            


if __name__ == '__main__':

    args = parser.parse_args()

    if args.sph2pipe is None:   # It must be on the PATH
        sph2pipe_path = None
    elif os.path.isdir(args.sph2pipe):
        sph2pipe_path = os.path.join(args.sph2pipe, 'sph2pipe')
    elif os.path.isfile(args.sph2pipe):
        sph2pipe_path = args.sph2pipe

    generate_mixes(args.wavSCP, sph2pipe_path, args.uttId, args.outputFmt, args.dry_run, args.output_dir)

