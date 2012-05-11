#################################
# make brains
#################################
# * brains are resampled against MNI
#   and orientated to RPI
#
# * assumes exists:
#     * <possumBrain> - location of brain include with possom
#     * <MNIBrain>    - the location of base mni brain
#     * <ROIActBrain> - ROI masked activation of most motionless subject
#
# * creates
#     * <BrainF>      - brain to simulate in the scanner (segmented tissue in 3 subbricks)
#     * <ActivationF> - activation pattern in TE seconds
#
# * <BrainF>      =>  <possumBrain> resampled with master <MNIBrain> in RPI
# * <ActivationF> => truncate <ROIActBrain>, resampled to <BrainF>, reset TR


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




###### ROIActBrain history
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

