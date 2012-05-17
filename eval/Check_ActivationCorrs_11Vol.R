setwd(file.path(getMainDir(), "rs-fcMRI_Motion"))

library(fmri)
library(oro.nifti)
library(plyr)
origActiv15_scale1_gm244 <- "/Volumes/Serena/possum_speedup_tests_xsede/gitFromBlacklight/origactiv_first15.nii.gz" 
#possumSim10_scale1_gm244 <- "/Volumes/Serena/possum_speedup_tests_xsede/gitFromBlacklight/nbswktm_Brain_act1.5_15_zero_1.5_15_abs_trunc5_6_scale1_1mm_244GMMask.nii"
possumSim10_scale1_gm244 <- "/Volumes/Serena/rs-fcMRI_motion_simulation/10653_4dtemplate/simTestMay2012/nbswkmt_Brain_act1.5_15_zero_1.5_15_abs_trunc5_6_scale1_1mm_244GMMask.nii.gz"
spheres_int <- "/Volumes/Serena/rs-fcMRI_motion_simulation/10653_4dtemplate/mprage/10653_bb244_gmMask_fast.nii.gz"

origActiv15Mat <- readNIfTI(origActiv15_scale1_gm244)@.Data
possumSim10Mat <- readNIfTI(possumSim10_scale1_gm244)@.Data
spheresMat <- readNIfTI(spheres_int)@.Data
    
#origActiv15Mat <- extract.data(read.NIFTI(origActiv15_scale1_gm244))
#possumSim10 <- extract.data(read.NIFTI(possumSim10_scale1_gm244))

#obtain indices of non-zero voxels in first volume (will be the same for all other vols) 
origActivPresent <- which(origActiv15Mat[,,,1] != 0.0, arr.ind=TRUE)
simActivPresent <- which(possumSim10Mat[,,,1] != 0.0, arr.ind=TRUE)

origVols <- dim(origActiv15Mat)[4]
simVols <- dim(possumSim10Mat)[4]

#note that the orig is in 1.5s and contains 15 volumes (22.5 s)
#the sim is in 2.05s and contains 10 vols (20.5s)

#sanity check
identical(origActivPresent, simActivPresent)

#interpolate each TS to the same sampling rate
##one lead
##library(zoo)
##
##na.spline(x)
#
#
##simpler is seewave
targetSampFreq <- 1/1.0 #TR=1.0s
origTR <- 1.5
origFreq <- 1/origTR
simTR <- 2.05
simFreq <- 1/simTR

numsecs <- 19

resampTime <- seq(0, (numsecs-1)*targetSampFreq, by=targetSampFreq)
origTime <- seq(0, (origVols-1)*origTR, by=origTR)
simTime <- seq(0, (simVols-1)*simTR, by=simTR)

resampVoxMat <- array(NA, dim=c(2, nrow(origActivPresent), length(resampTime)), dimnames=list(orig_sim=c("orig", "sim"), vox=NULL, time=resampTime))

#simple linear interpolation here
for (i in 1:nrow(origActivPresent)) {
  resampVoxMat["orig",i,] <- approx(origTime, origActiv15Mat[cbind(pracma::repmat(origActivPresent[i,], origVols, 1), 1:origVols)], xout=resampTime)$y
  resampVoxMat["sim", i,] <- approx(simTime, possumSim10Mat[cbind(pracma::repmat(simActivPresent[i,], simVols, 1), 1:simVols)], xout=resampTime)$y
}

#and if that works, correlate each voxel time series between the original and sim.
voxCorr <- aaply(resampVoxMat, 2, function(suba) {
      cor(suba[1,], suba[2,])
    })

mean(voxCorr, na.rm=TRUE) #looks promising! :P

#try per-roi correlation
for (n in sort(unique((as.vector(spheresMat))))) {
  
}