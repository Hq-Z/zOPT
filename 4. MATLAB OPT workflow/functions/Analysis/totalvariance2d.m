function score=totalvariance2d(data3D)
score=zeros(1,size(data3D,3));
kernel1 = [-1 1 0];
kernel2 = [0 1 -1];
kernel3 = [-1 1 0]';
kernel4 = [0 1 -1]';
for i=1:size(data3D,3)
    diffImageLeft = imfilter(data3D(:,:,i), kernel1, 'replicate','same');
    diffImageRight = imfilter(data3D(:,:,i), kernel2, 'replicate','same');
    diffImageTop = imfilter(data3D(:,:,i), kernel3, 'replicate','same');
    diffImageBottom = imfilter(data3D(:,:,i), kernel4, 'replicate','same');
    score(i) = sum(sum(sqrt(diffImageLeft.^2 + diffImageRight.^2 + diffImageTop.^2 + diffImageBottom.^2)));
end
