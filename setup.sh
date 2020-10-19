#!/bin/bash
# sudo apt-get update
# sudo apt-get install -qq bc tree sox automake autoconf sox libtool subversion sctk libatlas-base-dev gfortran
# pip3 install gdown

WHOAMI=$(whoami)
WHICH_PYTHON_ENV="venv"   # venv or sys (might want to use sys for online notebook

# Install Kaldi
KALDI_ROOT=$(pwd)/kaldi
if false
then
    echo "building kaldi"
    rm -rf kaldi
    git clone https://github.com/kaldi-asr/kaldi $KALDI_ROOT
    pushd kaldi/tools
    make -j$(nproc)
    chmod +x extras/*.sh
    ./extras/install_openblas.sh
    ./extras/install_mkl.sh
    popd
    pushd kaldi/src
    ./configure --use-cuda=no
    make -j$(nproc) clean depend
    make -j$(nproc)
    popd
fi


# Install ESPNet
ESPNET_ROOT=$(pwd)/espnet
if false 
then
    # rm -rf espnet
    # git clone -b v.0.9.4 https://github.com/espnet/espnet $ESPNET_ROOT
    pushd espnet/tools
    ln -s $KALDI_ROOT .
    . ./setup_cuda_env.sh /usr/local/cuda/
    if [ "$WHICH_PYTHON_ENV" == "venv" ]
    then
        ./setup_venv.sh $(command -v python3)
        ./venv/bin/pip install ipykernel
        ipython kernel install --user --name=espnet-venv
    elif [ "$WHICH_PYTHON_ENV" == "sys" ]
    then
        ./setup_python.sh $(command -v python3)
    fi
    make clean
    make TH_VERSION=1.5
    . ./activate_python.sh; python3 check_install.py
    popd
    if [ "$WHICH_PYTHON_ENV" == "venv" ]
    then
        echo "Set up a Notebook kernel by running:"
        echo "ipython kernel install --user --name=<kernel-name>"
        echo "Then update the kernel to use python3 in espnet/tools/venv/bin/python"
    fi
fi
