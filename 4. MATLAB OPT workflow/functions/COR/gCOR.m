function [Iout,data]=gCOR(data,Config,FBPoutput)
% This function is a demonstration of gCOR algorithm to correct COR errors
% and reconstruct tomography data using FBP method. This function requires 
% CUDA decives for parallel computing.
% Important: This implementation is verified using MATLAB R2018b (academic use)
%
% Inputs: sinoI - A 3D sinogram (n*m*i) containing n pixels in vertical 
%                 direction and m pixels in horizontal direction, i frames. 
%
%                 IMPORTANT: The rotation axis is along the horizontal axis.
%
%         Config - Configurations for this function.see InitOPT for more
%         details
%
%         FBPoutput - if FBPoutput==1, Apply FBP method and output reconstruction results to
%                     Iout. if FBPoutput==0, Iout=[];
%
% Outputs: Iout (optional) - FBP results (3D) after COR correction
%       
%          data - (n*m*i) data after COR correction
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
disp('Gip:');
global FillValue testIm MarginR halfPeriod
[DataWidth,ColSlices,FullRev,ColorChannel]=size(data);
if(ColorChannel~=1)
    data=data(:,:,:,Config.DefaultChannel);
    disp(['ReconstructionbasedCOR: Select channel ', num2str(Config.DefaultChannel) ' by default.']);
end
if(Config.AngValid==1) % ! More info go to: getOPT360.
    Ang=Config.Ang;
    halfPeriod = floor(length(Ang)/2); 
else
    AgnRes=360/FullRev;
    Ang=(1:FullRev)*AgnRes-AgnRes;
    halfPeriod=length(Ang)/2;
    disp(['ReconstructionbasedCOR: Test images contains : ' num2str(length(Ang)) ' frames with resolution of ' num2str(AgnRes) ' degrees/frame.']);
end
MarginR = Config.Margin;
FillValue = Config.FillValue;
%% Global method for COR correction
MIP=sum(data,3);
testIm=MIP;
x=[0 0 0]; % Init values
X = fminsearch(@SelfSymY3D,x);
scale = [10000 10000 10000]/2;
CorrectionXYR=X.*scale;
for i=1:2*halfPeriod
    temp = imtranslate(data(:,:,i),[CorrectionXYR(1), CorrectionXYR(2)],'FillValues',FillValue);
    data(:,:,i) = imrotate(temp,CorrectionXYR(3),'crop');
end
if(FBPoutput==1)
    disp('ReconstructionbasedCOR: Applying FBP reconstruction');
    Iout=single(zeros(size(data,1),size(data,1),size(data,2)));
    for i=1:ColSlices
        gpuArraySlice=gpuArray(permute(data(:,i,:),[1 3 2]));
        Iout(:,:,i) = gather(iradon(gpuArraySlice,Ang,DataWidth));
    end
    Iout(Iout<0)=0;
    % Maskout artifects
    IMask=MaskOPT(Iout(:,:,1),Config.Margin);
    Iout(repmat(IMask,[1 1 ColSlices]))=0;
else
    Iout=[];
end
end
function fval  = SelfSymY3D(x)
global FillValue testIm MarginR
scale = [10000 10000 10000];
x=x.*scale;
I_mirror = imtranslate(testIm,[x(1), x(2)],'FillValues',FillValue);
I_mirror = imrotate(I_mirror,x(3),'bilinear','crop');
I_mirror = flipdim(I_mirror,1);
fval=1-corr2(testIm(MarginR:end-MarginR,MarginR:end-MarginR),I_mirror(MarginR:end-MarginR,MarginR:end-MarginR));
end
