function ROI=selectROI(Image,axes1_handle)
[FRAME_Height, FRAME_Width,~]=size(Image);
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