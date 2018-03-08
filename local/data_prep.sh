#!/usr/bin/env bash

data_dir=$DATA/free-spoken-digit-dataset/recordings

echo "==== check and convert audio format "
#./convert_pcm.sh $data_dir || exit 1

echo "==== create formatted transcript for each utterance"
#./format_trn.sh $data_dir || exit 1

echo "==== create train/test split"
rm -rf $data_dir/train $data_dir/test
mkdir -p $data_dir/train $data_dir/test
./train_test_split.sh $data_dir || exit 1

echo "==== generate wav.scp & utt2spk"
./create_wav_scp_utt2spk.sh $data_dir || exit 1
