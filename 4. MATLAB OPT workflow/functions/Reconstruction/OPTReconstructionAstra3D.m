% OPTReconstructionAstra3D: Wrapper function for the tomography
% reconstruction functionality in the ASTRA tomography toolbox. the
% function reconstruct multiple slices.
% rec = OPTReconstructionAstra3D(sino,type,Angles)
% Inputs:
%    sino - The sinogram (Height x Slice x Frame Number)asscociated with
%           multiple slices
%    type - The type of the reconstruction algorithm to be used. Recommend
%           'fbp' for filtered backprojection.
%    Angles - The angles corresponding to the projection views in each
%           frame
% Outputs:
%    rec - the reconstructed 3D image
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

function rec = OPTReconstructionAstra3D(sino,type,Angles,varargin)
if(nargin>3)
    option=varargin{1};
else
    option='Default';
end
GPU=isGpuAvailable;
NrSlices = size(sino,2);
diago=size(sino,1);
if(strcmp(option,'diago'))
    N =  ceil(sqrt(diago^2/2));%
else
    N = diago;
end
rec=zeros(N,N,NrSlices);
for i=1:NrSlices
    
    sinoSlice=squeeze(sino(:,i,:,1));
    diago=size(sinoSlice,1);
    proj_geom = astra_create_proj_geom('parallel', 1.0, diago, Angles);
    % store sino
    vol_geom = astra_create_vol_geom(N, N);
    % Create a data object for the reconstruction
    rec_id = astra_mex_data2d('create', '-vol', vol_geom);
    sinogram_id = astra_mex_data2d('create','-sino', proj_geom, 0);
    astra_mex_data2d('set',sinogram_id,permute(sinoSlice,[2 1]));
    % create configuration
    if strcmp(type,'fbp')
        if ~GPU
            proj_id = astra_create_projector('strip', proj_geom, vol_geom);
            cfg = astra_struct('FBP');
            cfg.ProjectorId = proj_id;
        else
            cfg = astra_struct('FBP_CUDA');
        end
        cfg.FilterType = 'Ram-Lak';
        %cfg.FilterType = 'shepp-logan';
        %      cfg.FilterType = 'hamming';
        %      cfg.option.PixelSuperSampling=4;
    elseif strcmp(type,'cgls')
        cfg = astra_struct('CGLS_CUDA');
        cfg.option.MinConstraint =0;
    elseif strcmp(type,'sirt')
        cfg = astra_struct('SIRT_CUDA');
        %     cfg.option.MinConstraint =0;
    end
    cfg.ReconstructionDataId = rec_id;
    cfg.ProjectionDataId = sinogram_id;
    % Create and run the algorithm object from the configuration structure
    alg_id = astra_mex_algorithm('create', cfg);
    if strcmp(type,'cgls')
        astra_mex_algorithm('iterate', alg_id, 50);
    elseif strcmp(type,'sirt')
        astra_mex_algorithm('iterate', alg_id, 300);
    elseif strcmp(type,'fbp')
        astra_mex_algorithm('run', alg_id);
    end
    % Get the result
    rec(:,:,i,1) = astra_mex_data2d('get', rec_id);
    % Clear memory
    astra_mex_algorithm('delete', alg_id);
    astra_mex_data2d('delete', rec_id);
    astra_mex_data2d('delete', sinogram_id);
end
end

