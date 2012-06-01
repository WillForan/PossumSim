function demeanPSC {
   simInput=$1
   simOutput=$2
   simBrain=$3
   simName=$4

  

   set -xe

   # remove the first 5 volumes so we are only looking at the steady state part of the simulation
   [ -r ${simName}_steadyState.nii.gz ] || 3dTcat "$simOutput"'[5..$]' -prefix ${simName}_steadyState.nii.gz
   simOutput=${simName}_steadyState.nii.gz


   # bring 3mm sim output (as flirt input) into simulation input 1 mm (as flirt ref) 
   # so the sim input can be used to mask the sim output
   if [ ! -r ${simName}_to_mniRPI.nii.gz ] ; then
    # generate warp mat (don't use out, will only apply to first volume -- need it on all 15)
    flirt -in $simOutput -ref $simBrain  \
          -omat ${simName}_to_mniRPI.mat \
          -dof 6 -schedule ${FSLDIR}/etc/flirtsch/sch3Dtrans_3dof
    # apply it to all (sub)volumes
    applywarp \
          --ref=$simBrain \
          --in=$simOutput \
          --out=${simName}_to_mniRPI \
          --premat=${simName}_to_mniRPI.mat \
          --interp=spline
   fi
   # *** WHY: dim t == 1!?  _to_mniRPI

   # get all non zero voxels in one place (flatten time series)
   # this takes too long, but no danger of messing up orientation 
   ## doesn't do anything to defInput
   [ -r ${simName}_Tmax.nii.gz ] || fslmaths $simInput -Tmax ${simName}_Tmax.nii.gz
   # assumes simInput and simBrain are in the same space

   # use input (flattened) to mask simulation output
   # m from tmax
   # f from flirt/applywarp
   [ -r ${simName}_MaskByInput.nii.gz ] || \
     3dcalc -f ${simName}_to_mniRPI.nii.gz -m ${simName}_Tmax.nii.gz     \
            -expr 'step(abs(m))*f' -prefix ${simName}_MaskByInput.nii.gz

   # get PSC with mean= 1.0
   #PSC=${simName}_scale1.nii.gz
   PSC=${simName}_PSC.nii.gz
   if [ ! -r  $PSC ]; then

      #### FIRST ATTEMPT
      # grand mean intensity scaling factor to achieve M = 100
      #fslmaths ${simName}_MaskByInput.nii.gz -add 100 -ing 100 ${simName}_scaleM100 -odt float
      # -inm <mean> :  (-i i ip.c) intensity normalisation (per 3D volume mean)
      # -ing <mean> :  (-I i ip.c) intensity normalisation, global 4D mean)
      # or use -Tmean and subtract new from orig.
      # actually want voxel mean though ???
      #fslmaths ${simName}_scaleM100 -div 100 ${PSC} -odt float

      ### SECOND ATTEMPT : get mean, subtract mean from sim output, div by mean, scale 100x
      # get mean over T
      #fslmaths ${simName}_MaskByInput.nii.gz -Tmean ${simName}_Tmean -odt float
      # (subtract from actual (mean at 1) * 100
      #3dcalc -i ${simName}_MaskByInput.nii.gz -m ${simName}_Tmean.nii.gz -expr '100*(i-m)/m' -prefix ${PSC}

      #### THIRD
      # get mean over time for each voxel
      3dTstat -overwrite -prefix ${simName}_Tmean.afni.nii.gz  ${simName}_MaskByInput.nii.gz 
      # get simulation output's diff from mean for each voxel per volume
      3dcalc -overwrite -prefix ${simName}_PSC.nii.gz \
             -s ${simName}_MaskByInput.nii.gz -m ${simName}_Tmean.nii.gz  \
             -expr '100*s/m' 

   fi 

   # print some stats
   fslstats ${PSC}   $(seq 0 10 100|sed 's/^/-P /')

   set +xe
}

 ourInput="../../runPossum/inputs/10653_POSSUM4D_bb244_fullFreq_RPI.nii.gz"
ourOutput="../../runPossum/output/zeroMotion_1.5TR_15vol/sim/brainImage_abs.nii.gz"
 ourBrain="10653_t1_1mm_mni152_rpi.nii.gz"

 defInput="../../runPossum/inputs/possumDefault/activation3D.nii.gz"
defOutput="../../runPossum/output/defaultActivation_1.5TR_15vol/sim/brainImage_abs.nii.gz"
defBrain="../../runPossum/inputs/possumDefault/brain.nii.gz"



# get % sig change with 1.0 mean as *_scale1, 
our=$( demeanPSC $ourInput $ourOutput $ourBrain our)
def=$( demeanPSC $defInput $defOutput $defBrain def)
echo "our: $our"
echo "def: $def"



