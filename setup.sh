#!/bin/bash
sudo apt-get update
sudo apt-get install -qq bc tree sox automake autoconf sox libtool subversion sctk libatlas-base-dev gfortran
pip3 install gdown

WHICH_PYTHON_ENV="anaconda"         # anaconda, venv or sys
CUDA_HOME=/usr/local/cuda-10.2      # Must be >=Cuda-10.1 <Cuda-11.0
BUILD_FRESH=true     # Deletes the existing repo, clones a fresh repo and builds from that
BUILD_KALDI=true
BUILD_ESPNET=true
SETUP_PROJECT=true

# Install Kaldi
KALDI_ROOT=$(pwd)/kaldi
if $BUILD_KALDI
then
    echo "building kaldi"
    if $BUILD_FRESH || [ ! -d $KALDI_ROOT ]
    then
        rm -rf kaldi
        git clone https://github.com/kaldi-asr/kaldi $KALDI_ROOT
    fi
    pushd kaldi/tools
    make -j$(nproc)
    chmod +x extras/*.sh
    ./extras/install_openblas.sh
    sudo ./extras/install_mkl.sh
    # Sometimes the configure command fails in kaldi/src b/c make doesn't symlink openfst
    if [ ! -e openfst ]
    then
        openfstdir=$(find . -maxdepth 1 | grep --color=never -E "openfst-.+[0-9]$")
        ln -s $openfstdir openfst
    fi
    popd
    pushd kaldi/src
    ./configure --use-cuda=no    # ESPNet only uses Kaldi feature extraction which is CPU bound
    # $ ./configure --openblas-root=../tools/OpenBLAS/install --cudatk-dir=$CUDA_HOME    # If you want to build Kaldai with CUDA and BLAS
    make -j$(nproc) clean depend
    make -j$(nproc)
    popd
fi


# Install ESPNet
ESPNET_ROOT=$(pwd)/espnet
if $BUILD_ESPNET
then
    if $BUILD_FRESH || [ ! -d $ESPNET_ROOT ]
    then
        rm -rf espnet
        git clone -b v.0.9.4 https://github.com/espnet/espnet $ESPNET_ROOT
    fi
    pushd espnet/tools
    ln -s $KALDI_ROOT .
    if [ ! -f $CUDA_HOME/lib64/libcublas.so ]
    then
        sudo ln -s /usr/lib/x86_64-linux-gnu/libcublas.so.10 $CUDA_HOME/lib64/libcublas.so
    fi
    . ./setup_cuda_env.sh $CUDA_HOME
    if [ "$WHICH_PYTHON_ENV" == "venv" ]
    then
        ./setup_venv.sh $(command -v python3)
        ./venv/bin/pip install ipykernel
    elif [ "$WHICH_PYTHON_ENV" == "anaconda" ]
    then
        CONDA_ENV_NAME="espnet"
        if $BUILD_FRESH
        then
            conda env remove --name=$CONDA_ENV_NAME
        fi
        CONDA_TOOLS_DIR=$(dirname ${CONDA_EXE})/..
        ./setup_anaconda.sh ${CONDA_TOOLS_DIR} $CONDA_ENV_NAME 3
        conda install -y ipykernel --name=$CONDA_ENV_NAME
    elif [ "$WHICH_PYTHON_ENV" == "sys" ]
    then
        ./setup_python.sh $(command -v python3)
    fi
    make clean
    make TH_VERSION=1.5
    . ./activate_python.sh; python3 check_install.py
    popd
    if [ "$WHICH_PYTHON_ENV" == "venv" ] || [ "$WHICH_PYTHON_ENV" == "anaconda" ]
    then
        ipython kernel install --user --name=espnet-venv
        echo "Set up a Notebook kernel by running:"
        echo "ipython kernel install --user --name=<kernel-name>"
        echo "Then update the kernel to use python3 in espnet/tools/venv/bin/python if using venv"
        echo "Or ~/anaconda3/envs/espnet/bin/pyton if using anaconda"
    fi
fi

ESPNET_WSJ=$ESPNET_ROOT/egs/wsj/asr1
MODEL="pretrained-transformer-model"
MODEL_PATH=$(pwd)/$MODEL

if $SETUP_PROJECT
then
    # Project Specific Setup
    rm -rf $ESPNET_WSJ/conf $ESPNET_WSJ/run.sh
    ln -s $(pwd)/wsj_asr1/conf $ESPNET_WSJ
    ln -s $(pwd)/wsj_asr1/run.sh $ESPNET_WSJ

    # Pretrained Models
    if [ $MODEL == "pretrained-transformer-model" ]
    then
        if [ ! -d $MODEL_PATH ]
        then
            $ESPNET_ROOT/utils/download_from_google_drive.sh "https://drive.google.com/open?id=1Az-4H25uwnEFa4lENc-EKiPaWXaijcJp" $MODEL_PATH tar.gz
        fi
        mkdir -p $ESPNET_WSJ/data/train_si284
        ln -s $MODEL_PATH/data/lang_1char $ESPNET_WSJ/data
        ln -s $MODEL_PATH/data/train_si284/cmvn.ark $ESPNET_WSJ/data/train_si284
        mkdir -p $ESPNET_WSJ/exp
        ln -s $MODEL_PATH/exp/train_rnnlm_pytorch_lm_word65000 $ESPNET_WSJ/exp
        ln -s $MODEL_PATH/exp/train_si284_pytorch_train_no_preprocess $ESPNET_WSJ/exp
    elif [ $MODEL == "pretrained-rnn-model" ]
    then
        if [ ! -d $MODEL_PATH ]
        then
            $ESPNET_ROOT/utils/download_from_google_drive.sh "https://drive.google.com/u/0/uc?id=1Az-4H25uwnEFa4lENc-EKiPaWXaijcJp&export=download" $MODEL_PATH tar.gz
        fi
        echo "Have not previously pulled or tested this yet. Setup is still required"
    elif [ $MODEL == "wsj_asr1" ]
    then
        echo "We have not trained this model to completion yet"
    fi
fi
