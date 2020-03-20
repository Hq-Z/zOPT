function [RecAng,Xq,Yq]=CheckRotationDirection(RecIm,dataSino,Ang)
% This function finds the rotation direction by comparing the
% reconstructed frames with original frames using 2D correlation.
% Inputs:
%      RecIm: The #th slice of OPT reconstructed data
%      dataIm:The #th slice of ogirinal data sinogram
%      Ang: Angles used in the OPT reconstruction
% Outputs:
%      RecAng: Resultant Ang.
%      Xq,Yq: Template coordinates using radon function.
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
global  ComparingImg1 ComparingImg2  RefImg FillValue MarginR
[DataWidth,FullRev]=size(dataSino);
HalfWidth=floor(double(DataWidth)/2);

temp2D =RecIm;
tempR1 = radon(temp2D,Ang);
tempR2 = radon(temp2D,-Ang);
Center= double(size(tempR1,1))/2;
if mod(double(DataWidth),2)==1 % Check odd
    [Xq,Yq]=meshgrid(1:1:FullRev,Center-HalfWidth:1:Center+HalfWidth);
else
    [Xq,Yq]=meshgrid(1:1:FullRev,Center+0.5-HalfWidth:1:Center-0.5+HalfWidth);
end
Vq1 = interp2(tempR1,Xq,Yq);
Vq2 = interp2(tempR2,Xq,Yq);
ComparingSino1=Vq1;
ComparingSino2=Vq2;

CheckFramesList=[30 60 90]; %
options= optimset('TolFun',1e-6,'TolX',1e-6,'MaxIter',100,'Display','off');
fval1 = zeros(1,length(CheckFramesList));
fval2 = zeros(1,length(CheckFramesList));
FillValue=0;
MarginR=5;
for i=1:length(CheckFramesList)
    ComparingImg1= ComparingSino1(:,CheckFramesList(i));
    ComparingImg2= ComparingSino2(:,CheckFramesList(i));
    RefImg=dataSino(:,CheckFramesList(i));
    x = 0; % Init values
    [~,fval1(i)] = fminsearch(@TestY1,x,options);
    [~,fval2(i)] = fminsearch(@TestY2,x,options);
end
if(sum(fval1)<sum(fval2))
    RecAng=Ang;
else
    RecAng=-Ang;
end
end

function fval  = TestY1(x)
global ComparingImg1 RefImg FillValue MarginR
scale = 10000;
x=x.*scale;
I_shift = double(imtranslate(ComparingImg1,[0, x(1)],'FillValues',FillValue));
fval=1-corr(RefImg(1+MarginR:end-MarginR),I_shift(1+MarginR:end-MarginR));
end

function fval  = TestY2(x)
global ComparingImg2 RefImg FillValue MarginR
scale = 10000;
x=x.*scale;
I_shift = double(imtranslate(ComparingImg2,[0, x(1)],'FillValues',FillValue));
fval=1-corr(RefImg(1+MarginR:end-MarginR),I_shift(1+MarginR:end-MarginR));
end