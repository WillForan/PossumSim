#!/bin/bash
set -e
set -x

# Subject
       scriptdir="$(dirname $0)"
      templateT1="$scriptdir/inputs/10653/mprage_bet.nii.gz"                # struct ref for flirt lin warp
templateWarpCoef="$scriptdir/inputs/10653/mprage_warpcoef.nii.gz"           # applywarp (x2)
  templateGMMask="$scriptdir/inputs/10653/10653_bb244_gmMask_fast_bin+tlrc" # last 3dcalc
# skynet only
#templateT1=/Volumes/Serena/rs-fcMRI_motion_simulation/10653_4dtemplate/mprage/mprage_bet.nii.gz
#templateWarpCoef=/Volumes/Serena/rs-fcMRI_motion_simulation/10653_4dtemplate/mprage/mprage_warpcoef.nii.gz
#templateGMMask=/Volumes/Serena/rs-fcMRI_motion_simulation/10653_4dtemplate/mprage/10653_bb244_gmMask_fast_bin+tlrc

# MNI
mniTemplate_1mm=$HOME/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c_brain
    mniTemplate=$HOME/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c_brain_3mm
        mniMask=$HOME/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c_mask_3mm.nii

#if no parameters are passed in, then print help and exit.
if [ $# -eq 0 ]; then
    echo "No command line parameters passed. Expect at least -4d."
    exit 0
fi

# provided as input argument
funcFile=
# detected by fslhd of activation brain
TR=
smoothing_kernel=6
chop_vols=5 #3dbp says 1 transient issue with 4

#process command line parameters
while [ _$1 != _ ] ; do
    if [[ $1 = -4d || $1 = -4D ]] ; then
	funcFile="${2}"
	funcNifti="${funcFile}" #retains file extension
	shift 2
    elif [ $1 = -smoothing_kernel ] ; then
        smoothing_kernel=${2}
        shift 2
    elif [ $1 = -chop_vols ] ; then
        chop_vols=${2}
        shift 2
    else
	echo -e "----------------\n\n"
	echo "Unrecognized command line parameter: ${1}"
	exit 1
    fi
done

sigma=$( echo "scale=5; $smoothing_kernel/2.355" | bc )

# like funcFile="$(dirname $funcNifti )/$(basename $(basename $funcNifti .gz) .nii)"
if [ ${funcFile:(-7)} = ".nii.gz" ]; then
    if [ ! -f ${funcFile} ]; then
	echo -e "Raw functional 4D file: $funcFile does not exist.\nPass in as -4d parameter. Exiting.\n"
	exit 1
    else
	#strip off the suffix for FSL processing and makes filenames easier to build.
	lenFile=${#funcFile}
	lenSub=$( expr $lenFile - 7 )
	funcFile=${funcFile:0:$lenSub}
    fi
elif [ ${funcFile:(-4)} = ".nii" ]; then
    if [ ! -f ${funcFile} ]; then
	echo -e "Raw functional 4D file: $funcFile does not exist.\nPass in as -4d parameter. Exiting.\n"
	exit 1
    else
	#strip off the suffix for FSL processing
	lenFile=${#funcFile}
	lenSub=$( expr $lenFile - 4 )
	funcFile=${funcFile:0:$lenSub}
    fi
else
    #passed in parameter does not have nii or nii.gz extension. Need to test for file
    if [[ ! -f "${funcFile}.nii" && ! -f "${funcFile}.nii.gz" ]]; then
	echo -e "Raw functional 4d file: $funcFile does not exist.\nAttempted to look for ${funcFile}.nii and ${funcFile}.nii.gz to no avail.\nExiting.\n"
	exit 1
    fi
fi

#obtain TR from func file (original funcFile from POSSUM is trustworthy)
#round to 3 dec
detectTR=$( fslhd ${funcNifti} | grep "^pixdim4" | perl -pe 's/pixdim4\s+(\d+)/\1/' | xargs printf "%1.3f" )

#remove initial volumes corresponding to discarded volumes from scanner
#spins have not reached steady state yet and intensities are quite sharp

truncOutput="$(basename $funcFile)_trunc${chop_vols}"
numVols=$( fslhd ${funcNifti}  | grep '^dim4' | perl -pe 's/dim4\s+(\d+)/\1/' )

fslroi  ${funcFile} $truncOutput ${chop_vols} $((${numVols}-1)) #fslroi uses 0-based indexing

#ensure that chopped files are used moving forward
funcFile=$truncOutput 
funcNifti=${truncOutput}.nii.gz

#1. motion correction
if [ ! -f m_${funcNifti} ]; then
    #align to middle volume (was using mean, but seems less directly interpretable in this context)
    #mcflirt -in functional -o m_functional -meanvol -stages 4 -sinc_final -rmsabs -rmsrel
    #mcflirt -in ${funcFile} -o m_${funcFile} -stages 4 -sinc_final -rmsabs -rmsrel -plots #if omit refvol, defaults to middle

    #quick reduce to 3-stage for testing (go back to sinc_final once script works)
    mcflirt -in ${funcFile} -o m_${funcFile} -stages 3 -rmsabs -rmsrel -plots #if omit refvol, defaults to middle
fi

#2. slice timing correction
if [ ! -f tm_${funcNifti} ]; then
    slicetimer -i m_${funcFile} -o tm_${funcFile} -r ${detectTR}
fi

#skull strip mean functional
fslmaths tm_${funcFile} -Tmean tm_mean_${funcFile}                     # generate mean functional
bet tm_mean_${funcFile} ktm_mean_${funcFile} -R -f 0.4 -m              # skull strip mean functional
fslmaths tm_${funcFile} -mas ktm_mean_${funcFile}_mask ktm_${funcFile} # apply skull strip mask to 4d file

#compute the median intensity (prior to warp) of voxels within the BET mask
#(couldn't I just use ktm_${funcFile} since that has the mask applied?)
median_intensity=$( fslstats "tm_${funcFile}" -k "ktm_mean_${funcFile}_mask" -p 50 )

p_2=$( fslstats "ktm_${funcFile}" -p 2 )

#from FEAT
susan_thresh=$( echo "scale=5; ($median_intensity - $p_2) * 0.75" | bc )

#linear warp mean functional to structural
flirt -in ktm_mean_${funcFile} -ref ${templateT1} -out func_to_mprage -omat func_to_mprage.mat -dof 7

#warp subject mask to MNI using NN
applywarp \
    --ref=${mniTemplate} \
    --in=ktm_mean_${funcFile}_mask \
    --out=wktm_${funcFile}_mask \
    --premat=func_to_mprage.mat \
    --warp=${templateWarpCoef} \
    --interp=nn

#ensure that subject mask does not extend beyond bounds of anatomical mask, but may be smaller
#subtract mni anatomical mask from subject's mask, then threshold at zero (neg values represent areas where anat mask > subj mask)
fslmaths wktm_${funcFile}_mask -sub ${mniMask} -thr 0 wktm_outofbounds_mask -odt char

fslmaths wktm_${funcFile}_mask -sub wktm_outofbounds_mask wktm_${funcFile}_mask_anatTrim -odt char

#warp functional to structural
#stick with spline interpolation for now. Sinc has tendency to blur far outside the mask (as I knew),
#but what is striking here is that any limitations of the mask are quite magnified by the sinc interpolation, but not spline
applywarp --ref=${mniTemplate} \
    --in=ktm_${funcFile} --out=wktm_${funcFile} --premat=func_to_mprage.mat --warp=${templateWarpCoef} \
    --interp=spline --mask=wktm_${funcFile}_mask_anatTrim

#prior to smoothing, create and an extents mask to ensure that all time series are sampled at all timepoints
fslmaths wktm_${funcFile} -Tmin -bin extents_mask -odt char

if [ ! -f swktm_${funcFile}_${smoothing_kernel}.nii.gz ]; then
    fslmaths wktm_${funcFile} -Tmean wktm_mean_${funcFile}
    susan wktm_${funcFile} ${susan_thresh} ${sigma} 3 1 1 wktm_mean_${funcFile} ${susan_thresh} swktm_${funcFile}_${smoothing_kernel}
fi

#now apply the extents mask to eliminate excessive blurring due to smooth and only retain voxels fully sampled in unsmoothed space
fslmaths swktm_${funcFile}_${smoothing_kernel} -mul extents_mask swktm_${funcFile}_${smoothing_kernel} -odt float

#use 3dBandpass here for consistency (no nuisance regression, of course)
#in particular, this is used to quadratic detrend all voxel time series, which makes the scaling to 1.0 sensible.
#otherwise, the -ing 100 makes all brain voxels high and all air voxels low. Would need to ing within mask otherwise.
3dBandpass -input swktm_${funcFile}_${smoothing_kernel}.nii.gz -mask extents_mask.nii.gz \
    -prefix bswktm_${funcFile}_${smoothing_kernel}.nii.gz 0 99999

#intensity normalization to mean 1.0. This makes it comparable to the original activation input (before T2* scaling)
#logic: add some constant to all voxels, then determine the grand mean intensity scaling factor to achieve M = 100
#this will make non-brain voxels 100, and voxels within the brain ~100
#necessary to scale away from 0 to allow for division against baseline to yield PSC
#Otherwise, leads to division by zero problems. (should not be problematic here since we did not detrend voxel time series)
fslmaths bswktm_${funcFile}_${smoothing_kernel} -add 100 -ing 100 bswktm_${funcFile}_${smoothing_kernel}_scaleM100 -odt float

#dividing the M=100 file by 100 yields a proportion of mean scaling (PSC)
fslmaths bswktm_${funcFile}_${smoothing_kernel}_scaleM100 -div 100 nbswktm_${funcFile}_${smoothing_kernel}_scale1 -odt float

#okay, should have achieved the functional input with all proper preprocessing and scaling

#need to upsample the final file to 1mm voxels for comparison with original input
#upsample the preproc data (scale 1) into 1mm voxels to match GM mask
flirt -in nbswktm_${funcFile}_${smoothing_kernel}_scale1 \
    -ref ${mniTemplate_1mm} \
    -applyxfm -init ${FSLDIR}/etc/flirtsch/ident.mat \
    -out nbswktm_${funcFile}_${smoothing_kernel}_scale1_1mm -paddingsize 0.0 -interp nearestneighbour

#now should apply the 244 GM mask to these data for comparison
3dcalc -overwrite -a nbswktm_${funcFile}_${smoothing_kernel}_scale1_1mm.nii.gz -b ${templateGMMask} -expr 'a*b' \
    -prefix nbswktm_${funcFile}_${smoothing_kernel}_scale1_1mm_244GMMask
