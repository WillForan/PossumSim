PossumSim
=========
## Simulation
run by `runPossum/runPos.sh` see `runPossum/readme.md`

## Problem
Zero-motion simulated activation is not correlated with input activation within the brain or within the ROIs.
`eval/Check_ActivationCorrs_11Vol.R`

## unit sanity checks

### Percent signal change comparison
`eval/mask/PSC.sh`

for both our simulation and the default simulation

* `_steadyState.nii.gz` remove the first 5 volumes of the simulation
* `_to_mniRPI` warp the `3.2 x 3.2 x 3.9mm` simulation output into `1mm^3` simulation input space (this direction is conservative)
* `_MaskByInput.nii.gz` create mask from simulation input and apply to warped output (only look at what should change)
    * use binary mask of `fslmaths -Tmax` to identify all voxels used to provide activation to possum
* `_PSC.nii.gz` masked warped simulation/mean across time, scale 100x `100*s/m`
* look at percentiles of percent signal change in increments of 10 `fslstats $PSC $(seq 0 10 100|sed 's/^/-P /')`

eval/mask/PSC.sh

    our:    98.202827 99.945663 99.984612 99.993546 99.997459 99.999695 100.001778 100.005592 100.014824 100.052811  102.378998 
    def: -6479.607422 99.882957 99.972885 99.991508 99.997589 99.999557 100.000153 100.001991 100.016258 100.101547 8134.155273 

### Inputs  ( activation3D v. 10653_POSSUM4D_bb244_fullFreq_RPI )

Default

    fslstats  runPossum/inputs/possumDefault/activation3D.nii.gz  $(seq 0 10 100|sed 's/^/-P /')
    -0.004380 -0.000148 -0.000046 -0.000001 0.000003 0.000027 0.000616 0.001904 0.003339 0.005224 0.020054 

 with max up to *0.2080 and min *0.0625 based on coef in activation3Dtimecourse (`| perl -slane 'print join " ", map {$_*0.0625} @F'`)

    -0.00091104 -3.0784e-05 -9.568e-06 -2.08e-07 6.24e-07  5.616e-06  0.000128128 0.000396032 0.000694512  0.001086592 0.004171232
    -0.00027375 -9.25e-06   -2.875e-06 -6.25e-08 1.875e-07 1.6875e-06 3.85e-05    0.000119    0.0002086875 0.0003265   0.001253375

Ours

    fslstats  runPossum/inputs/10653_POSSUM4D_bb244_fullFreq_RPI.nii.gz   $(seq 0 10 100|sed 's/^/-P /')
    -0.011187 -0.000643 -0.000410 -0.000253 -0.000122 -0.000001 0.000120 0.000252 0.000414 0.000655 0.01890

### Outputs (brainImage_abs)

on default 

    fslstats def_steadyState.nii.gz  $(seq 0 10 100|sed 's/^/-P /')
    0.000001 0.025122 0.129458 0.261100 0.510435 1.275171 46.933567 50.492115 52.606575 54.991096 67.815620 

on ours

    fslstats our_steadyState.nii.gz  $(seq 0 10 100|sed 's/^/-P /')
    0.000062 0.068471 0.171856 0.319948 0.627242 1.712328 48.406570 50.825855 52.734016 55.082741 70.112701 

## overview


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



