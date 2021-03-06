#!/usr/bin/env python 
import pdb
import os, re

# change global var DATA to point to your data directory if necessary
DATA_PATH = os.getenv('DATA') + "/free-spoken-digit-dataset/recordings"
files = os.listdir(DATA_PATH)
LOCAL_PATH = 'data'
print(LOCAL_PATH)

# 50 utterances for each digit. we take 10-29 (30 .wav out of)

expression = r"_[10-29].wav"
name = r"_(.*)_"
digit = r"(\d)_"

dic = {0:"zero", 1:"one", 2:"two", 3:"three", 4:"four", 5:"five", 6:"six", 7:"seven", 8:"eight", 9:"nine"}

wav_scd = open(LOCAL_PATH + '/train/wav.scp', "w")
spk2utt = open(LOCAL_PATH + '/train/spk2utt', "w")
utt2spk = open(LOCAL_PATH + '/train/utt2spk', "w")
text = open(LOCAL_PATH + '/train/text', "w")

for f in files:
    if re.search(expression, f):
        # file
        # print f
        # speaker id
        speakerid = re.search(name, f).group(1)
        # utterance ID
        utteranceid = speakerid + "_" + f[:-4]
        # print utteranceid
        # file absolute path
        absolute_path = DATA_PATH + '/' + f
        # print absolute_path

        # digit
        d = re.search(digit, f).group(1)
        # print d

        # wav.scd
        # print utteranceid + " " + absolute_path
        if 'nicolas' in utteranceid:
            absolute_path = 'sox  -b 16 -e signed-integer {} -t wav - |'.format(absolute_path)
        wav_scd.write(utteranceid + " " + absolute_path + "\n")

        # spk2utt
        spk2utt.write(speakerid + ' ' + utteranceid + "\n")
        utt2spk.write(utteranceid + ' ' + speakerid + "\n")

        # text
        text.write(utteranceid + " " + dic[int(d)] + "\n")


wav_scd.close()
spk2utt.close()
utt2spk.close()
text.close()
