PossumSim
=========

* mask ROIs with subject Grey Matter
* generate activation of motionless subject for region
* check simulation
* repeat with motion
* report variance 

## Dirs 

    /Volumes/Serena/rs-fcMRI_motion_simulation/10653_4dtemplate
    $FSLDIR/data/possum/brain.nii.gz

## Activation4D

### createTemplate.bash

* generate activation of the brain in simulated MRI
* only in GM, only for 244 ROIS 
* procedure 
    1. Warp (mprage) to template
    1. GM from Freesurfer tissue segmentation (aseg) 
    1. Preprocess (functional) 
        * motion (based on position of 100th volume), slice time (T_R = 1.5s)
        * skull strip from the mean functional
        * warp to structure, warp to template 
        * smooth (and remask)
        * Normalize: _voxel mean_, global mean, median, mode 
    1. Nuisance regression
        * demeaned  Motion, WhiteMatter,Vent, Global, and derivatives
    1. bandpass (all pass though currently [0-99999] )
    1. re-segment with fast (?)
    1. mask with GM and ROIs
    1. Put change in T2\* to T2\_static seconds 
* writes `${subj}_POSSUM4D_bb244_fullFreq.nii.gz`

### restPreproc\_possum.bash

* Process the simulated functional activation
* options `-4d` `-chop_vols` (default:5)  `-smoothing_kernel` (default:6)
* write `nbswktm_${funcFile}_${smoothing_kernel}_scale1_1mm_244GMMask`



