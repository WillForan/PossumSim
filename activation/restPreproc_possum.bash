#!/bin/bash
set -e
set -x

#should be warping against 1mm 10653 structural already in mni + rpi space
templateT1=/Volumes/Serena/rs-fcMRI_motion_simulation/10653_4dtemplate/mprage/10653_t1_1mm_mni152_rpi.nii.gz
templateGMMask=/Volumes/Serena/rs-fcMRI_motion_simulation/10653_4dtemplate/mprage/10653_bb244_gmMask_fast_bin+tlrc
mniTemplate_3mm=$HOME/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c_brain_3mm
mniTemplate_1mm=$HOME/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c_brain
mniMask_3mm=$HOME/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c_mask_3mm.nii
mniMask_1mm=$HOME/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c_mask.nii

#if no parameters are passed in, then print help and exit.
if [ $# -eq 0 ]; then
    echo "No command line parameters passed. Expect at least -4d."
    exit 0
fi

funcFile=
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
detectTR=$( fslhd ${funcFile} | grep "^pixdim4" | perl -pe 's/pixdim4\s+(\d+)/\1/' | xargs printf "%1.3f" )

#remove initial volumes corresponding to discarded volumes from scanner
#spins have not reached steady state yet and intensities are quite sharp

numVols=$( fslhd ${funcNifti}  | grep '^dim4' | perl -pe 's/dim4\s+(\d+)/\1/' )
fslroi ${funcFile} ${funcFile}_trunc${chop_vols} ${chop_vols} $((${numVols}-1)) #fslroi uses 0-based indexing

#ensure that chopped files are used moving forward
funcFile=${funcFile}_trunc${chop_vols}
funcNifti=${funcFile}.nii.gz

#1. slice timing correction
#placing first see here: http://mindhive.mit.edu/node/109
if [ ! -f t_${funcNifti} ]; then
    slicetimer -i ${funcFile} -o t_${funcFile} -r ${detectTR}
fi

#2. motion correction
if [ ! -f mt_${funcNifti} ]; then
    #align to middle volume (was using mean, but seems less directly interpretable in this context)
    #mcflirt -in functional -o m_functional -meanvol -stages 4 -sinc_final -rmsabs -rmsrel
    #mcflirt -in ${funcFile} -o m_${funcFile} -stages 4 -sinc_final -rmsabs -rmsrel -plots #if omit refvol, defaults to middle

    #quick reduce to 3-stage for testing (go back to sinc_final once script works)
    mcflirt -in t_${funcFile} -o mt_${funcFile} -stages 3 -rmsabs -rmsrel -plots #if omit refvol, defaults to middle
fi

#3. skull strip mean functional
if [ ! -f kmt_${funcNifti} ]; then
    fslmaths mt_${funcFile} -Tmean mt_mean_${funcFile} #generate mean functional
    bet mt_mean_${funcFile} kmt_mean_${funcFile} -R -f 0.4 -m #skull strip mean functional
    fslmaths mt_${funcFile} -mas kmt_mean_${funcFile}_mask kmt_${funcFile} #apply skull strip mask to 4d file
fi

#compute the median intensity (prior to co-registration) of voxels within the BET mask
#(couldn't I just use kmt_${funcFile} since that has the mask applied?)
median_intensity=$( fslstats "mt_${funcFile}" -k "kmt_mean_${funcFile}_mask" -p 50 )

#needed for susan threshold
p_2=$( fslstats "kmt_${funcFile}" -p 2 )

#from FEAT
susan_thresh=$( echo "scale=5; ($median_intensity - $p_2) * 0.75" | bc )

#4. co-register the POSSUM output with the POSSUM anatomical (T1) input.
#N.B.: The POSSUM T1 input is already in MNI space and of the desired orientation and voxel size.
#Thus, the task here is co-registration, NOT warping per se.

#one approach: just resample the brain to match the geometry of the POSSUM input T1
#PROBLEM: There is a big translation between POSSUM output and the template T1 space.
#This occurs because the coordinate system of the POSSUM output is arbitrary, similar to scanner anatomical.
#But the relative shape, size, etc. of the POSSUM output is correct, only the orientation and origin are offset.
#flirt -in kmt_${funcFile} -ref ${templateT1} -applyxfm -init ${FSLDIR}/etc/flirtsch/ident.mat \
#    -out wkmt_${funcFile}_resampOnly -paddingsize 0.0 -interp sinc -sincwidth 7 -sincwindow hanning

#Similar problems with AFNI
#3dresample -overwrite -inset kmt_${funcFile}.nii.gz -master ${templateT1} -prefix wkmt_${funcFile}_resampleOnlyAFNI.nii.gz

#This is right: co-register mean functional to structural, allowing for translation, rotation, and global scaling
#The transformation matrix is ~1 on the diagonal (scaling) and 0 on the off-diagonal (rotation), but big translation components.
#flirt -in kmt_mean_${funcFile} -ref ${templateT1} -out func_to_mprage -omat func_to_mprage.mat -dof 7 \
#    -interp sinc -sincwidth 7 -sincwindow hanning

#Sensible: force flirt to 3 df to allow for translation only since there should be a 1:1 match with the input.
#i.e., the relative position and size of the POSSUM output should precisely match input.
#Is there a possibility that more df will be needed to co-register once we have motion to contend with?
#The mean functional may (prob. not) include some imprecision due to residual motion effects. Cross that bridge when we come to it.
#Use the 1mm template T1 to maximize similarity to input. Using 3mm downsampled T1s tended to shift translations ~0.5mm.
flirt -in kmt_mean_${funcFile} -ref ${templateT1} -out func_to_mprage -omat func_to_mprage.mat \
    -dof 6 -schedule ${FSLDIR}/etc/flirtsch/sch3Dtrans_3dof \
    -interp sinc -sincwidth 7 -sincwindow hanning

#warp subject mask to 3mm MNI-POSSUM brain using NN
#shouldn't matter whether MNI template or 10653 since ref is just used for image geometry
applywarp \
    --ref=${mniTemplate_3mm} \
    --in=kmt_mean_${funcFile}_mask \
    --out=wkmt_${funcFile}_mask \
    --premat=func_to_mprage.mat \
    --interp=nn

#ensure that subject mask does not extend beyond bounds of anatomical mask, but may be smaller
#subtract mni anatomical mask from subject's mask, then threshold at zero (neg values represent areas where anat mask > subj mask)
fslmaths wkmt_${funcFile}_mask -sub ${mniMask_3mm} -thr 0 wkmt_outofbounds_mask -odt char

fslmaths wkmt_${funcFile}_mask -sub wkmt_outofbounds_mask wkmt_${funcFile}_mask_anatTrim -odt char

#co-register POSSUM-simulated functional to POSSUM input structural at 3mm. (1mm co-registration above mostly for affine mat.
#stick with spline interpolation for now. Sinc has tendency to blur far outside the mask (as I knew),
#but what is striking here is that any limitations of the mask are quite magnified by the sinc interpolation, but not spline
applywarp --ref=${mniTemplate_3mm} \
    --in=kmt_${funcFile} --out=wkmt_${funcFile} --premat=func_to_mprage.mat \
    --interp=spline --mask=wkmt_${funcFile}_mask_anatTrim

#prior to smoothing, create and an extents mask to ensure that all time series are sampled at all timepoints
fslmaths wkmt_${funcFile} -Tmin -bin extents_mask -odt char

if [ ! -f swkmt_${funcFile}_${smoothing_kernel}.nii.gz ]; then
    fslmaths wkmt_${funcFile} -Tmean wkmt_mean_${funcFile}
    susan wkmt_${funcFile} ${susan_thresh} ${sigma} 3 1 1 wkmt_mean_${funcFile} ${susan_thresh} swkmt_${funcFile}_${smoothing_kernel}
fi

#now apply the extents mask to eliminate excessive blurring due to smooth and only retain voxels fully sampled in unsmoothed space
fslmaths swkmt_${funcFile}_${smoothing_kernel} -mul extents_mask swkmt_${funcFile}_${smoothing_kernel} -odt float

#use 3dBandpass here for consistency (no nuisance regression, of course)
#in particular, this is used to quadratic detrend all voxel time series, which makes the scaling to 1.0 sensible.
#otherwise, the -ing 100 makes all brain voxels high and all air voxels low. Would need to ing within mask otherwise.
3dBandpass -input swkmt_${funcFile}_${smoothing_kernel}.nii.gz -mask extents_mask.nii.gz \
    -prefix bswkmt_${funcFile}_${smoothing_kernel}.nii.gz 0 99999

#intensity normalization to mean 1.0. This makes it comparable to the original activation input (before T2* scaling)
#logic: add some constant to all voxels, then determine the grand mean intensity scaling factor to achieve M = 100
#this will make non-brain voxels 100, and voxels within the brain ~100
#necessary to scale away from 0 to allow for division against baseline to yield PSC
#Otherwise, leads to division by zero problems. (should not be problematic here since we did not detrend voxel time series)
fslmaths bswkmt_${funcFile}_${smoothing_kernel} -add 100 -ing 100 bswkmt_${funcFile}_${smoothing_kernel}_scaleM100 -odt float

#dividing the M=100 file by 100 yields a proportion of mean scaling (PSC)
fslmaths bswkmt_${funcFile}_${smoothing_kernel}_scaleM100 -div 100 nbswkmt_${funcFile}_${smoothing_kernel}_scale1 -odt float

#okay, should have achieved the functional input with all proper preprocessing and scaling

#need to upsample the final file to 1mm voxels for comparison with original input
#upsample the preproc data (scale 1) into 1mm voxels to match GM mask
flirt -in nbswkmt_${funcFile}_${smoothing_kernel}_scale1 \
    -ref ${mniTemplate_1mm} \
    -applyxfm -init ${FSLDIR}/etc/flirtsch/ident.mat \
    -out nbswkmt_${funcFile}_${smoothing_kernel}_scale1_1mm -paddingsize 0.0 -interp nearestneighbour

#now should apply the 244 GM mask to these data for comparison
3dcalc -overwrite -a nbswkmt_${funcFile}_${smoothing_kernel}_scale1_1mm.nii.gz -b ${templateGMMask} -expr 'a*b' \
    -prefix nbswkmt_${funcFile}_${smoothing_kernel}_scale1_1mm_244GMMask




##########

#This is a mistake: POSSUM output will be in MNI space based on already warped brain.
#By contrast, these coefs warp 10653's native space brain into MNI...
#Should resample instead.
#####templateWarpCoef=/Volumes/Serena/rs-fcMRI_motion_simulation/10653_4dtemplate/mprage/mprage_warpcoef.nii.gz
