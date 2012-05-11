#!/usr/bin/env bash

#
# possum --nproc=128 --procid=15 \
#        -o sim/act1.5_15_zero_1.5_15/possum_15 \
#        -m variables/zero_1.5_15motion \
#        -i defaults/possum_10653_fast.nii.gz \
#        -x defaults/MRpar_3T \
#        -f defaults/slcprof \
#        -p pulse_15 \
#        --activ4D=variables/act1.5_15.nii.gz \
#        --activt4D=variables/act1.5_15_time
#
# roiactbrain
#
#
#=== Input a:
#3drefit -TR 1.500 rnswktm_functional_6_100voxelmean_scale1_1mm.nii.gz
#=== Input b:
# ===================================
#=== History of inputs to 3dcalc ===
#=== Input a:
# 3dUndump -master 10653_t1_1mm_mni152.nii.gz -prefix bb244 -xyz -srad 5 -orient LPI bb244_coordinate
#=== Input b:
# 3dresample -inset 10653_mni152_fast_seg_1.nii.gz -orient LPI -prefix 10653_mni152_fast_seg_1
#===================================
#3dcalc -a bb244+tlrc -b 10653_mni152_fast_seg_1+tlrc -expr 'a*b' -prefix 10653_bb244_gmMask_fast
#3dcalc -a 10653_bb244_gmMask_fast+tlrc -expr 'step(a)' -prefix 10653_bb244_gmMask_fast_bin
#===================================
#3dcalc -a /Volumes/Serena/rs-fcMRI_motion_simulation/10653_4dtemplate/rest/rnswktm_functional_6_100voxelmean_scale1_1mm.nii.gz -b 10653_bb244_gmMask_fast_bin+tlrc -expr 'a*b' -prefix /Volumes/Serena/rs-fcMRI_motion_simulation/10653_4dtemplate/rest/rnswktm_functional_6_100voxelmean_scale1_1mm_244GMMask
#3dcalc -a /Volumes/Serena/rs-fcMRI_motion_simulation/10653_4dtemplate/rest/rnswktm_functional_6_100voxelmean_scale1_1mm_244GMMask+tlrc -expr '((29/(29/51-log(a)))-51)/1000' -prefix /Volumes/Serena/rs-fcMRI_motion_simulation/10653_4dtemplate/rest/10653_POSSUM4D_bb244_fullFreq.nii.gz
#3dresample -inset 10653_POSSUM4D_bb244_fullFreq.nii.gz -orient RPI -prefix 10653_POSSUM4D_bb244_fullFreq_RPI.nii.gz


### setup environment
ROIActBrain="inputs/10653_POSSUM4D_bb244_fullFreq_RPI.nii.gz"
possumBrain="/opt/ni_tools/fsl_4.1.9/data/possum/brain.nii.gz"
   MNIBrain="/Users/lncd/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c.nii"

totaljobs=120
  maxjobs=10
sleeptime=100

       TR=1.5
   numvol=15

##### Set up inputs to possum

# motion and tr agnostic files
            MRF="inputs/MRpar_3T"
            RFF="inputs/slcprof"
         BrainF="inputs/MNIpaddedpossumBrain.nii.gz"            # **
        
# motion and tr dependent files 
        MotionF="inputs/${TR}TR_${numvol}vol/zeromotion"
         PulseF="inputs/${TR}TR_${numvol}vol/pulse/pulse_15"
    ActivationF="inputs/${TR}TR_${numvol}vol/activation.nii.gz" # **
ActivationTimeF="inputs/${TR}TR_${numvol}vol/4DactivationTime"

outDir="output/zeroMotion_${TR}TR_${numvol}vol"
simDir="$outDir/sim"
logDir="$outDir/log"

# make all the paths
for d in "$simDir" "$logDir"; do
   [ ! -d $d ] && mkdir -p $d
done


# make input brain
[ ! -r "$BrainF" ] && 3dresample -inset $possumBrain -master $MNIBrain -prefix $BrainF

# make activation brain
if [ ! -r "$ActivationF" ]; then
  # crop the number of values wanted
  3dTcat -prefix "$ActivationF" "$ROIActBrain[0..$((($numvol-1)))]" 
  # for new TR
  3drefit -TR $TR "$ActivationF" 
fi

### run possum
set -e # die on error
for jobID in `seq 1 $totaljobs`; do
 possum                           \
    --nproc=$totaljobs            \
    --procid=$jobID               \
    -x ${MRF}                     \
    -f ${RFF}                     \
    -i ${BrainF}                  \
    -m ${MotionF}                 \
    -p ${PulseF}                  \
    --activ4D=${ActivationF}      \
    --activt4D=${ActivationTimeF} \
    -o $simDir/possum_${jobID}    \
      > ${logDir}_$jobID.log &
 
   jobcount=$(jobs|wc -l)
   
   # sleep until a job opens up
   while [ $jobcount  -gt $maxjobs ]; do
     echo "sleeping for $sleeptime: $jobcount > $maxjobs"
     sleep $sleeptime
     jobcount=$(jobs|wc -l)
   done
done
set +e
