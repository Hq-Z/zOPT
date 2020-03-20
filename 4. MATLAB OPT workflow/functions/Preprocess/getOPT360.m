function [data,FramesInOnePeriod,Angles]=getOPT360(data,Config)
% This functions finds optimal frame number for 360 degrees rotation in OPT
% data and calculates the angle for each frame.
%   
% Inputs: data - n*m*i 
%
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
TotalFrameNum=size(data,3);
CorrMatchingFrame=findMatchingFrame(data,Config.DownSamplingFactor,1,Config.SafetyMargin);
FrameMargin=1;
TestFrames=10;
while(TestFrames>5+1)
    TestFrames=TotalFrameNum-CorrMatchingFrame-2*FrameMargin;
    if(TestFrames<=0)
        TestFrames=0;
        break;
    end
    FrameMargin=FrameMargin+1;
end
if(TestFrames>0)
    FramesInOneRev=zeros(1,2*TestFrames);
    for i=1:TestFrames
        FramesInOneRev(2*i-1) = findMatchingFrame(data,Config.DownSamplingFactor,i+FrameMargin,Config.SafetyMargin);
        FramesInOneRev(2*i) = findMatchingFrame(flip(data,3),Config.DownSamplingFactor,i+FrameMargin,Config.SafetyMargin);
        FramesInOneRev(2*i-1) =FramesInOneRev(2*i-1) -FrameMargin-i;
        FramesInOneRev(2*i) =FramesInOneRev(2*i) -FrameMargin-i;
    end
else
    error('getOPT360: Need more frames for calculation.')
end
MinFrameInOneRev=min(FramesInOneRev);
MaxFrameInOneRev=max(FramesInOneRev);
MedianFrameInOneRev=median(FramesInOneRev);
% Choose the starting frame
PositionList=FrameMargin+1:1:FrameMargin+TestFrames;
PositionList = repelem(PositionList,2);
FramePosition=find(abs(FramesInOneRev-MedianFrameInOneRev)<=round(std(FramesInOneRev)));
if(isempty(FramePosition))
    FramesInOneRev
    error('getOPT360: Failed finding one revolution.')
end
StartingFrame=PositionList(FramePosition(round(length(FramePosition)/2)));
disp(['Starting frame at : ' num2str(StartingFrame)])
global colSelected data_FullLength FN360
inc=1;
AngVariation=1; % extra angle range corresponding to frames 
OneRevList=MinFrameInOneRev:1:MaxFrameInOneRev;
OPTI = optimset('MaxIter',100,'TolFun',1e-5,'TolX',1e-5,'Display','off');%
for i=OneRevList
    % Choose slices using intensity
    if(StartingFrame+i-1>size(data,3))
       break; 
    end
    data_FullLength = data(:,:,StartingFrame:1:StartingFrame+i-1);
    SliceWeight=IntensityWeight(data_FullLength);
    [~,Intensity_Index]=sort(SliceWeight,'descend');
    selectedNum=10;
    colSelected=Intensity_Index(1:selectedNum);
    % Define upper and lower bound for guassian kernel variance search
    FN360=i;
    lb=360/(FN360+1+AngVariation);
    ub=360/(FN360-AngVariation);
    [dk(inc),fval(inc)] = fminbnd(@optTVMultiSlices,lb,ub,OPTI);
    inc=inc+1;
end
OptFval = find(fval==min(fval));
OptRevFrames = OneRevList(OptFval);
sInterval = dk(OptFval);
% Force even number
FN360=2*floor(OptRevFrames/2);
Angles=(0:FN360-1)*sInterval;

if(mod(OptRevFrames,2)==1)
    FramesInOnePeriod=OptRevFrames-1;
else
    FramesInOnePeriod=OptRevFrames;
end
global FillValue refIm testIm MarginR
refIm=data(:,:,StartingFrame);
testIm=data(:,:,StartingFrame+FramesInOnePeriod);
MarginR=20; %(maximum motion)
FillValue=mean(mean((single(data(1,:,:))+single(data(end,:,:)))/2));
x=[0 0]; % Init values
options = optimset('TolFun',1e-5,'TolX',1e-5,'MaxIter',200,'Display','off');
X = fminsearch(@MotionR,x,options);
scale = [10000 10000];
xf=X.*scale;
Xestimate=xf(1);
Yestimate=xf(2);
if(Xestimate~=0)
    x_translate=0:Xestimate/FramesInOnePeriod:Xestimate;
else
    x_translate=zeros(1,FramesInOnePeriod);
end
if(Yestimate~=0)
    y_translate=0:Yestimate/FramesInOnePeriod:Yestimate;
else
    y_translate=zeros(1,FramesInOnePeriod);
end
for i=StartingFrame:StartingFrame+FramesInOnePeriod-1 % start from the second frame
    data(:,:,i)=imtranslate(data(:,:,i),[x_translate(i-StartingFrame+1) y_translate(i-StartingFrame+1)],'FillValues',FillValue);
end
data=data(:,:,StartingFrame:StartingFrame+FramesInOnePeriod-1);
end
function fval  = optTVMultiSlices(dt)
global FN360 data_FullLength colSelected;
Angles=-(0:FN360-1)*dt;
fval=zeros(1,length(colSelected));
% reconstruct the sampled slices
for i=1:length(colSelected)
    Recon_I= OPTReconstructionAstra3D(data_FullLength(:,colSelected(i),:),'fbp',Angles/360*2*pi);
    fval(i)=sum(totalvariance2d(Recon_I));
end
fval=sum(fval);
end
function fval  = MotionR(x)
global FillValue refIm testIm MarginR
scale = [10000 10000];
x=x.*scale;
I_translate = imtranslate(testIm,[x(1), x(2)],'FillValues',FillValue);
fval=1-corr2(refIm(MarginR:end-MarginR,MarginR:end-MarginR),I_translate(MarginR:end-MarginR,MarginR:end-MarginR));
end

