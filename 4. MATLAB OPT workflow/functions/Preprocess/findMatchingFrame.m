function CorrMatchingFrame=findMatchingFrame(VideoIn,DownSamplingFactor,StartingFrame,SafetyMargin)
% CorrMatchingFrame=findMatchingFrame(VideoIn,DownSamplingFactor,StartingFrame,SafetyMargin)
% Inputs:
%           VideoIn : N*M*FrameNumVideoIn : N*M*FrameNum
%           DownSamplingFactor : positive integer n < min(N,M)
%           StartingFrame : positive integer 
%           SafetyMargin : positive integer 
% Output: CorrMatchingFrame: frame number of the best match image
% This code uses GPUs for calculation of correlation.
%
%--------------------------------------------------------------------------
% Please cite our paper:
% "zOPT: an open source Optical Projection Tomography system and methods for
% rapid 3D zebrafish imaging"
% HANQING ZHANG,LAURA WALDMANN,REMY MANUEL,TATJANA HAITINA,AND AMIN ALLALOU
%
% Copyright 2020,  1. BioImage Informatics Facility at SciLifeLab,Sweden
%                  2. Division of Visual information and interaction, 
%                     Department of Information Technology, Uppsala university,Sweden
%
% License: The program is distributed under the terms of the GNU General 
% Public License v3.0
% Contact: zhanghq0088@gmail.com
% Website: https://github.com/Hq-Z/zOPT
%--------------------------------------------------------------------------
if(ndims(VideoIn)~=3)  
   error('Input Video must be row*col*frame');
end
I=gpuArray(VideoIn(1:DownSamplingFactor:end,1:DownSamplingFactor:end,:)); % downsample
FrameNumTotal=size(I,3);
CorrCoef=gpuArray(zeros(1,FrameNumTotal)); 
if(StartingFrame<FrameNumTotal-SafetyMargin && SafetyMargin>0 && StartingFrame<FrameNumTotal+SafetyMargin)
    %disp(['Searching from frame ' num2str(StartingFrame+SafetyMargin) ' to ' num2str(FrameNumTotal)])
else
    StartingFrame=1;
    SafetyMargin=1;
    disp('OPT_find360: Inputs contains invalid numbers, changing to default values...')
    disp(['Searching from frame ' num2str(StartingFrame+SafetyMargin) 'to' num2str(FrameNumTotal)])
end

RefI=I(:,:,StartingFrame)-mean(mean(I(:,:,StartingFrame)));
for i=1:FrameNumTotal
    if any(i==StartingFrame-SafetyMargin:StartingFrame+SafetyMargin)
        CorrCoef(i) = 0;
    else
        CorrCoef(i)= corr2(I(:,:,i)-mean(mean(I(:,:,i))),RefI);
    end
end
[~, CorrMatchingFrame]=max(gather(CorrCoef));