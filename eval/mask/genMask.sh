function demeanPSC {
   simInput=$1
   simOutput=$2
   simBrain=$3
   simName=$4

  

   set -xe

   # bring 3mm sim output (as flirt input) into simulation input 1 mm (as flirt ref) 
   # so the sim input can be used to mask the sim output
   if [ ! -r ${simName}_to_mniRPI.nii.gz ] ; then
    flirt -in $simOutput -ref $simBrain -out ${simName}_to_mniRPI_pre \
          -omat func_to_mniRPI.mat                                    \
          -dof 6 -schedule ${FSLDIR}/etc/flirtsch/sch3Dtrans_3dof     \
          -interp sinc -sincwidth 7 -sincwindow hanning
    applywarp \
          --ref=$simBrain \
          --in=$simOutput \
          --out=${simName}_to_mniRPI \
          --premat=func_to_mniRPI.mat \
          --interp=sinc
   fi
   # *** WHY: dim t == 1!?  _to_mniRPI

   # get all non zero voxels in one place (flatten time series)
   # this takes too long, but no danger of messing up orientation 
   ## doesn't do anything to defInput
   [ -r ${simName}_Tmax.nii.gz ] || fslmaths $simInput -Tmax ${simName}_Tmax.nii.gz

   # use input (flattened) to mask simulation output
   [ -r ${simName}_MaskByInput.nii.gz ] || \
     3dcalc -a ${simInput}_Tmax.nii.gz -b ${simName}_to_mniRPI.nii.gz \
             -expr 'step(abs(a))*b' -prefix ${simName}_MaskByInput.nii.gz

   # get PSC with mean= 1.0
   #PSC=${simName}_scale1.nii.gz
   PSC=${simName}_PSC.nii.gz
   if [ ! -r  $PSC ]; then

      # grand mean intensity scaling factor to achieve M = 100
      #fslmaths ${simName}_MaskByInput.nii.gz -add 100 -ing 100 ${simName}_scaleM100 -odt float
      # -inm <mean> :  (-i i ip.c) intensity normalisation (per 3D volume mean)
      # -ing <mean> :  (-I i ip.c) intensity normalisation, global 4D mean)
      # or use -Tmean and subtract new from orig.
      # actually want voxel mean though ???
      #fslmaths ${simName}_scaleM100 -div 100 ${PSC} -odt float

      # get mean over T
      fslmaths ${simName}_MaskByInput.nii.gz -Tmean ${simName}_Tmean -odt float
      # (subtract from actual (mean at 1) - 1) * 100
      3dcalc -i ${simName}_MaskByInput.nii.gz -m ${simName}_Tmean.nii.gz -expr '((i-m)/m)*100' -prefix ${PSC}
   fi 

   set +xe

   # print some stats
   fslstats ${PSC}   $(seq 0 10 100|sed 's/^/-P /')
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



