#!/bin/bash
#SBATCH --partition=standard
#SBATCH --job-name=qsiprep
#SBATCH -c 8
#SBATCH -o /bmcdata/data/ADRC_core/slurmlog/qsiprep_v1.0.1-%j.out

# JESS 9/5/25

# run_qsiprep_v1.0.1.sh will save the outputs to BIDS/derivatives/qsiprep
## USAGE: ./run_qsiprep_v1.0.1.sh sub-ID session
    # sub-ID: requires the 'sub-' prefix
    # ses-Session: e.g. ses-Session1

## DESCRIPTION: 
    # Runs ADRC BMC data in qsiprep

# Set up number of threads if not running on sbatch
if [[ ! -v SLURM_CPUS_PER_TASK ]]; then  # Likely running locally
  echo Defaulting to 16 CPU threads 
  SLURM_CPUS_PER_TASK=16
fi

slots=$SLURM_CPUS_PER_TASK

umask 002

# Check for valid command line arguments
if [ $# -ne 2 ]; then
    echo "Error: This script requires exactly 2 arguments."
    echo "Usage: $0 <subject_id> <session_number>"
    echo "Example: $0 sub-ID ses-Session1"
    exit 1
fi

# COMMAND LINE ARGUMENTS
sid=`echo $1 | sed s/sub-//`
sess=`echo $2 | sed s/ses-//`
sess=`echo $sess | sed s/Session//`

# CONTAINERS
singularity_image=/bmcdata/data/ADRC_core/containers/qsiprep_v1.0.1.sif

export SINGULARITYENV_FS_LICENSE=/bmcdata/data/ADRC_core/BIDS/code/license.txt
export FS_LICENSE=/bmcdata/data/ADRC_core/BIDS/code/license.txt
export SINGULARITYENV_TEMPLATEFLOW_HOME=/bmcdata/data/ADRC_core/templateflow
export TEMPLATEFLOW_HOME=/bmcdata/data/ADRC_core/templateflow
export SLURM_CPUS_PER_TASK

# PATHS
bids_dir=/bmcdata/data/ADRC_core/BIDS
subdir=$bids_dir/sub-${sid}
outdir=$bids_dir/derivatives/qsiprep/sub-${sid}/ses-Session${sess}
if [ ! -e $outdir ]; then
mkdir -p $outdir
fi
# if we made a bids filter ahead of time, this is it
bids_filter=$bids_dir/derivatives/qsiprep/sub-${sid}/ses-Session${sess}/bids_filter.json
eddy_config=$bids_dir/code/eddy_config.json

# edit the eddy config file to use the slots allocated for this
cat $eddy_config | envsubst > $outdir/eddy_config_${slots}slots.json

echo Starting qsiprep on $SLURM_JOB_NODELIST with $SLURM_CPUS_PER_TASK slots
echo +++ Running qsiprep v1.0.1 on $sid $sess at `date` +++

# # echo Environment Variables
# env
# exit

echo ++ Running from qsiprep container $singularity_image ++

call="time singularity run --writable-tmpfs --containall \
    -B ${TEMPLATEFLOW_HOME}:${TEMPLATEFLOW_HOME} \
    -B /bmcdata:/bmcdata \
    $singularity_image \
    $bids_dir $bids_dir/derivatives/qsiprep \
    participant --participant-label $sid \
    --ignore t2w \
    --output-resolution 2.0 \
    --unringing-method mrdegibbs \
    --pepolar-method TOPUP --use-syn-sdc \
    --eddy-config $outdir/eddy_config_${slots}slots.json \
    --omp-nthreads $slots --nthreads $slots \
    --anat-modality T1w --skip-bids-validation -v \
    -w /bmcdata/data/ADRC_core/work \
    --fs-license-file $FS_LICENSE \
    --resource-monitor \
    --stop-on-first-crash"

# add bids filter if we have one
if [ -e $bids_filter ]; then
call=`echo $call --bids-filter-file $bids_filter`
else echo No BIDS filter for sub-${sid}
#exit
fi

echo Command: $call

echo $call | bash

# write call to directory
echo $call > $bids_dir/derivatives/qsiprep/sub-${sid}/ses-Session${sess}/run_qsiprep_command_sub-${sid}.txt

echo Done at `date`