function [ feat ] = features2(im,scale )
% Computes the HOG features of the image. 
% ARGUMENTS: 
% im			depth image for displacement feats
% scale			scale for HOG and displacement feats	
%
%
% Copyright (C) 2014 Grigorios Chrysos
% available under the terms of the Apache License, Version 2.0


if 0,                                       %feat rgb, feat hog separetely
    featRGB=features(im(:,:,1:3),scale);
    featD=features_only_depth(im(:,:,4),scale);

    % concatenate features: 
    ftrgb=shiftdim(featRGB,2);
    ftd=shiftdim(featD,2);
    ft=[ftrgb;ftd];
    feat=shiftdim(ft,1);
else
    feat=features_64(double(im),scale);
end


end

