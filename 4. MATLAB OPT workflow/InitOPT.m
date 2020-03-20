function Config=InitOPT()
% This function sets the configurations for automated OPT workflow.
%
%%--------------------------------------------------------------------------
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
% Copyright 2020,  1. BioImage Informatics Facility at SciLifeLab,Sweden
%                  2. Division of Visual information and interaction, 
%                     Department of Information Technology, Uppsala university,Sweden
%
% License: The program is distributed under the terms of the GNU General 
% Public License v3.0
% Contact: Version 1.0 - first release, 20200207, zhanghq0088@gmail.com
% Website: https://github.com/Hq-Z/zOPT
%%--------------------------------------------------------------------------
if(~isdeployed)
    cPath=mfilename('fullpath');
    [GUIpath,~]=fileparts(cPath);
    lPath_f='functions';
    lPath_f=strcat(GUIpath,'\',lPath_f);
    if~exist((lPath_f),'dir')
        mkdir(lPath_f);
    end
    addpath(genpath(lPath_f));
end
% function: selectROI
Config.ROI.FixedArea=[128 1023]; % [Height Width]
% function: getOPTbG
Config.bG.nSample=5; % number of frames for generating background
% function: getOPT360
Config.find360.DownSamplingFactor=2; % Positive Integer
Config.find360.StartingFrame=1; % Positive Integer (candidate frame for searching 360 degrees rotation)
Config.find360.SafetyMargin=50; % Positive Integer (number of frames after the starting frame)
Config.OptAng=[]; % optimal angle interval
% function: iReg*
Config.RegCOR.AngValid=0;  % see getOPT360;
Config.RegCOR.Ang=[];      % see getOPT360;
Config.RegCOR.Iteration=10; % number of iterations for registration methods
Config.RegCOR.DefaultChannel=2; %
Config.RegCOR.Margin=20; % image template margin in pixels
Config.RegCOR.FillValue=0; % background pixels are 0
Config.RegCOR.OptSetOptions=optimset('TolFun',1e-4,'TolX',1e-4,'MaxIter',100,'Display','off');
% Save the data
Config.savePath='save\';
if~exist((Config.savePath),'dir')
    mkdir(Config.savePath);
end
Config.saveName=[];
Config.saveFormat='uint8'; % ! Save .vtk
Config.saveTextName='OPTLog.txt';
