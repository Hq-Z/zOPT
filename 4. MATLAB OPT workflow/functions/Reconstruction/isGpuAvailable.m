% isGpuAvailable: test if GPU is available on the current computer

% OK = isGpuAvailable

% Outputs:
%    OK - OK = 1 if GPU is available, 0 otherwise.

%--------------------------------------------------------------------------
% This file is part of the OPT InSitu Toolbox
%
% Copyright: 2017,  Researchlab of electronicss,
%                   Massachusetts Institute of Technology (MIT)
%                   Cambridge, Massachusetts, USA
% License: 
% Contact: a.allalou@gmail.com
% Website: https://github.com/aallalou/OPT-InSitu-Toolbox
%--------------------------------------------------------------------------

function OK = isGpuAvailable
try
    d = gpuDevice;
    OK = d.SupportsDouble;
catch
    OK = false;
end