#!/bin/bash

# edit .json for fmaps to have "intended for" line for qsiprep to use.

umask 002

BIDS_DIR=/bmcdata/data/ADRC_core/BIDS
subj=$1
subj=`echo $subj | sed s/sub-//`
sess=$2
sess=`echo $sess | sed s/ses-//`
sess=`echo $sess | sed s/Session//`

for i in $BIDS_DIR/sub-${subj}/ses-Session${sess}/fmap/sub-${subj}_ses-Session${sess}_dir-??_*epi.json; do
    echo Editing $i - original contents: `cat $i`
    prefix=`echo $i | sed s/.json//`
    #cp $i ${prefix}_orig.json
    line=$(grep -n "EchoTime" $i | cut -d : -f 1)
    next=1
    lineout=$(($line + $next))

    array=()
    array=(`find $BIDS_DIR/sub-${subj}/ses-Session${sess}/dwi/*dwi.nii.gz -type f`)
    var=$( IFS=$'\n'; printf "\"${array[*]}"\" )
    filenames=$(echo $var | sed 's/ /", "/g')
    textin=$(echo -e '"IntendedFor": ['$filenames'],')
    sed -i "${lineout}i $textin " $i

    echo Done editing $i - new contents: `cat $i`

done

echo Done at `date`