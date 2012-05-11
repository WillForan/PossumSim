#!/usr/bin/env bash

#
# generate possum input (brains)
# and run possum
#
# to regenerate brains use: REGEN=1 ./runPos.sh
#   otherwise if files exist, they will be used
#


#
###### ROIActBrain
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
#possumBrain="/opt/ni_tools/fsl_4.1.9/data/possum/brain.nii.gz"
#   MNIBrain="/Users/lncd/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c.nii"
   MNIBrain="/data/Luna1/ni_tools/standard_templates/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c.nii"
possumBrain="/data/Luna1/ni_tools/fsl_4.1.8/data/possum/brain.nii.gz"
ROIActBrain="inputs/10653_POSSUM4D_bb244_fullFreq_RPI.nii.gz"

maxjobsSrc="maxjobs.src.sh"
totaljobs=120
source $maxjobsSrc

# relax time and number of volumes to simulate
    TR=1.5
numvol=15

##### Set up inputs to possum

# motion and tr agnostic files
            MRF="inputs/MRpar_3T"
            RFF="inputs/slcprof"
         BrainF="inputs/MNIpaddedPossumBrain.nii.gz"    # **

# motion and tr dependent files 
inDir="inputs/${TR}TR_${numvol}vol"

        MotionF="$inDir/zeromotion"
         PulseF="$inDir/pulse/pulse_15"
    ActivationF="$inDir/activation.nii.gz"              # **
ActivationTimeF="$inDir/4DactivationTime"

# outputs (log and simulation)
outDir="output/zeroMotion_${TR}TR_${numvol}vol"
simDir="$outDir/sim"
logDir="$outDir/log"

# make all the paths
for d in "$simDir" "$logDir"; do
   [ ! -d $d ] && mkdir -p $d
done


#################################
# make brains
#################################

# make input brain
if [ ! -r "$BrainF" -o -n "$REGEN" ]; then 
  # where the temp file goes
  mnirpi="inputs/temp/mni_RPI.nii.gz"
  # resample mni into RPI
  3dresample -orient RPI -inset $MNIBrain -prefix  $mnirpi
  # resample possum into mni RPI (add padding)
  3dresample -inset $possumBrain -master $mnirpi -prefix $BrainF  -overwrite
fi

# make activation brain
if [ ! -r "$ActivationF" -o -n "$REGEN" ]; then
  # where the temp file goes
  acttemp="inputs/temp/trunc$numvol-tmp.nii.gz"
  # crop the number of values wanted -- takes a while try to only do once
  [ -r $acttemp ] || 3dTcat -prefix "$acttemp" "$ROIActBrain[0..$((($numvol-1)))]" 
  # resample to the input brain
  3dresample -inset "$acttemp" -master $BrainF -prefix $ActivationF -overwrite
  # set TR
  3drefit -TR $TR "$ActivationF" 
fi

[ -n "$REGEN" ] && echo "done regenerating brains" && exit



######################################################
### run possum
######################################################

set -e # die on error

for jobID in `seq 1 $totaljobs`; do
 logFile=${logDir}/$jobID.log 
 date > $logFile
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
      >> $logFile &
 
   jobcount=$(jobs|wc -l)
   
   # sleep until a job opens up
   while [ $jobcount  -gt $maxjobs ]; do
     # allow dynamically update how many jobs to run and how long to sleep
     source $maxjobsSrc 
     echo "sleeping for $sleeptime: $jobcount > $maxjobs"
     sleep $sleeptime
     jobcount=$(jobs|wc -l)
   done
done

set +e
