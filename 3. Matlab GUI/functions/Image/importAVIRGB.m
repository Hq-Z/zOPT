% ImportAVIRGBCrop: Input all the frames and crop from a video file
%
% I = importAVIRGBCrop(VideoName)
% Inputs:
%    VideoName - the full directory of the video file
% Outputs:
%    I - 4D images (Height x Width x Frame Number x Color) containing 
%    all the frames.
%
% Authors: Hanqing Zhang, Amin Allalou.
%          Department of Information technology,Uppsala University, Sweden


function I = importAVIRGB(VideoName)
%IMPORTAVIRGB Import RGB *.avi file from OPT acquisition
% RGB images are stored as f(x,y,z,color)

readerobj = VideoReader(VideoName);
I = read(readerobj);
tmpI=I(:,:,1,1);
fh=figure(1)
imshow(tmpI(:,:,1,1));
% Update Preprocessing Region-of-interest
ROI=selectROI(tmpI,gca);
I = I (ROI(2):ROI(2)+ROI(4),ROI(1):ROI(1)+ROI(3),:,:);
close(fh);
I = permute(I(:,:,:,:),[1 2 4 3]);
end

