#!/usr/bin/env bash

#set -xeuo pipefail
#set -x
. path.sh || exit 1
. cmd.sh || exit 1

nprocs=3        # number of parallel jobs
nspkrs=3
lm_order=1     # language model order (n-gram quantity) - 1 is enough for digits grammar
stage=0
echo $train_cmd

# DATA
export WORK=data
export EXP=exp
mkdir -p data/train
mkdir -p data/test

# Safety mechanism (possible running this script with modified arguments)
. utils/parse_options.sh || exit 1
[[ $# -ge 1 ]] && { echo "Wrong arguments!"; exit 1; } 


if [ $stage -le 1 ]; then
    echo
    echo "===== PREPARING ACOUSTIC DATA ====="
    echo

    # Removing previously created data (from last run.sh execution)
    rm -rf exp mfcc data/train/* data/test/* data/local/lang data/lang data/local/tmp data/local/dict/lexiconp.txt

    # fsdd_wav=$DATA/free-spoken-digit-dataset/recordings
    # ./loca/convert_pcm.sh $fsdd_wav
    ./local/make_test.py
    ./local/make_train.py

    # DATA PREPARATION
    # text: <utt_id> <transcript>
    # wav.scp: <file_id><wave filename with path>
    # utt2spk: <utt_id> <speaker_id>

    # note: files should be sorted
    # can use utils/fix_data_dir.sh to do so

    # Needs to be prepared by hand (or using self written scripts): 
    #
    # spk2gender    [<speaker-id> <gender>]
    # wav.scp    [<uterranceID> <full_path_to_audio_file>]
    # text        [<uterranceID> <text_transcription>]
    # utt2spk    [<uterranceID> <speakerID>]
    # corpus.txt    [<text_transcription>]

    # sort utt2spk
    utils/validate_data_dir.sh data/train
    utils/validate_data_dir.sh data/test
    utils/fix_data_dir.sh data/train
    utils/fix_data_dir.sh data/test

    # Making spk2utt files
    utils/utt2spk_to_spk2utt.pl data/train/utt2spk > data/train/spk2utt
    utils/utt2spk_to_spk2utt.pl data/test/utt2spk > data/test/spk2utt
fi


if [ $stage -le 2 ]; then
    
    echo
    echo "===== FEATURES EXTRACTION ====="
    echo
    # Making feats.scp files
    export  mfccdir=mfcc
    # utils/validate_data_dir.sh data/train     # script for checking if prepared data is all right
    # utils/fix_data_dir.sh data/train          # tool for data sorting if something goes wrong above
    steps/make_mfcc.sh --nj $nspkrs --cmd "$train_cmd" data/train exp/make_mfcc/train $mfccdir
    steps/make_mfcc.sh --nj $nspkrs --cmd "$train_cmd" data/test exp/make_mfcc/test $mfccdir

    # Normalize cepstral features. Making cmvn.scp files
    # use --fake flag to skip feature normalization step
    steps/compute_cmvn_stats.sh data/train exp/make_mfcc/train $mfccdir
    steps/compute_cmvn_stats.sh data/test exp/make_mfcc/test $mfccdir

    # Print MFCC result
    copy-feats scp:mfcc/raw_mfcc_test.1.scp ark,t:- |head
    copy-feats ark:mfcc/raw_mfcc_test.1.ark ark,t:- |head

fi


if [ $stage -le 3 ]; then
    
    echo
    echo "===== PREPARING LANGUAGE DATA ====="
    echo

    # Needs to be prepared by hand (or using self written scripts): 
    #
    # lexicon.txt        [<word> <phone 1> <phone 2> ...]        
    # nonsilence_phones.txt    [<phone>]
    # silence_phones.txt    [<phone>]
    # optional_silence.txt    [<phone>]

    # Preparing language data
    # --position-dependent-phones false
    utils/prepare_lang.sh data/local/dict "<sil>" data/local/lang data/lang
fi


if [ $stage -le 4 ]; then
    
    echo
    echo "===== MAKING lm.arpa ====="
    echo

    loc=`which ngram-count`;
    if [ -z $loc ]; then
	if uname -a | grep 64 >/dev/null; then
            sdir=$KALDI_ROOT/tools/srilm/bin/i686-m64 
	else
          sdir=$KALDI_ROOT/tools/srilm/bin/i686
	fi
	if [ -f $sdir/ngram-count ]; then
            echo "Using SRILM language modelling tool from $sdir"
            export PATH=$PATH:$sdir
	else
          echo "SRILM toolkit is probably not installed.
              Instructions: tools/install_srilm.sh"
          exit 1
	fi
    fi

    local=data/local
    mkdir -p data/local/tmp
    ngram-count -order $lm_order -write-vocab $local/tmp/vocab-full.txt -wbdiscount -text $local/corpus.txt -lm $local/tmp/lm.arpa -sort
fi

if [ $stage -le 5 ]; then
    
    echo
    echo "===== COMPILING GRAMMAR G.fst ====="
    echo

    lang=data/lang
    mkdir -p data/lang
    cat $local/tmp/lm.arpa | arpa2fst - | fstprint | utils/eps2disambig.pl | utils/s2eps.pl | \
	fstcompile --isymbols=$lang/words.txt --osymbols=$lang/words.txt --keep_isymbols=false --keep_osymbols=false | \
	fstrmepsilon | fstarcsort --sort_type=ilabel > $lang/G.fst
fi

if [ $stage -le 6 ]; then

    # PARAMS
    # number of states for phoneme training
    pdf=200 # 1200 #10
    # number of gaussians used for training
    gauss=3000 # 19200 #100
    train_mmi_boost=0.05
    mmi_beam=16.0
    mmi_lat_beam=10.0
    fake="--fake"
    
    echo
    echo "===== TRAINING ACOUSTIC MODELS====="
    echo

    echo "train monophone model on full data"
    #--num-iters 10 --max-iter-inc 8 --totgauss 100 --boost-silence 1.25 --realign-iters "1 4 7 10"
    # steps/train_mono.sh --num-iters 10 --max-iter-inc 8 --totgauss $gauss \
    # 			--boost-silence 1.25 --realign-iters "1 3 5 7 10" \
    # 			--nj $nprocs --cmd "$train_cmd" $WORK/train $WORK/lang $EXP/mono  || exit 1

    steps/train_mono.sh --nj $nprocs --cmd "$train_cmd" $WORK/train $WORK/lang $EXP/mono  || exit 1

    echo "get alignments for monophone model"
    steps/align_si.sh --nj $nprocs --cmd "$train_cmd" $WORK/train $WORK/lang $EXP/mono $EXP/mono_ali || exit 1


    # triphone model to try to capture and model the effects of the two neighboring phones
    # Since the number of possible triphones is very large, many systems use a decision tree to cluster sets of triphones (aka senones) to reduce the complexity of the system to a more manageable scale

    # param: <num-leaves>  The number of such sets of triphones, corresponding to the leaves of the decision tree.
    #        <tot-gauss>   The total number of Gaussian mixtures used to model them (rule of thumb: <20 * num-leaves)
    # num_leaves=2000
    # tot_gauss=11000
    
    echo "Train tri1 [first triphone pass]"
    pdf=3200
    gauss=30000
    steps/train_deltas.sh  --cmd "$train_cmd" --boost-silence 1.25 \
			   $pdf $gauss $WORK/train $WORK/lang $EXP/mono_ali $EXP/tri1 || exit 1;

    # draw-tree $WORK/lang/phones.txt $EXP/tri1/tree | dot -Tsvg -Gsize=8,10.5  > graph.svg
    
    echo "Align tri1"
    steps/align_si.sh  --nj $nprocs --cmd "$train_cmd" \
		       --use-graphs true $WORK/train $WORK/lang $EXP/tri1 $EXP/tri1_ali || exit 1;

    echo "Train tri2a [delta+delta-deltas]"
    pdf=4200
    gauss=40000
    steps/train_deltas.sh  --cmd "$train_cmd" $pdf $gauss \
			   $WORK/train $WORK/lang $EXP/tri1_ali $EXP/tri2a || exit 1;

    echo "Train tri2b [LDA+MLLT]"
    pdf=4200
    gauss=40000
    steps/train_lda_mllt.sh  --cmd "$train_cmd" --splice-opts "--left-context=3 --right-context=3" $pdf $gauss \
    			     $WORK/train $WORK/lang $EXP/tri1_ali $EXP/tri2b || exit 1;

    echo "Align"
    steps/align_si.sh  --nj $nprocs --cmd "$train_cmd" \
    		       --use-graphs true $WORK/train $WORK/lang $EXP/tri2b $EXP/tri2b_ali || exit 1;

    echo "SAT+fmllr (tri3b)"
    pdf=4200
    gauss=40000
    steps/train_sat.sh --cmd "$train_cmd" $pdf $gauss \
      $WORK/train $WORK/lang $EXP/tri2b_ali $EXP/tri3b || exit 1;

    echo "align"
    steps/align_si.sh  --nj $nprocs --cmd "$train_cmd" \
    		       --use-graphs true $WORK/train $WORK/lang $EXP/tri3b $EXP/tri3b_ali || exit 1;

    echo "SGMM UBM (ubm5b2)"
    steps/train_ubm.sh  --cmd "$train_cmd"  \
      200 $WORK/train $WORK/lang $EXP/tri3b_ali $EXP/ubm5b2

    steps/train_sgmm2.sh  --cmd "$train_cmd"  \
       5200 12000 $WORK/train $WORK/lang $EXP/tri3b_ali $EXP/ubm5b2/final.ubm $EXP/sgmm2_5b2


    echo "Train MMI on top of LDA+MLLT."
    steps/make_denlats.sh  --nj $nprocs --cmd "$train_cmd" \
     			   --beam $mmi_beam --lattice-beam $mmi_lat_beam \
     			   $WORK/train $WORK/lang $EXP/tri2b $EXP/tri2b_denlats || exit 1;
    steps/train_mmi.sh  $WORK/train $WORK/lang $EXP/tri2b_ali $EXP/tri2b_denlats $EXP/tri2b_mmi || exit 1;


    echo "Train MMI on top of LDA+MLLT with boosting. train_mmi_boost is a e.g. 0.05"
    steps/train_mmi.sh  --boost ${train_mmi_boost} $WORK/train $WORK/lang \
     			$EXP/tri2b_ali $EXP/tri2b_denlats $EXP/tri2b_mmi_b || exit 1;

    echo "Train MPE."
    steps/train_mpe.sh $WORK/train $WORK/lang $EXP/tri2b_ali $EXP/tri2b_denlats $EXP/tri2b_mpe || exit 1;


fi

if [ $stage -le 7 ]; then
    
    echo
    echo "===== GRAPH GENERATION ====="
    echo
    utils/mkgraph.sh --mono $WORK/lang $EXP/mono $EXP/mono/graph || exit 1
    utils/mkgraph.sh $WORK/lang $EXP/tri1 $EXP/tri1/graph || exit 1
    utils/mkgraph.sh $WORK/lang $EXP/tri2a $EXP/tri2a/graph || exit 1
    utils/mkgraph.sh $WORK/lang $EXP/tri2b $EXP/tri2b/graph || exit 1    
    utils/mkgraph.sh $WORK/lang $EXP/tri3b $EXP/tri3b/graph || exit 1
    utils/mkgraph.sh $WORK/lang $EXP/sgmm2_5b2 $EXP/sgmm2_5b2/graph || exit 1
fi

if [ $stage -le 8 ]; then

    min_lmw=9
    max_lmw=20
    
    echo "monophone decoding"
    steps/decode.sh --boost-silence 1.25 --scoring-opts "--min-lmw $min_lmw --max-lmw $max_lmw" \
		    --config conf/decode.config --nj $nspkrs --cmd "$decode_cmd" \
		    $EXP/mono/graph $WORK/test $EXP/mono/decode

    echo "Decode tri1"
    steps/decode.sh --scoring-opts "--min-lmw $min_lmw --max-lmw $max_lmw" \
		    --config conf/decode.config --nj $nspkrs --cmd "$decode_cmd" \
		    $EXP/tri1/graph $WORK/test $EXP/tri1/decode

    echo "Decode tri2a"
    steps/decode.sh --scoring-opts "--min-lmw $min_lmw --max-lmw $max_lmw" \
		    --config conf/decode.config --nj $nspkrs --cmd "$decode_cmd" \
		    $EXP/tri2a/graph $WORK/test $EXP/tri2a/decode

    echo "Decode tri2b [LDA+MLLT]"
    steps/decode.sh --scoring-opts "--min-lmw $min_lmw --max-lmw $max_lmw" \
    		    --config conf/decode.config --nj $nspkrs --cmd "$decode_cmd" \
    		    $EXP/tri2b/graph $WORK/test $EXP/tri2b/decode

    echo "decode SAT+FMLLR (tri3b)"
    steps/decode_fmllr.sh --nj $nspkrs --cmd "$decode_cmd" \
			  $EXP/tri3b/graph $WORK/test $EXP/tri3b/decode

    echo "decode SGMM"
    steps/decode_sgmm2.sh --nj $nspkrs --cmd "$decode_cmd" \
			  --transform-dir exp/tri3b/decode \
			  $EXP/sgmm2_5b2/graph $WORK/dev $EXP/sgmm2_5b2/decode
    
#    Note: change --iter option to select the best model. 4.mdl == final.mdl
    echo "Decode MMI on top of LDA+MLLT."
    steps/decode.sh --scoring-opts "--min-lmw $min_lmw --max-lmw $max_lmw" \
    		    --config conf/decode.config --iter 3 --nj $nspkrs --cmd "$decode_cmd" \
    		    $EXP/tri2b/graph $WORK/test $EXP/tri2b_mmi/decode_it3

    steps/decode.sh --scoring-opts "--min-lmw $min_lmw --max-lmw $max_lmw" \
    		    --config conf/decode.config --iter 4 --nj $nspkrs --cmd "$decode_cmd" \
    		    $EXP/tri2b/graph $WORK/test $EXP/tri2b_mmi/decode_it4
    
    echo "Decode MMI on top of LDA+MLLT with boosting. train_mmi_boost is a number e.g. 0.05"
    steps/decode.sh --scoring-opts "--min-lmw $min_lmw --max-lmw $max_lmw" \
    		    --config conf/decode.config --iter 3 --nj $nspkrs --cmd "$decode_cmd" \
    		    $EXP/tri2b/graph $WORK/test $EXP/tri2b_mmi_b/decode_it3

    steps/decode.sh --scoring-opts "--min-lmw $min_lmw --max-lmw $max_lmw" \
    		    --config conf/decode.config --iter 4 --nj $nspkrs --cmd "$decode_cmd" \
    		    $EXP/tri2b/graph $WORK/test $EXP/tri2b_mmi_b/decode_it4

    echo "Decode MPE."
    steps/decode.sh --scoring-opts "--min-lmw $min_lmw --max-lmw $max_lmw" \
    		    --config conf/decode.config --iter 3 --nj $nspkrs --cmd "$decode_cmd" \
    		    $EXP/tri2b/graph $WORK/test $EXP/tri2b_mpe/decode_it3 || exit 1;

    steps/decode.sh --scoring-opts "--min-lmw $min_lmw --max-lmw $max_lmw" \
    		    --config conf/decode.config --iter 4 --nj $nspkrs --cmd "$decode_cmd" \
    		    $EXP/tri2b/graph $WORK/test $EXP/tri2b_mpe/decode_it4 || exit 1;    
fi


if [ $stage -le 8 ]; then
    # local/online/run_nnet2_multisplice.sh
    echo "stage 8"
fi


# echo "==== WORD LEVEL ALIGNMENT ===="
#     steps/get_ctm.sh data/train data/lang/ exp/mono/decode/ || exit 1

echo
echo "==== WER ===="
echo

for x in exp/*/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done

echo
echo "==== SER ===="
echo

for x in exp/*/decode*; do [ -d $x ] && grep SER $x/wer_* | utils/best_wer.sh; done


#local/results.py $EXP | tee $EXP/results.log
#local/export_models.sh /tmp $EXP $WORK/lang


# echo
# echo "==== translate lattice into text ===="
# echo

# lattice-best-path --acoustic-scale=0.1 --lm-scale=12 --word-symbol-table=exp/tri1/graph/words.txt "ark:zcat exp/tri1/decode/lat.1.gz |" ark,t:- | utils/int2sym.pl -f 2- exp/tri1/graph/words.txt > exp/tri1/decode/hyp.txt
# cat exp/tri1/decode/hyp.txt

# echo
# echo "===== run.sh script is finished ====="
# echo
