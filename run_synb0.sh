#!/bin/bash
#SBATCH --partition=standard
#SBATCH --job-name=SynB0
#SBATCH -o /bmcdata/data/ADRC_core/slurmlog/synb0-%j.out
#SBATCH -c 16

# JN | 11/01/23

## USAGE: ./synth_b0.sh subID sess
# subID: sub-XXXXXX
# sess: ses-SessionX

## DESCRIPTION: synthesize a b0 for diffusion distortion correction with synb0-DISCO: https://github.com/MASILab/Synb0-DISCO/tree/master#overview
echo echo Started at `date`

if [[ ! -v SLURM_CPUS_PER_TASK ]]; then
  echo Defaulting to 2 CPU threads 
  SLURM_CPUS_PER_TASK=2
fi

# sid=`echo $1 | sed s/sub-//`
# echo $sid

# sess=`echo $2 | sed s/ses-//`
# sess=`echo $sess | sed s/Session//`
# echo $sess

sid=$1
dwi=$2
t1=$3

echo Running synb0 on $dwi and $t1

bids_path=/bmcdata/data/ADRC_core/BIDS
der_path=$bids_path/derivatives/synb0/$sid/ses-Session1
if [ ! -d $der_path ]; then
  mkdir -p $der_path
fi
# t1_path=$bids_path/sub-${sid}/ses-Session${sess}/anat

# CONTAINERS
SYNTH=/bmcdata/data/ADRC_core/containers/synb0-disco_v3.0.sif
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
MRT="singularity exec -B /bmcdata /bmcdata/data/ADRC_core/containers/mrtrix3_conda.sif"
MRT_opts="-nthreads $SLURM_CPUS_PER_TASK"

# INPUTS

# First, extract b0

# 1. setting up .mif files
#filename=$(basename -- "$dwi")
fulldwi=`echo $dwi | sed s/.nii.gz//`
filename="${dwi##*/}"
outname=`echo $filename | sed s/.nii.gz//`

if [ ! -e $der_path/${outname}_b0.nii.gz ]; then
# Convert raw multi-shell
	$MRT mrconvert $dwi $der_path/${outname}.mif -fslgrad ${fulldwi}.bvec ${fulldwi}.bval -json_import ${fulldwi}.json
  echo Extracting median b0 image
  $MRT dwiextract $MRT_opts $der_path/${outname}.mif $der_path/${outname}_b0_all.nii.gz
  $MRT mrmath -axis 3 $der_path/${outname}_b0_all.nii.gz median $der_path/${outname}_b0.nii.gz
  rm $der_path/${outname}_b0_all.nii.gz
  echo Extracting median b0 finished at: `date`
fi

# FINAL INPUTS FOR SYNB0
b0_input=$der_path/${outname}_b0.nii.gz
t1_input=$t1

# give inputs correct names for synb0 to recognize

# copy B0 and T1
echo copying $b0_input and $t1_input to $der_path
cp $b0_input $der_path/b0.nii.gz
cp $t1 $der_path/T1.nii.gz

echo b0: $der_path/b0.nii.gz
echo T1: $der_path/T1.nii.gz

# Run -- don't run in topup since qsiprep will handle that
singularity run -e \
-B $der_path:/INPUTS \
-B $der_path:/OUTPUTS \
-B /bmcdata/data/ADRC_core/containers/license.txt:/extra/freesurfer/license.txt \
$SYNTH --notopup

echo Finished at `date` -- b0_u.nii.gz is the file to pass into qsiprep