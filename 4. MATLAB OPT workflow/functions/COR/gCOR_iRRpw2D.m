function [reconstructI,sinoiRRpw]=gCOR_iRRpw2D(sinoIn,Ang,phantomsize,phantonProjectionsize,Config,varargin)
% This function correct COR errors and reconstruct tomography data using FBP
% method.
%
% Inputs: sinoIn - A 2D sinogram (n*m) containing n pixels 1D projection
%                data with m columns(frames).
%         Ang  - Angle for each frame. Note that the Ang must be in range
%                [0 360].
%
%         phantomsize - sample size in pixels.
%
%         phantonProjectionsize - the template size for sample after
%         radon transform. It must be larger than (sample size)*2^(0.5).
%
%         Config - Algorithm 
%
%         varargin - check if a groundtruth is available for comparison.
%                    I_objStatic=varargin(1);
%
% Outputs: reconstructI - FBP results (2D) after COR correction
%       
%          sinoiRRpw - sinogram after COR correction based on iRRpw method
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
Debug_=1;
DebugPath=Config.savePath;
disp(' ');
if(nargin>5)
    I_objStatic=varargin{1};
else
    disp('No groudtruth available.')
end
% Settings
global FillValue refIm testIm MarginR halfPeriod
halfPeriod=floor(length(Ang)/2);
FullPeriod=2*halfPeriod; % ! force to even number
MarginR=Config.RegCOR.Margin;
FillValue = Config.RegCOR.FillValue;
options   = Config.RegCOR.OptSetOptions;
% Debug and analysis
DebugPlotNum=Config.RegCOR.Iteration+1; %
saveSAD=zeros(1,2+Config.RegCOR.Iteration); % original+Gip+iRec
saveTV=zeros(1,2+Config.RegCOR.Iteration);
% Analysis of input sinogram
reconstructI=iradon(sinoIn,Ang,phantomsize);
tvEr_1=totalvariance2d(reconstructI);
OutputTestIm=Register2ImageRigid(I_objStatic,reconstructI);
res_absdiffs = imabsdiff(OutputTestIm(1+MarginR:end-MarginR,1+MarginR:end-MarginR),I_objStatic(1+MarginR:end-MarginR,1+MarginR:end-MarginR));
SADEr_1=sum(res_absdiffs(:));
saveSAD(1)= SADEr_1;
saveTV(1)=  tvEr_1;
if(Debug_==1)
    writeName=strcat(DebugPath,'Data_In_',num2str(tvEr_1,'%3.5e'),'_',num2str(SADEr_1,'%3.5e'),'.png');
    writeNamePrint=strcat(DebugPath,'P_Data_In_',num2str(tvEr_1,'%3.5e'),'_',num2str(SADEr_1,'%3.5e'),'.png');
    imwrite(OutputTestIm,writeName,'PNG');
    h=figure();
    imshowpair(ImageNorm(OutputTestIm),ImageNorm(I_objStatic))
    set(gcf,'units','points','position',[10,10,size(reconstructI,1),size(reconstructI,2)])
    print(writeNamePrint,'-dpng')
    close(h);
end
%% Step.1 Correction for constant shift
disp('Correcting constant shift');
MIP=sum(sinoIn,2);
testIm=MIP;
H_shift_init = 0;
H_shift = fminsearch(@GipY,H_shift_init,options);
scale = 10000/2;
H_Global    = H_shift.*scale;
sinoConst=zeros(size(sinoIn));
for i=1:FullPeriod
    sinoConst(:,i) = imtranslate(sinoIn(:,i),[0 H_Global(1)],'FillValues',FillValue);
end
reconstructI=iradon(sinoConst,Ang,phantomsize);
tvEr_1=totalvariance2d(reconstructI);
OutputTestIm=Register2ImageRigid(I_objStatic,reconstructI);
res_absdiffs = imabsdiff(OutputTestIm(1+MarginR:end-MarginR,1+MarginR:end-MarginR),I_objStatic(1+MarginR:end-MarginR,1+MarginR:end-MarginR));
SADEr_1=sum(res_absdiffs(:));
saveSAD(2)= SADEr_1;
saveTV(2)=  tvEr_1;
if(Debug_==1)
    writeName=strcat(DebugPath,'Data_S1_',num2str(tvEr_1,'%3.5e'),'_',num2str(SADEr_1,'%3.5e'),'.png');
    writeNamePrint=strcat(DebugPath,'P_Data_S1_',num2str(tvEr_1,'%3.5e'),'_',num2str(SADEr_1,'%3.5e'),'.png');    
    imwrite(OutputTestIm,writeName,'PNG');
    h=figure();
    imshowpair(ImageNorm(OutputTestIm),ImageNorm(I_objStatic))
    set(gcf,'units','points','position',[10,10,size(reconstructI,1),size(reconstructI,2)])
    print(writeNamePrint,'-dpng')
    close(h);
end
disp(['Corrected COR error : ' num2str(H_Global(1))  ' pixels in vertical direction.']);
%% Step.2 Correction for shift in each frame
figure('name','Correction for random motion')
subplot(3,DebugPlotNum,1)
reconstructI=iradon(sinoConst,Ang,phantomsize);
imshow(reconstructI)
tvER_1=totalvariance2d(reconstructI);
title(['tv : ' num2str(tvER_1,'%3.3e') '  , ' ])
subplot(3,DebugPlotNum,1+DebugPlotNum)
imshowpair(reconstructI,I_objStatic)
res_absdiffs = imabsdiff(reconstructI,I_objStatic);
sadER_2=sum(res_absdiffs(:));
title(['sum of abs diff : ' num2str(sadER_2,'%3.3e') '  , ' ])
OutputTestIm=Register2ImageRigid(I_objStatic,reconstructI);
subplot(3,DebugPlotNum,1+2*DebugPlotNum)
imshowpair(OutputTestIm,I_objStatic)
res_absdiffs = imabsdiff(OutputTestIm(1+MarginR:end-MarginR,1+MarginR:end-MarginR),I_objStatic(1+MarginR:end-MarginR,1+MarginR:end-MarginR));
sadER_3=sum(res_absdiffs(:));
title(['sum of abs diff : ' num2str(sadER_3,'%3.3e') '  , ' ])
disp('Standard reconstruction method for motion correction');
for j=1:Config.RegCOR.Iteration
    disp(['Iteration : ' num2str(j)]);
    if(j==1)
        sinoLoop= sinoConst;
    end
    %%  Reconstructions and Projections
    I_Reconstruct = iradon(sinoLoop,Ang,round(phantonProjectionsize/2^(1/2)));
    sinoProjections=zeros(phantonProjectionsize,360);
    for i=1:FullPeriod
        Rotatetemp=imrotate(I_Reconstruct,-Ang(i),'crop');
        temp=imtranslate(Rotatetemp,[0 0]);
        sinoProjections(:,i)=radon(temp,0,phantonProjectionsize);
    end
    %% Correct shifts
    sinoRec=zeros(size(sinoIn));
    for i=1:FullPeriod
        testIm = sinoConst(:,i);
        refIm  = sinoProjections(:,i);
        H_shift_init = 0; % Init values
        H_shift = fminsearch(@iRegY,H_shift_init,options);
        scale = 10000;
        Hlocal    = H_shift.*scale;
        sinoRec(:,i) = imtranslate(sinoIn(:,i),[0 Hlocal(1)+H_Global],'FillValues',FillValue);
    end
    %% Correct paris
    sinoiRRpw=zeros(size(sinoIn));
    for i=1:halfPeriod
        refIm  = sinoRec(:,i);
        testIm = sinoRec(:,i+halfPeriod);
        H_shift_init = 0; % Init values
        H_shift = fminsearch(@PairY,H_shift_init,options);
        scale = 10000/2;
        Hlocal2    = H_shift.*scale;
        sinoiRRpw(:,i) = imtranslate(sinoRec(:,i),[0 Hlocal2(1)],'FillValues',FillValue);
        sinoiRRpw(:,i+halfPeriod) = imtranslate(sinoRec(:,i+halfPeriod),[0 Hlocal2(1)],'FillValues',FillValue);
    end
    sinoLoop=sinoiRRpw;
    
    subplot(3,DebugPlotNum,j+1)
    reconstructI=iradon(sinoiRRpw,Ang,phantomsize);
    imshow(reconstructI)
    tvER_1=totalvariance2d(reconstructI);
    title(['tv : ' num2str(tvER_1,'%3.3e') '  , ' ])
    subplot(3,DebugPlotNum,j+DebugPlotNum+1)
    imshowpair(reconstructI,I_objStatic);
    res_absdiffs = imabsdiff(reconstructI(1+MarginR:end-MarginR,1+MarginR:end-MarginR),I_objStatic(1+MarginR:end-MarginR,1+MarginR:end-MarginR));
    sadER_2=sum(res_absdiffs(:));
    title(['sum of abs diff : ' num2str(sadER_2,'%3.3e') '  , ' ])
    OutputTestIm=Register2ImageRigid(I_objStatic,reconstructI);
    subplot(3,DebugPlotNum,j+2*DebugPlotNum+1)
    imshowpair(OutputTestIm,I_objStatic)
    res_absdiffs = imabsdiff(OutputTestIm(1+MarginR:end-MarginR,1+MarginR:end-MarginR),I_objStatic(1+MarginR:end-MarginR,1+MarginR:end-MarginR));
    sadER_3=sum(res_absdiffs(:));
    title(['sum of abs diff : ' num2str(sadER_3,'%3.3e') '  , ' ])
    if(Debug_==1)
        writeName=strcat(DebugPath,'Data_S2_i',num2str(j),'_',num2str(tvER_1,'%3.5e'),'_',num2str(sadER_3,'%3.5e'),'.png');
        writeNamePrint=strcat(DebugPath,'P_Data_S2_i',num2str(j),'_',num2str(tvER_1,'%3.5e'),'_',num2str(sadER_3,'%3.5e'),'.png');
        imwrite(OutputTestIm,writeName,'PNG');
        h=figure();
        imshowpair(ImageNorm(OutputTestIm),ImageNorm(I_objStatic))
        set(gcf,'units','points','position',[10,10,size(reconstructI,1),size(reconstructI,2)])
        print(writeNamePrint,'-dpng')
        close(h);
    end
    saveSAD(2+j)= sadER_3;
    saveTV(2+j)=  tvER_1;
end
if(Debug_==1)
    data2Save=[saveSAD'  saveTV'];
    filename = strcat(DebugPath,'Template_',num2str(size(OutputTestIm),1),'.xlsx');
    xlswrite(filename,data2Save,'Results');
end
% Maskout artifects
reconstructI(reconstructI<0)=0;
IMask=MaskOPT(reconstructI(:,:,1),Config.RegCOR.Margin);
reconstructI(IMask)=0;
end

function fval  = GipY(x)
global FillValue testIm MarginR
scale = 10000;
x=x.*scale;
I_180 = imtranslate(testIm,[0, x(1)],'cubic','FillValues',FillValue);
I_180 = flipdim(I_180,1);
fval=1-corr(testIm(1+MarginR:end-MarginR),I_180(1+MarginR:end-MarginR));
end

function fval  = PairY(x)
global FillValue refIm testIm MarginR
scale = 10000;
x=x.*scale;
I_180 = imtranslate(testIm,[0 x(1)],'cubic','FillValues',FillValue);
I_180 = flipdim(I_180,1);
fval=-corr(refIm(1+MarginR:end-MarginR),I_180(1+MarginR:end-MarginR));
end

function fval  = iRegY(x)
global FillValue refIm testIm MarginR
scale = 10000;
x=x.*scale;
I_shift = double(imtranslate(testIm,[0, x(1)],'cubic','FillValues',FillValue));
%I_shift = flipud(I_shift);
I_shift=I_shift-mean(I_shift(:));
refIm_Shift=double(refIm)-mean(double(refIm(:)));
fval=-corr(refIm_Shift(1+MarginR:end-MarginR),I_shift(1+MarginR:end-MarginR));
end


function fval  = MatchY(x)
global FillValue refIm testIm MarginR
scale = 10000;
x=x.*scale;
I_180 = imtranslate(testIm,[0, x(1)],'cubic','FillValues',FillValue);
I_sym = double(refIm(1+MarginR:end-MarginR))+double(I_180(1+MarginR:end-MarginR));
fval=-var(I_sym(:));
end
