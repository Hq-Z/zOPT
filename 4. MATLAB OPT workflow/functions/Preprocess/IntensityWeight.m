function weight=IntensityWeight(I)
weight=sum(I,3);
weight=sum(weight,1);
weight=weight./(max(weight(:))+eps);

