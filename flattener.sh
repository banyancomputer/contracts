#!/bin/bash

# This script takes a directory of .sol files and converts them to flattened .sol files.
# usage: ./flattener.sh

path=$(pwd)

get_contracts () {
    echo "*** Flattening contracts of '$1' folder ***"
    cd $path/$1
    mkdir -p $path/$1/flattened
    for f in *.sol; do
        echo "Flattening $f"
        npx hardhat flatten $f > $path/$1/flattened/$f
        sed -i '/SPDX-License-Identifier/d' $path/$1/flattened/$f
        sed -i "1i\ //\ SPDX-License-Identifier:\ MIT" $path/$1/flattened/$f
        echo "$f flattened"
    done
    cd $path
}

# edit this to add or remove folders
get_contracts "contracts"
