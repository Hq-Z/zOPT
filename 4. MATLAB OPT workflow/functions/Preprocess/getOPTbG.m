function bG=getOPTbG(data,nsample)
% This function calculates OPT data background.
%
% Please refer to our paper for more details:
%
% "zOPT: an open source Optical Projection Tomography system and methods for
% rapid 3D zebrafish imaging"
% HANQING ZHANG,LAURA WALDMANN,REMY MANUEL,TATJANA HAITINA,AND AMIN ALLALOU
% 
% Authors information:
%   hanqing.zhang@it.uu.se
%   amin.allalou@it.uu.se
%
% Copyright 2020,  Department of Information Technology,
%                  Uppsala University, Sweden
%
% License: The program is distributed under the terms of the GNU General 
% Public License
% 
% Version 1.0 - first release, 20200207, zhanghq0088@gmail.com
%
% !! For details regarding inpaint_nans, please cite the following:
% John D'Errico (2020). inpaint_nans (https://www.mathworks.com/matlabcentral/fileexchange/4551-inpaint_nans), MATLAB Central File Exchange. Retrieved February 7, 2020.
KernelSize=101;
Iv=var(data,0,3);
Imin=min(data,[],3);
bG=zeros(size(data,1),size(data,2),nsample);
nsampleList=1:round(size(data,3)/nsample):size(data,3);
inc=1;
for i=nsampleList
    ftest=data(:,:,i);
    fdiff=double(ftest-Imin).*double(Iv);
    MASK=imbinarize(fdiff,1/10*mean(fdiff(:)));
    
    SE = strel('disk',13,8);
    MASK=imclose(MASK,SE);
    SE = strel('disk',15,8);
    MASK=imopen(MASK,SE);
    MASK=imfill(MASK,'holes');
    
    ftest(MASK) = NaN;
    bG_tmp = inpaint_nans(double(ftest),4);
    bG(:,:,inc) =imfilter(bG_tmp,fspecial('gaussian',[KernelSize KernelSize],KernelSize/3),'replicate');
    inc=inc+1;
end
bG=single(mean(bG,3));
bG=imfilter(bG,fspecial('gaussian',15),'replicate');