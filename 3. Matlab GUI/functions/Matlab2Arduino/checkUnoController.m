function valid=checkUnoController(s)
%%-------------------------------------------------------------------------
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
%%-------------------------------------------------------------------------
valid=0;
pause(2); % wait for controller to respond
while(s.BytesAvailable>0)
    out = fscanf(s);
    pause(0.05);
    out=regexprep(out,newline,'','ignorecase'); % enter
    out=regexprep(out,char(13),''); % end of the line
    if(~isempty(out))
        valid=1;
        disp(out);
    end
end

fprintf(s,'i');
pause(2);
while(s.BytesAvailable>0)
    out = fscanf(s);
    pause(0.05);
    out=regexprep(out,newline,'','ignorecase'); % enter
    out=regexprep(out,char(13),''); % end of the line
    if(~isempty(out))
        valid=1;
        disp(out);
    end
end
