#!/usr/bin/env bash

#set -x

# 20/80 split
wav_dir=$1

ls $wav_dir/*.wav | sort -R > randomized_list.txt

n_tot=$(ls $wav_dir/*.wav | wc -l)
n_test=$(echo "$n_tot * 20 / 100" | bc )
n_train=$(( $n_tot - $n_test ))

mkdir -p $wav_dir/test
mkdir -p $wav_dir/train

tail -n $n_train randomized_list.txt | xargs -I {} bash -c "cp {} $wav_dir/train"
tail -n $n_train randomized_list.txt | xargs -I {} basename {} .wav | \
    xargs -I{} cp $wav_dir/{}.ref.txt $wav_dir/train

head -n $n_test randomized_list.txt | xargs -I {} bash -c "cp {} $wav_dir/test; "
head -n $n_test randomized_list.txt | xargs -I {} basename {} .wav | \
    xargs -I{} cp $wav_dir/{}.ref.txt $wav_dir/test





