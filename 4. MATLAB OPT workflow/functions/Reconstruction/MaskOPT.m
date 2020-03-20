% Mask: Generate a disk shaped mask around the center


% IMask=MaskOPT(I,d)
% Inputs:
%    I - a 2D image whose size defines the output size of the mask
%    d - the distance between the edge of the disk shaped region and 
%    the boudary of the mask 

% Outputs:
%    Imask - a binary mask with a disk shaped region at the center.


%--------------------------------------------------------------------------
% This file is part of the OPT InSitu Toolbox
%
% Copyright: 2017,  Researchlab of electronicss,
%                   Massachusetts Institute of Technology (MIT)
%                   Cambridge, Massachusetts, USA
% License: 
% Contact: origianl version: a.allalou@gmail.com
%          modified version: 20191216, zhanghq0088@gmail.com
% Website: https://github.com/aallalou/OPT-InSitu-Toolbox
%--------------------------------------------------------------------------



function   IMask=MaskOPT(I,d)
% Generate a mask of size size(I,1)xsize(I,2). The  mask is a centered
% circle disk,and the disk edge is d pixel away from the mask boudary

[r, c, ~]=size(I);
cpx=ceil(r/2);
cpy=ceil(c/2);
cpr = min(cpx,cpy);
Radius2=(cpr-d)^2;
[X,Y]=meshgrid(1:1:r,1:1:c);
IMask=(X-cpx).*(X-cpx)+(Y-cpy).*(Y-cpy)>Radius2;
end

