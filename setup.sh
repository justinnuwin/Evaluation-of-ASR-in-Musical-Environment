#!/bin/bash
sudo apt-get update
sudo apt-get install -qq bc tree sox automake autoconf sox libtool subversion sctk libatlas-base-dev gfortran
pip3 install gdown

WHICH_PYTHON_ENV="anaconda"         # anaconda, venv or sys
CUDA_HOME=/usr/local/cuda-10.2      # Must be >=Cuda-10.1 <Cuda-11.0
BUILD_FRESH=false     # Deletes the existing repo, clones a fresh repo and builds from that
BUILD_KALDI=true
BUILD_ESPNET=true

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
    elif [ "$WHICH_PYTHON_ENV" == "anaconda" ]
    then
        CONDA_TOOLS_DIR=$(dirname ${CONDA_EXE})/..
        ./setup_anaconda.sh ${CONDA_TOOLS_DIR} venv 3
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
        ./venv/bin/pip install ipykernel
        ipython kernel install --user --name=espnet-venv
        echo "Set up a Notebook kernel by running:"
        echo "ipython kernel install --user --name=<kernel-name>"
        echo "Then update the kernel to use python3 in espnet/tools/venv/bin/python"
    fi
fi
