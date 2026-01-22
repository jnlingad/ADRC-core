#!/bin/bash
#SBATCH --partition=standard
#SBATCH --job-name=ALPS
#SBATCH -c 2
#SBATCH -o /mnt/hippocampus/starkdata1/Jess/ADRC_core/slurmlog_alps/DTI-ALPS_index_%j.out

# OG author of this script: Daniel Callow
# edited by Jessica Noche just to pull in the preprocessed dwi data from qsiprep and to reference to the ROIs generated for https://github.com/gbarisano/alps
# JN warped these the ROIs that were in JHU space to MNI space

# This calculates the DTI-ALPS index using diffusion maps from ROIs within projection (L,R superior corona radiata) and association (L,R superior longitudinal fasciculus) fibers

# JN: Set up apptainer environment variable for FSLDIR
export APPTAINERENV_FSLDIR=/opt/fsl-6.0.5.1 # FYI this is the version of our containerized FSL
export APPTAINERENV_FS_LICENSE=/mnt/hippocampus/starkdata1/Jess/ADRC_core/BIDS/code/fslicense.txt

# mrtrix, ANTs, fsl containers
MRT="singularity exec -B /mnt/hippocampus /mnt/hippocampus/starkdata1/Jess/mycontainers/mrtrix3_010923.sif"
ANTS="singularity exec -B /mnt /mnt/hippocampus/starkdata1/Jess/mycontainers/ants234_bc.sif"
FSL="singularity exec -B /mnt /mnt/hippocampus/starkdata1/Jess/mycontainers/fslmrs_v2.0.2.sif"

# Check if the subject ID is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <subject_ID>"
    exit 1
fi

# Define the folder and subject ID
SUBJECT_ID=$1
SUBJECT_ID=`echo $SUBJECT_ID | sed s/sub-//` # strip off sub-
FOLDER="/mnt/hippocampus/starkdata1/Jess/ADRC_core/BIDS/derivatives/alps"
if [ ! -d $FOLDER ]; then
    mkdir -p $FOLDER
fi

ROI_FOLDER="/mnt/hippocampus/starkdata1/Jess/ADRC_core/BIDS/derivatives/alps/ROIs_MNI_ALPS"
OUTPUT_FOLDER="${FOLDER}/DTI_ALPS_results_rigid"
if [ ! -d $OUTPUT_FOLDER ]; then
    mkdir -p $OUTPUT_FOLDER
fi

# Define ROI file paths - these were nonlinearly warped from JHU to MNI
# ROI_LEFT_ASSOCIATION="${ROI_FOLDER}/L_SLF.nii.gz"
# ROI_RIGHT_ASSOCIATION="${ROI_FOLDER}/R_SLF.nii.gz"
# ROI_LEFT_PROJECTION="${ROI_FOLDER}/L_SCR.nii.gz"
# ROI_RIGHT_PROJECTION="${ROI_FOLDER}/R_SCR.nii.gz"

ROI_LEFT_ASSOCIATION="${ROI_FOLDER}/L_SLF_rigid.nii.gz"
ROI_RIGHT_ASSOCIATION="${ROI_FOLDER}/R_SLF_rigid.nii.gz"
ROI_LEFT_PROJECTION="${ROI_FOLDER}/L_SCR_rigid.nii.gz"
ROI_RIGHT_PROJECTION="${ROI_FOLDER}/R_SCR_rigid.nii.gz"

# Initialize results file
RESULT_FILE="${OUTPUT_FOLDER}/DTI_ALPS_indices_${SUBJECT_ID}.csv"
echo "Subject,ALPS_Index_Left,ALPS_Index_Right" > $RESULT_FILE

# Define the subject directory and new ID
SUBJECT_DIR="${FOLDER}/sub-${SUBJECT_ID}"
if [ ! -d $SUBJECT_DIR ]; then
    mkdir $SUBJECT_DIR
fi

NEW_ID=sub-${SUBJECT_ID}
echo "Processing subject: ${NEW_ID}"

#### MAJOR JN UPDATE: adding in bits to grab tensor data, then get Dxx, Dyy, and Dzz from mrtrix mrconvert

# preprocessed data path
PREPROC_PATH=/mnt/hippocampus/starkdata1/Jess/ADRC_core/BIDS/derivatives/tensors/sub-${SUBJECT_ID}/ses-Session1

# 1. convert preprocessed dwi data to tensor
if [ ! -e $SUBJECT_DIR/nativespace_dwi_tensor.mif ]; then
    echo Converting preprocessed DWI data to tensor
    $MRT dwi2tensor $PREPROC_PATH/*dwi.mif $SUBJECT_DIR/nativespace_dwi_tensor.mif
fi
# 2. Get the diffusivity maps along the x, y, and z axes, which are located within the 4th dimension (index=3) of the tensor data:
    # dxx=3,0
    # dyy=3,1
    # dzz=3,2
    # axes= 0,1,2 ensure that the image is just a 3d image; if not including -axes, output will be a 4d image but the 4th dimension will end up being just 1 anyway.

echo Getting the diffusivity maps along the x, y, and z axes
$MRT mrconvert $SUBJECT_DIR/nativespace_dwi_tensor.mif -coord 3 0 -axes 0,1,2 $SUBJECT_DIR/nativespace_dxx.mif
$MRT mrconvert $SUBJECT_DIR/nativespace_dwi_tensor.mif -coord 3 1 -axes 0,1,2 $SUBJECT_DIR/nativespace_dyy.mif
$MRT mrconvert $SUBJECT_DIR/nativespace_dwi_tensor.mif -coord 3 2 -axes 0,1,2 $SUBJECT_DIR/nativespace_dzz.mif

# 3. Convert to .nii.gz
echo Converting to .nii.gz
if [ ! -e $SUBJECT_DIR/nativespace_dxx.nii.gz ]; then
    $MRT mrconvert $SUBJECT_DIR/nativespace_dxx.mif $SUBJECT_DIR/nativespace_dxx.nii.gz
fi
if [ ! -e $SUBJECT_DIR/nativespace_dyy.nii.gz ]; then
    $MRT mrconvert $SUBJECT_DIR/nativespace_dyy.mif $SUBJECT_DIR/nativespace_dyy.nii.gz 
fi
if [ ! -e $SUBJECT_DIR/nativespace_dzz.nii.gz ]; then
    $MRT mrconvert $SUBJECT_DIR/nativespace_dzz.mif $SUBJECT_DIR/nativespace_dzz.nii.gz 
fi

# 4. Apply warps from qsiprep to move these to MNI space (1mm)
MNI_TEMPLATE=/mnt/hippocampus/starkdata1/Jess/ADRC_core/templateflow/tpl-MNI152NLin2009cAsym/tpl-MNI152NLin2009cAsym_res-01_T2w.nii.gz
QSIPREP_DIR=/mnt/hippocampus/starkdata1/Jess/ADRC_core/BIDS/derivatives/qsiprep_v0x21x4_2
T1_to_MNI_WARP=${QSIPREP_DIR}/qsiprep/sub-${SUBJECT_ID}/anat/sub-${SUBJECT_ID}_from-T1w_to-MNI152NLin2009cAsym_mode-image_xfm.h5

for dir in dxx dyy dzz; do
    if [ ! -e $SUBJECT_DIR/MNIspace_${dir}.nii.gz ]; then
        echo Moving $SUBJECT_DIR/nativespace_${dir}.nii.gz image to MNI space
        $ANTS antsApplyTransforms -d 3 \
        -i $SUBJECT_DIR/nativespace_${dir}.nii.gz \
        -r $MNI_TEMPLATE \
        -t ${T1_to_MNI_WARP} \
        -o $SUBJECT_DIR/MNIspace_${dir}.nii.gz
    fi
done

### Done with the major JN update to Daniel's script -- now for the minor updates to filenames and such, but of course keeping daniel's calculations

# Define paths to the DTI tensor components
DX="${SUBJECT_DIR}/MNIspace_dxx.nii.gz"
DY="${SUBJECT_DIR}/MNIspace_dyy.nii.gz"
DZ="${SUBJECT_DIR}/MNIspace_dzz.nii.gz"

# Function to calculate mean within a mask
calc_mean_in_mask() {
    local tensor=$1
    local mask=$2
    if $FSL fslmaths $tensor -mas $mask ${SUBJECT_DIR}/temp_masked.nii.gz; then
        $FSL fslstats ${SUBJECT_DIR}/temp_masked.nii.gz -M
    else
        echo "Error applying mask. Check if the tensor and mask dimensions match."
        return 1
    fi
}

# For the Left Side
Dx_association_left=$(calc_mean_in_mask $DX $ROI_LEFT_ASSOCIATION)
if [ $? -eq 1 ]; then exit 1; fi
Dz_association_left=$(calc_mean_in_mask $DZ $ROI_LEFT_ASSOCIATION)
if [ $? -eq 1 ]; then exit 1; fi
Dx_projection_left=$(calc_mean_in_mask $DX $ROI_LEFT_PROJECTION)
if [ $? -eq 1 ]; then exit 1; fi
Dy_projection_left=$(calc_mean_in_mask $DY $ROI_LEFT_PROJECTION)
if [ $? -eq 1 ]; then exit 1; fi

# Print ROI averages for the Left Side
echo "Left Association ROI Averages: Dx = $Dx_association_left, Dz = $Dz_association_left"
echo "Left Projection ROI Averages: Dx = $Dx_projection_left, Dy = $Dy_projection_left"

# JN: we have to run bc from the ANTs container because our nodes don't have bc installed...
Dx_avg_left=$(echo "$Dx_association_left + $Dx_projection_left" | $ANTS bc)
Dz_avg_left=$Dz_association_left
Dy_avg_left=$Dy_projection_left

alps_index_left=$(echo "$Dx_avg_left / ($Dy_avg_left + $Dz_avg_left)" | $ANTS bc -l)

# For the Right Side
Dx_association_right=$(calc_mean_in_mask $DX $ROI_RIGHT_ASSOCIATION)
if [ $? -eq 1 ]; then exit 1; fi
Dz_association_right=$(calc_mean_in_mask $DZ $ROI_RIGHT_ASSOCIATION)
if [ $? -eq 1 ]; then exit 1; fi
Dx_projection_right=$(calc_mean_in_mask $DX $ROI_RIGHT_PROJECTION)
if [ $? -eq 1 ]; then exit 1; fi
Dy_projection_right=$(calc_mean_in_mask $DY $ROI_RIGHT_PROJECTION)
if [ $? -eq 1 ]; then exit 1; fi

# Print ROI averages for the Right Side
echo "Right Association ROI Averages: Dx = $Dx_association_right, Dz = $Dz_association_right"
echo "Right Projection ROI Averages: Dx = $Dx_projection_right, Dy = $Dy_projection_right"

Dx_avg_right=$(echo "$Dx_association_right + $Dx_projection_right" | $ANTS bc)
Dz_avg_right=$Dz_association_right
Dy_avg_right=$Dy_projection_right

alps_index_right=$(echo "$Dx_avg_right / ($Dy_avg_right + $Dz_avg_right)" | $ANTS bc -l)

# Save the ALPS indices to the results file
echo "${NEW_ID},${alps_index_left},${alps_index_right}" >> $RESULT_FILE

# Clean up temporary files
rm -f ${SUBJECT_DIR}/temp_masked.nii.gz

echo "DTI-ALPS index calculation for ${SUBJECT_ID} complete. Results saved to ${RESULT_FILE}"
