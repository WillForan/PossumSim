function demeanPSC {
   simInput=$1
   simOutput=$2
   simBrain=$3
   simName=$4

  

   set -xe

   # bring 3mm sim output (as flirt input) into simulation input 1 mm (as flirt ref) 
   # so the sim input can be used to mask the sim output
   [ -r ${simName}_to_mniRPI.nii.gz ] ||                              \
    flirt -in $simOutput -ref $simBrain -out ${simName}_to_mniRPI     \
          -dof 6 -schedule ${FSLDIR}/etc/flirtsch/sch3Dtrans_3dof       \
          -interp sinc -sincwidth 7 -sincwindow hanning


   # get all non zero voxels in one place (flatten time series)
   # this takes too long, but no danger of messing up orientation 
   ## doesn't do anything to defInput
   [ -r ${simName}_Tmax.nii.gz ] || fslmaths $simInput -Tmax ${simName}_Tmax.nii.gz

   # use input (flattened) to mask simulation output
   [ -r ${simName}_MaskByInput.nii.gz ] || \
     3dcalc -a ${simInput}_Tmax.nii.gz -b ${simName}_to_mniRPI.nii.gz \
             -expr 'step(abs(a))*b' -prefix ${simName}_MaskByInput.nii.gz

   # get PSC with mean= 1.0
   if [ ! -r  ${simName}_scale1.nii.gz ]; then

      # grand mean intensity scaling factor to achieve M = 100
      # actually want voxel mean though ???
      fslmaths ${simName}_MaskByInput.nii.gz -add 100 -ing 100 ${simName}_scaleM100 -odt float

      #dividing the M=100 file by 100 yields a proportion of mean scaling (PSC)
      fslmaths ${simName}_scaleM100 -div 100 ${simName}_scale1 -odt float
   fi 

   set +xe

   # print some stats
   fslstats ${simName}_scale1.nii.gz   $(seq 0 10 100|sed 's/^/-P /')
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



