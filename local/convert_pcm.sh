#!/usr/bin/env bash

wav_folder=$1

for file in $wav_folder/*.wav; do
  echo $file
  encoding=$(soxi -e $file)
  bitrate=$(soxi -b $file)
  channels=$(soxi -c $file)
  if [ "$encoding" != "Signed Integer PCM" ] || [ "$channels" != 1 ] || [ "$bitrate" != 16 ]; then
      echo "converting current .wav: " $bitrate bit $encoding $channels channels $file
      sox $file -b 16 -c 1 -e 'signed-integer' tmp.wav
      cp $file $file~
      mv tmp.wav $file
  fi

done



