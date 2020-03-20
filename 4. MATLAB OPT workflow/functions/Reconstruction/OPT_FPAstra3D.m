function proj = OPT_FPAstra3D(vol,Angles,varargin)
% OPT_FPAstra3D: Wrapper function for the tomography
% reconstruction functionality in the ASTRA tomography toolbox. the
% function apply forward projection on volume slices.
% rec = OPTReconstructionAstra3D(sino,type,Angles)
% Inputs:
%    vol - The volumn (Width x Width x Slices)
%    Angles - The angles corresponding to the projection views in each
%           frame
% Outputs:
%    proj - the projection images
%--------------------------------------------------------------------------
% Please cite our paper:
% "zOPT: an open source Optical Projection Tomography system and methods for
% rapid 3D zebrafish imaging"
% HANQING ZHANG,LAURA WALDMANN,REMY MANUEL,TATJANA HAITINA,AND AMIN ALLALOU
%
% Copyright 2020,  1. BioImage Informatics Facility at SciLifeLab,Sweden
%                  2. Division of Visual information and interaction, 
%                     Department of Information Technology, Uppsala university,Sweden
%
% License: The program is distributed under the terms of the GNU General 
% Public License v3.0
% Contact: zhanghq0088@gmail.com
% Website: https://github.com/Hq-Z/zOPT
%--------------------------------------------------------------------------
if(nargin>2)
    N = varargin{1};
else
    N = size(vol,1);
end
volN=size(vol,1);
GPU=isGpuAvailable;
NrSlices = size(vol,3);
proj=single(zeros(length(Angles),N,NrSlices));
for i=1:NrSlices 
    V=vol(:,:,i);
    %% create geometries
    proj_geom = astra_create_proj_geom('parallel', 1.0, N, Angles);
    vol_geom = astra_create_vol_geom(volN,volN);
    %% store volume
    volume_id = astra_mex_data2d('create', '-vol', vol_geom, V);
    %% create forward projection
    sinogram_id = astra_mex_data2d('create', '-sino', proj_geom, 0);
    if ~GPU
        cfg = astra_struct('FP');
    else
        cfg = astra_struct('FP_CUDA');
    end
    cfg.ProjectionDataId = sinogram_id;
    cfg.VolumeDataId = volume_id;
    fp_id = astra_mex_algorithm('create', cfg);
    astra_mex_algorithm('run', fp_id);
    proj(:,:,i) = astra_mex_data2d('get', sinogram_id);
    
    %% garbage disposal
    astra_mex_data2d('delete', sinogram_id, volume_id);
    astra_mex_algorithm('delete', fp_id);
end
proj=permute(proj,[2 3 1]);