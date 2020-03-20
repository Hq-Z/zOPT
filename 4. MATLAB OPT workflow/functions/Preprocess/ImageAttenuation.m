function I_nonz=ImageAttenuation(I)
% the attenuation image: logarithm of the background corrected image
I_nonz=I; %! avoid zeros
if(min(I_nonz(:))<0)
    I_nonz=1-log(I_nonz-min(I_nonz(:)));
else
    I_nonz=1-log(I_nonz);
end
I_nonz(isinf(I_nonz))=NaN;
I_nonz=real(I_nonz);
I_nonz(isnan(I_nonz))=max(I_nonz(:));
NormV=zeros(1,size(I_nonz,3));
for i=1:size(I_nonz,3)
    %I_nonz(:,:,i) = inpaint_nans(double(I_nonz(:,:,i)),1);
    NormV(i)=1/max(max(I_nonz(:,:,i)));
end
MN=min(NormV);
I_nonz=single(I_nonz*MN);
