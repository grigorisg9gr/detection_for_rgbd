function [ feat ] = features2(im,imrgbd,scale,flag_disp_fts,fsz,nrfts,interval_endpoints)
% Computes the HOG features of the image. If flag_disp_fts=1 (only for filter size image) it also
% computes the displacement feats and concatenates them.
% ARGUMENTS: 
% im			depth image for displacement feats
% imrgbd		rgb and depth image in MxNx4 
% scale			scale for HOG and displacement feats	
% fsz			filter size (for displacement feats)
% interval_endpoints	Endpoints so as to distinguish the interval that each difference belongs to (for displacement feats)
% nrfts			How many intervals we will have (for displacement feats)
%
%
% Copyright (C) 2014 Grigorios Chrysos
% available under the terms of the Apache License, Version 2.0



if flag_disp_fts
    im2=call_im2blocks(im, scale);
    featdisp=extract_displacement_feats_filter_size(im2,fsz,interval_endpoints,nrfts); % ONLY for im in filter size 
end

ftrgbd=features_64(double(imrgbd),scale);

% concatenate features if necessary
if flag_disp_fts
    sf=size(featdisp);shog=size(ftrgbd);           % trunc the displacement feats on the appropriate size
    if (sf(1)>shog(1))||(sf(2)>shog(2))
        featdisp=featdisp(1:shog(1),1:shog(2),:);
    end
    feat=cat(3,ftrgbd, featdisp);
else
    feat=ftrgbd;
end 
end



function newIm=call_im2blocks(im, sbin)
im=single(im);out=floor(size(im)/sbin);
newIm=im2blocks(single(im),sbin,out(1),out(2));
end




