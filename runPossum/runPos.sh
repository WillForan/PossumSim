#!/usr/bin/env bash

#
# generate possum input (brains)
# and run possum
#
# to regenerate brains use: REGEN=1 ./runPos.sh
#   otherwise if files exist, they will be used
#


#########################
### setup environment ###
#########################

# relax time and number of volumes to simulate
    TR=1.5
numvol=15


# "root" path is where the script residse
r=$(dirname $0) 

# job information
maxjobsSrc="$r/maxjobs.src.sh"
totaljobs=120
source $maxjobsSrc



### Brains ###

ROIActBrain="$r/inputs/10653_POSSUM4D_bb244_fullFreq_RPI.nii.gz"

# wallace path
   MNIBrain="/data/Luna1/ni_tools/standard_templates/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c.nii"
possumBrain="/data/Luna1/ni_tools/fsl_4.1.8/data/possum/brain.nii.gz"

# skynet path
#possumBrain="/opt/ni_tools/fsl_4.1.9/data/possum/brain.nii.gz"
#   MNIBrain="/Users/lncd/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c.nii"



### outputs (log and simulation) ###
outDir="$r/output/zeroMotion_${TR}TR_${numvol}vol"
simDir="$outDir/sim"
logDir="$outDir/log"


### make all the paths ###
for d in "$simDir" "$logDir"; do
   [ ! -d $d ] && mkdir -p $d
done

###############################
### Set up inputs to possum ###
###############################

#------------------------------#
# motion and tr agnostic files #
#------------------------------#

   MRF="$r/inputs/MRpar_3T"
   RFF="$r/inputs/slcprof"
BrainF="$r/inputs/MNIpaddedPossumBrain.nii.gz"    # **


#-------------------------------#
# motion and tr dependent files #
#-------------------------------#

inDir="$r/inputs/${TR}TR_${numvol}vol"

        MotionF="$inDir/zeromotion"
         PulseF="$inDir/pulse/pulse_15"
    ActivationF="$inDir/activation.nii.gz"       # **
ActivationTimeF="$inDir/4DactivationTime"


#-----------------------#
# Generate needed Files #
#-----------------------#
# if REGEN is non-zero length, recreated files and exit

# check that the brain files exist, or create them
source mkBrain.src.sh

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
