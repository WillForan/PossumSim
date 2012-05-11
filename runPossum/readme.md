# Possum

* see `runPos.sh`
* sleep time and parallel number set in `maxjobs.src.sh`
* output to `<scriptdir>/output/zeroMotion_<TR>TR_<numvol>vol/sim/possum_<jobID>`
* log to `<scriptdir>/output/zeroMotion_<TR>TR_<numvol>vol/log/<jobID>.log`

# Inputs

## Brains

* see `mkBrains.src.sh`
* assumes exists:
    * _possumBrain_: location of brain include with possom
    * _MNIBrain_: the location of base mni brain
    * _ROIActBrain_: ROI masked activation of most motionless subject

* creates
    * _BrainF_:       brain to simulate in the scanner (segmented tissue in 3 subbricks)
    * _ActivationF_:  activation pattern in TE seconds
* _BrainF_      =>  _possumBrain_ resampled with master _MNIBrain_ in RPI
* _ActivationF_ => truncate _ROIActBrain_, resampled to _BrainF_, reset TR

## Pulse

## Motion 

## Activation time
