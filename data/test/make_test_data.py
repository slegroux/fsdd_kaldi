#!/usr/bin/env python 

import pdb
import os, re
DATA_PATH = "/Users/voicera/Data/free-spoken-digit-dataset/recordings"
files = os.listdir(DATA_PATH)
# 50 utterances for each digit. we take the first 10 for testing (20%)
expression = r"_[0-9].wav"
name = r"_(.*)_"
digit = r"(\d)_"

dic = {0:"zero", 1:"one", 2:"two", 3:"three", 4:"four", 5:"five", 6:"six", 7:"seven", 8:"eight", 9:"nine"}

wav_scd = open('wav.scp', "w")
spk2utt = open('spk2utt', "w")
utt2spk = open('utt2spk', "w")
text = open('text', "w")

for f in files:
	if re.search(expression, f):
		# file
		print f
		# speaker id
		speakerid = re.search(name, f).group(1)
		# utterance ID
		utteranceid = speakerid + "_" + f[:-4]
		print utteranceid
		# file absolute path
		absolute_path = DATA_PATH + '/' + f
		print absolute_path

		# digit
		d = re.search(digit, f).group(1)
		print d

		# wav.scd
		print utteranceid + " " + absolute_path
		# if 'nicolas' in utteranceid:
		# 	absolute_path = 'sox  -b 16 {} -t wav - |'.format(absolute_path)
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






