#!/usr/bin/env bash

data_dir=$DATA/free-spoken-digit-dataset/recordings

# check and convert audio format 
./convert_pcm.sh $data_dir

# create formatted transcript for each utterance
./format_trn.sh $data_dir

# create train/test split
./train_test_split.sh $data_dir
