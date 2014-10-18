function [imOut, imDOut] = render_raw_image(im,imD,imD_inp, ts,a,filterlg )
% Creates a new (rendered) image based on the original (RGB, depth) and a set of parameters. 
% ARGUMENTS: 
% im    		rgb image (uint8 format)
% imD   		depth image (uint16 format)
% ts    		render angle (typo: atan(ts/2/Zc)*360/(2*pi) % =a/2) ) 
% a     		instristic parameter of the camera 
% filterlg  		(optional) if 1 then it applies a gaussian to the depth image before rendering (default 0)
%
%
% Copyright (C) 2014 Grigorios Chrysos
% available under the terms of the Apache License, Version 2.0 

if nargin<5
    filterlg=0;
end

imD2=imD;
if filterlg % apply the filter
    myfilter = fspecial('gaussian',[4 4], 4);
    imD = imfilter(imD, myfilter, 'replicate');%figure(),imshow(imD);
end
imD=double(imD);
Zc=10; 

inpaintedNYU=abs(imD-imD_inp)>0.5;
[r,c]=find(inpaintedNYU);

render=1;render1=render*a*ts/2; render2=1/Zc;
[imNew, imNewD]=horizontal_rendering_reliable(im,imD2,imD,render1,render2);
%imNew_in=imNew;imNewD_in=imNewD;
[imNew, imNewD]=horizontal_rendering_unreliable(imNew,im,imNewD,imD_inp,render1,render2,r,c);

imNew2 = medfilt2(imNewD, [3 3]);
cracks=(abs(double(imNewD)-double(imNew2))>0.5)&(imNewD==0);

% [imNew_o,imNewD2]=fix_disocclusions_slow(imNew,imNewD, cracks);

kernel = [1 1 1; ...                      % Convolution kernel
          1 0 1; ...
          1 1 1];
imNewD1=fix_disocclusions(imNewD,imNewD,kernel);
imNewD1(imNewD==0&~cracks)=0;
imNew1=zeros(size(imNew), 'uint8');
for ii=1:3
    tt=fix_disocclusions(double(imNew(:,:,ii)),imNewD,kernel);
    tt(imNewD==0&~cracks)=0;
    imNew1(:,:,ii)=uint8(round(tt));
end

imOut=imNew1;
imDOut=imNewD1;

end



function [imNew,imNewD]=horizontal_rendering_reliable(im,imDorg, imD,render1,render2)
% gia orizontia metatopisi me reliable only points
% INPUT: 
% im 		original RGB image 
% imDorg	original Depth image
% imD 		depth image (potentially pre-filtered with gaussian) 
% render1	parameter1 -> depends on the angle we want to succeed
% render2  	param2 -> 1/Zc=1/70000
imNew=zeros(size(im), 'uint8');
imNewD=zeros(size(imDorg), 'double');
s1=size(imNew,1); s2=size(imNew,2); 
for cnt=1:s1
    for j=1:s2
        if (imD(cnt,j)==0)
            continue;
        end
        Z=imD(cnt,j);
        new_place=round(j+render1*(1/Z-render2));
        if (new_place>0)&&(new_place<=s2)
             imNew(cnt,new_place,:)=im(cnt,j,:);
             imNewD(cnt,new_place)=imDorg(cnt,j);
        end
    end
end


end

function [im,imDN]=horizontal_rendering_unreliable(im,imOrg, imDN, imD,render1,render2,r,c)
% gia orizontia metatopisi me reliable only points
%render: -1 gia deksia apospi, +1 gia aristeri
s2=size(im,2); 

for cnt=1:size(r,1)
    Z=imD(r(cnt),c(cnt));
    new_place=round(c(cnt)+render1*(1/Z-render2));
    if (new_place>0)&&(new_place<=s2)&&(imDN(r(cnt),new_place)==0)
         im(r(cnt),new_place,:)=imOrg(r(cnt),c(cnt),:);
         imDN(r(cnt),new_place)=imD(r(cnt),c(cnt));
    end
end


end


function [imNew,imNewD]=fix_disocclusions_slow(imNew,imNewD, mask)
% aux function that assigns the mean of a square filter in disoccluded
% points
% mask -> maska i opoia mas leei se poia simeia "epitrepetai" na gemisoyme
% ta simeia
s1=size(imNew,1); s2=size(imNew,2); 
zero1=find(imNewD(:,:)==0);
for cnt=1:size(zero1,1)
    c=ceil(zero1(cnt)/s1); % due to the fact that zero123 shows the data in 1D array
    r=mod(zero1(cnt)-1,s1)+1;
    if (~mask(r,c)) %ayta ta simeia de theloyme na ta gemisei
        continue;
    end
    startr=max(1,r-1); endr=min(r+1,s1-1);
    startc=max(1,c-1); endc=min(c+1,s2-1);

    for color=1:3
%         window_im=imNew(startr:endr,startc:endc,color);
%         non_zero_el=size(find(window_im>0),1);
%         imNew(r,c,color)=sum(sum(window_im))/non_zero_el;
        imNew(r,c,color)=mean(nonzeros(imNew(startr:endr,startc:endc,color)));
    end
    imNewD(r,c)=mean(nonzeros(imNewD(startr:endr,startc:endc)));
end
%figure, imshow(imNew)
end

function new_x=fix_disocclusions(im,imD, kernel)
% aux function that assigns the mean of a square filter in disoccluded
% points
% fcn = @(x) [x(5) nansum(x(1:9))/max(nansum(x(1:9) > 0),1)]*[x(5) > 0; x(5) ==0]; % alternative but slow method
% imNewD_f = nlfilter(imNewD,[3 3],fcn);
sumX = conv2(im,kernel,'same');                 %# Compute the sum of neighbors
                                                %#   for each pixel
nX = conv2(double(im > 0),kernel,'same');       %# Compute the number of non-zero
                                                %#   neighbors for each pixel
index = (imD ==0);                               %# Find logical index of pixels == 0
new_x = im;                                     %# Initialize new_x
new_x(index) = sumX(index)./max(nX(index),1);   %# Replace the pixels in index

end



