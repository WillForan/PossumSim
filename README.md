PossumSim
=========
## unit sanity checks

### Percent signal change comparison

for both our simulation and the default simulation

* `_to_mniRPI` warp the `3.2 x 3.2 x 3.9mm` simulation output into `1mm^3` simulation input space (this direction is conservative)
* `_MaskByInput.nii.gz` create mask from simulation input and apply to warped output (only look at what should change)
* `_PSC.nii.gz` divide mean from the difference of the masked warped simulation and the mean across time, multiply by 100 (i-m)/m*100
* look at `fslstats $PSC $(seq 0 10 100|sed 's/^/-P /')`

eval/mask/genMask.sh

    our:     -21.384027 -3.524719 -2.522913 -1.943590 -1.573372 -1.285426 -1.024168 -0.782435 -0.543973 -0.113260    127.623230 
    def: -353183.468750 -6.853281 -4.548309 -2.980075 -2.009488 -1.414311 -1.001237 -0.690173 -0.477898  0.150954 178981.031250 

### Inputs  ( activation3D v. 10653_POSSUM4D_bb244_fullFreq_RPI )

Default

    fslstats  runPossum/inputs/possumDefault/activation3D.nii.gz  $(seq 0 10 100|sed 's/^/-P /')
    -0.004380 -0.000148 -0.000046 -0.000001 0.000003 0.000027 0.000616 0.001904 0.003339 0.005224 0.020054 

 with max up to *0.2080 and min *0.0625 based on coef in activation3Dtimecourse (`| perl -slane 'print join " ", map {$_*0.0625} @F'`)

    -0.00091104 -3.0784e-05 -9.568e-06 -2.08e-07 6.24e-07 5.616e-06 0.000128128 0.000396032 0.000694512 0.001086592 0.004171232
    -0.00027375 -9.25e-06 -2.875e-06 -6.25e-08 1.875e-07 1.6875e-06 3.85e-05 0.000119 0.0002086875 0.0003265 0.001253375

Constructed

    fslstats  runPossum/inputs/10653_POSSUM4D_bb244_fullFreq_RPI.nii.gz   $(seq 0 10 100|sed 's/^/-P /')
    -0.011187 -0.000643 -0.000410 -0.000253 -0.000122 -0.000001 0.000120 0.000252 0.000414 0.000655 0.01890

### Outputs (brainImage_abs)

on default 

    fslstats runPossum/output/defaultActivation_1.5TR_15vol/sim/brainImage_abs.nii.gz   $(seq 0 10 100|sed 's/^/-P /')
    0.000000 0.026420 0.136411 0.277663 0.548555 1.376216 47.412048 50.667046 52.903187 55.634007 147.255325

on constructed

    fslstats runPossum/output/zeroMotion_1.5TR_15vol/sim/brainImage_abs.nii.gz   $(seq 0 10 100|sed 's/^/-P /')
    0.000062 0.071509 0.180692 0.341071 0.676219 1.866770 48.506321 50.991276 53.060177 55.771019 146.422607

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



