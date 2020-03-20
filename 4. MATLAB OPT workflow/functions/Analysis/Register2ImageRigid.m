function OutputTestIm=Register2ImageRigid(InputRefIm,InputTestIm)
% This function apply 2D image intensity registration using rigid transform.
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
global FillValue refIm testIm MarginR
options   = optimset('TolFun',1e-6,'TolX',1e-6,'MaxIter',100,'Display','off');
FillValue=0;
MarginR=10;
refIm=InputRefIm;
testIm=InputTestIm;
x = [0 0 0]; % Init values
X = fminsearch(@MatchXYR,x,options);
scale = [10000 10000 10000];
xf    = X.*scale;
testIm = imtranslate(testIm,[xf(1) xf(2)],'cubic','FillValues',FillValue);
OutputTestIm = imrotate(testIm,xf(3),'crop');
end

function fval  = MatchXYR(x)
global FillValue refIm testIm MarginR
scale = [10000 10000 10000];
x=x.*scale;
I_180 = imtranslate(testIm,[x(1), x(2)],'FillValues',FillValue);
I_180 = imrotate(I_180,x(3),'crop');
fval=1-corr2(refIm(MarginR:end-MarginR,MarginR:end-MarginR),I_180(MarginR:end-MarginR,MarginR:end-MarginR));
end