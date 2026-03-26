#!/bin/bash
#Script executes these command with some safeguards in place in case it fails:
#mkdir minikraken && cd minikraken
#wget -q https://ccb.jhu.edu/software/kraken/dl/minikraken_20171019_8GB.tgz
#tar -zxf minikraken_20171019_8GB.tgz --strip-components=1
#rm minikraken_20171019_8GB.tgz
#wget -O minikraken_100mers_distrib.txt -q https://ccb.jhu.edu/software/bracken/dl/minikraken_8GB_100mers_distrib.txt
#chmod +r minikraken_100mers_distrib.txt

ENV_NAME=$1

MINIKRAKEN_DB_LINK=https://genome-idx.s3.amazonaws.com/kraken/k2_standard_16_GB_20260226.tar.gz

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR # avoiding small edge case where bashrc sourcing changes your directory

function exit_function() {
  echo "to rerun use the command:"
  echo "bash -i $SCRIPT_DIR/custom_install.sh $ENV_NAME"
  exit 1
}

CONDA_BASE=$(conda info --base)
source $CONDA_BASE/etc/profile.d/conda.sh

#if ! (conda env list | grep "$ENV_NAME")
#then
#  echo "conda environment specified is not found"
#  exit_function
#else
#  conda activate $ENV_NAME
#fi

RESOURCES="$SCRIPT_DIR/resources"
if test -d "$RESOURCES/minikraken"
then
  echo "$RESOURCES/minikraken" already exists, if you want to overwrite, please remove old database folder
  echo "You can use:"
  echo "rm -rf $RESOURCES/minikraken"
  exit_function
fi
if test -d "$RESOURCES"
then
  cd $RESOURCES
  mkdir minikraken
  cd minikraken
  wget --version
  WGET_IS_AVAILABLE=$?
  if [ $WGET_IS_AVAILABLE -eq 0 ]
  then
    echo "#################Downloading minikraken db from $MINIKRAKEN_DB_LINK"
    if ! wget $MINIKRAKEN_DB_LINK
    then
      echo >&2 "wget command failed"
      exit_function
    else
      MINIKRAKEN_DB_FILE=$(find . -name "k2_standard_16_GB_*")
      echo "#################Extracting the minikraken db from archive"
      if ! tar -xzf $MINIKRAKEN_DB_FILE 
      then
        echo >&2 "tar command failed"
        exit_function
      else
        echo "kraken db successfully downloaded"
      fi
    fi
  else
    echo "wget is not installed"
    echo "you can try activating the conda env for this tool"
    exit_function
  fi
else
  echo "resources folder is expected in the script directory"
  exit_function
fi
