#!/bin/bash
#SBATCH --partition=standard
#SBATCH --job-name=qsirecon
#SBATCH -c 8
#SBATCH -o /bmcdata/data/ADRC_core/slurmlog/qsirecon_v1.0.1-%j.out

# JESS 9/5/25

# run_qsirecon_v1.1.1.sh will save the outputs to BIDS/derivatives/qsirecon
## USAGE: ./run_qsiprep_v1.1.1.sh sub-ID session
    # sub-ID: requires the 'sub-' prefix
    # ses-Session: e.g. ses-Session1

## DESCRIPTION: 
    # Runs ADRC BMC data in qsirecon for scalar maps from amico, dipy MAPMRI, also TORTOISE that gets MAPMRI and tensor fits, and GQI which also gets tensor fits

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
singularity_image=/bmcdata/data/ADRC_core/containers/qsirecon_v1.1.1.sif

export SINGULARITYENV_FS_LICENSE=/bmcdata/data/ADRC_core/BIDS/code/license.txt
export FS_LICENSE=/bmcdata/data/ADRC_core/BIDS/code/license.txt
export SINGULARITYENV_TEMPLATEFLOW_HOME=/bmcdata/data/ADRC_core/templateflow
export TEMPLATEFLOW_HOME=/bmcdata/data/ADRC_core/templateflow
export SLURM_CPUS_PER_TASK

# PATHS
bids_dir=/bmcdata/data/ADRC_core/BIDS
subdir=$bids_dir/sub-${sid}
outdir=$bids_dir/derivatives/qsirecon/sub-${sid}/ses-Session${sess}
if [ ! -e $outdir ]; then
mkdir -p $outdir
fi


echo Starting recon on $SLURM_JOB_NODELIST with $SLURM_CPUS_PER_TASK slots
echo +++ Running recon v1.1.1 on $sid $sess at `date` +++

# # echo Environment Variables
# env
# exit

echo ++ Running from qsiprep container $singularity_image ++


# NODDI
call_noddi="time singularity run --writable-tmpfs --containall --env TEMPLATEFLOW_HOME=${TEMPLATEFLOW_HOME} \
    -B ${TEMPLATEFLOW_HOME}:${TEMPLATEFLOW_HOME} \
    -B /bmcdata:/bmcdata \
    $singularity_image \
    $bids_dir/derivatives/qsiprep \
    $bids_dir/derivatives/qsirecon \
    participant \
    --participant-label $sid \
    --session-id Session${sess} \
    --fs-license-file $FS_LICENSE \
    --recon-spec /bmcdata/data/ADRC_core/BIDS/code/amico_noddi_dpar1.3.yaml \
    --output-resolution 2.0 \
    -w /bmcdata/data/ADRC_core/work \
    --omp-nthreads $slots --nthreads $slots \
    --write-graph \
    --stop-on-first-crash \
    -v -v"


echo Command: $call_noddi

echo $call_noddi | bash

# write call to directory
echo $call_noddi > $bids_dir/derivatives/qsirecon/sub-${sid}/ses-Session${sess}/run_qsirecon_noddi_command_sub-${sid}.txt

# dipy MAPMRI
call_mapmri="time singularity run --writable-tmpfs --containall --env TEMPLATEFLOW_HOME=${TEMPLATEFLOW_HOME} \
    -B ${TEMPLATEFLOW_HOME}:${TEMPLATEFLOW_HOME} \
    -B /bmcdata:/bmcdata \
    $singularity_image \
    $bids_dir/derivatives/qsiprep \
    $bids_dir/derivatives/qsirecon \
    participant \
    --participant-label $sid \
    --session-id Session${sess} \
    --fs-license-file $FS_LICENSE \
    --recon-spec dipy_mapmri \
    --output-resolution 2.0 \
    -w /bmcdata/data/ADRC_core/work \
    --omp-nthreads $slots --nthreads $slots \
    --write-graph \
    --stop-on-first-crash \
    -v -v"


echo Command: $call_mapmri

echo $call_mapmri | bash

# write call to directory
echo $call_mapmri > $bids_dir/derivatives/qsirecon/sub-${sid}/ses-Session${sess}/run_qsirecon_mapmri_command_sub-${sid}.txt

# TORTOISE MAPMRI
call_tortoise="time singularity run --writable-tmpfs --containall --env TEMPLATEFLOW_HOME=${TEMPLATEFLOW_HOME} \
    -B ${TEMPLATEFLOW_HOME}:${TEMPLATEFLOW_HOME} \
    -B /bmcdata:/bmcdata \
    $singularity_image \
    $bids_dir/derivatives/qsiprep \
    $bids_dir/derivatives/qsirecon \
    participant \
    --participant-label $sid \
    --session-id Session${sess} \
    --fs-license-file $FS_LICENSE \
    --recon-spec TORTOISE \
    --output-resolution 2.0 \
    -w /bmcdata/data/ADRC_core/work \
    --omp-nthreads $slots --nthreads $slots \
    --write-graph \
    --stop-on-first-crash \
    -v -v"


echo Command: $call_tortoise

echo $call_tortoise | bash

# write call to directory
echo $call_tortoise > $bids_dir/derivatives/qsirecon/sub-${sid}/ses-Session${sess}/run_qsirecon_TORTOISE_command_sub-${sid}.txt

# dsi_studio_gqi for tensor metrics
call_gqi="time singularity run --writable-tmpfs --containall --env TEMPLATEFLOW_HOME=${TEMPLATEFLOW_HOME} \
    -B ${TEMPLATEFLOW_HOME}:${TEMPLATEFLOW_HOME} \
    -B /bmcdata:/bmcdata \
    $singularity_image \
    $bids_dir/derivatives/qsiprep \
    $bids_dir/derivatives/qsirecon \
    participant \
    --participant-label $sid \
    --session-id Session${sess} \
    --fs-license-file $FS_LICENSE \
    --recon-spec dsi_studio_gqi \
    --output-resolution 2.0 \
    -w /bmcdata/data/ADRC_core/work \
    --omp-nthreads $slots --nthreads $slots \
    --write-graph \
    --stop-on-first-crash \
    -v -v"


echo Command: $call_gqi

echo $call_gqi | bash

# write call to directory
echo $call_gqi > $bids_dir/derivatives/qsirecon/sub-${sid}/ses-Session${sess}/run_qsirecon_gqi_command_sub-${sid}.txt
echo Done at `date`