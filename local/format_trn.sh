#!/usr/bin/env bash

wav_folder=$1

declare -a dict
dict[0]=zero
dict[1]=one
dict[2]=two
dict[3]=three
dict[4]=four
dict[5]=five
dict[6]=six
dict[7]=seven
dict[8]=eight
dict[9]=nine

for file in $wav_folder/*.wav; do
    id=$(basename $file .wav)
    digit=$(echo $(basename $file) | cut -d'_' -f1)
    speaker=$(echo $(basename $file) | cut -d'_' -f2)
    echo ${speaker}_${id} ${dict[$digit]} > $wav_folder/$(basename $file .wav)".ref.txt"
done



