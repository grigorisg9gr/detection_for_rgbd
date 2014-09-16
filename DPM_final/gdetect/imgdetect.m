function [ds, bs, trees,im] = imgdetect(im1, model, thresh,im2)
% Wrapper around gdetect.m that computes detections in an image.
%   [ds, bs, trees] = imgdetect(im, model, thresh)
%
% Return values (see gdetect.m)
%
% Arguments
%   im        Input image
%   model     Model to use for detection
%   thresh    Detection threshold (scores must be > thresh)

if nargin==4
    im(:,:,4)=im2; 
	im(:,:,1:3)=im1;
else
    im=im1; %default cases 
end
im = color(im);
pyra = featpyramid(im, model);
[ds, bs, trees] = gdetect(pyra, model, thresh);