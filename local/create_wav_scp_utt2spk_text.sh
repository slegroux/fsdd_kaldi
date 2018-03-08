#!/usr/bin/env bash
export LC_ALL=C


data_dir=${1:-$DATA/free-spoken-digit-dataset/recordings}
test_dir=$data_dir/test
train_dir=$data_dir/train

if [ ! -d ../data/test ];then
    mkdir -p ../data/test
fi

if [ ! -d ../data/train ];then
    mkdir -p ../data/train
fi

#### create wav.scp
rm ../data/train/wav.scp; touch ../data/train/wav.scp
rm ../data/test/wav.scp; touch ../data/test/wav.scp
    
for file in $test_dir/*.wav; do
    echo $(cat $test_dir/$(basename $file .wav).ref.txt | cut -d' ' -f1) $file >> ../data/test/wav.scp
done    

for file in $train_dir/*.wav; do
    echo $(cat $train_dir/$(basename $file .wav).ref.txt | cut -d' ' -f1) $file >> ../data/train/wav.scp
done

#### create utt2spk
# needs bash 4
declare -A spk2utt
# rm ../data/test/spk2utt
rm ../data/test/utt2spk

for file in $test_dir/*ref.txt; do
    name=$(cat $file | cut -d'_' -f1)
    id=$(cat $file | cut -d' ' -f1 | cut -d '_' -f2-)
    spk2utt["$name"]+=" $id"
done

# iterate through keys
for name in ${!spk2utt[@]}; do
    # echo $name ${spk2utt[$name]} >> ../data/test/spk2utt 
    for utt in ${spk2utt[$name]}; do
	echo ${name}_$utt $name >> ../data/test/utt2spk
    done
done
sort ../data/test/utt2spk > tmp; mv tmp ../data/test/utt2spk

# rm ../data/train/spk2utt
rm ../data/train/utt2spk
declare -A spk2utt_train

for file in $train_dir/*ref.txt; do
    name=$(cat $file | cut -d'_' -f1)
    id=$(cat $file | cut -d' ' -f1 | cut -d '_' -f2-)
    spk2utt_train["$name"]+=" $id"
done

# iterate through keys
for name in ${!spk2utt_train[@]}; do
    # echo $name ${spk2utt_train[$name]} >> ../data/train/spk2utt
    for utt in ${spk2utt_train[$name]}; do
	echo ${name}_$utt $name >> ../data/train/utt2spk
    done
done
sort ../data/train/utt2spk > tmp; mv tmp ../data/train/utt2spk

#### create transcripts
rm ../data/test/text
rm ../data/train/text

for file in $test_dir/*.ref.txt;do
    cat $file >> ../data/test/text
done
sort ../data/test/text > tmp; mv tmp ../data/test/text

for file in $train_dir/*.ref.txt;do
    cat $file >> ../data/train/text
done
sort ../data/train/text > tmp; mv tmp ../data/train/text
