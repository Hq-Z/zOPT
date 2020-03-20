function ROI=selectROI(Image,Config,axes1_handle)
% This function is for selecting region-of-interest in a image.
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
[FRAME_Height, FRAME_Width,~]=size(Image);
if(Config.FixedArea(1)<FRAME_Height && Config.FixedArea(2)<FRAME_Width)
    try
         ROI_pre=dlmread('roiPosition.txt'); 
         if(ROI_pre(2)+ROI_pre(4)<=FRAME_Height && ROI_pre(1)+ROI_pre(3)<=FRAME_Width)
             disp('Load ROI from file.')
         else
             disp('Previous measurement exceed the maximum dimension. New ROI is applied.')
             ROI_pre=[1 1 Config.FixedArea(2) Config.FixedArea(1)];
         end
    catch
         disp('Cannot load from the previous measurement.')
         ROI_pre=[1 1 Config.FixedArea(2) Config.FixedArea(1)];
    end
    h = imrect(axes1_handle, ROI_pre);
    addNewPositionCallback(h,@(p) title(mat2str(p,3)));
    fcn = makeConstrainToRectFcn('imrect',get(gca,'XLim'),get(gca,'YLim'));
    setPositionConstraintFcn(h,fcn)
    position = wait(h);
    if(position(1)>1)
        position(1)=floor(position(1));
    else
        position(1)=1;
    end
    if(position(2)>1)
        position(2)=floor(position(2));
    else
        position(2)=1;
    end
    ROI=uint32(position);
    dlmwrite('roiPosition.txt',ROI,'delimiter','\t');
    delete(h);
else
    hrect = imrect(axes1_handle, [1   1  FRAME_Width-1 FRAME_Height-1]);
    setResizable(hrect,1)
    ROI=[1   1  FRAME_Height-1 FRAME_Width-1];
    try
        position = wait(hrect); % Double click
        if(isempty(position))
            return;
        end
        if(position(2)<1 || position(2)>=FRAME_Height)
            position(4)=position(4)-abs(position(2));
            position(2)=1;
        end
        if(position(1)<1 || position(1)>=FRAME_Width)
            position(3)=position(3)-abs(position(1));
            position(1)=1;
        end
        if(position(2)+position(4)>FRAME_Height || position(4)<=0)
            position(4)=FRAME_Height-position(2);
        end
        if(position(1)+position(3)>FRAME_Width || position(3)<=0)
            position(3)=FRAME_Width-position(1);
        end
        ROI=uint32(position);
    catch
        disp('The selection of region-of-interest is cancled.') ;
    end
    delete(hrect);
end
end