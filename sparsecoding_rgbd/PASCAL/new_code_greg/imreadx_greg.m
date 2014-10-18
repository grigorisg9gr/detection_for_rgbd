function [ im] = imreadx_greg( ex )
% A function that makes a 4-D image (3 first are the rgb channels and then
% the 4th is the depth field).

    im1 = imread(ex);
    ex=strrep(ex, '.png','_abs_smooth.png'); 
    ex=strrep(ex, 'KinectColor','RegisteredDepthData'); 
    im2=imread(ex);
    im(:,:,4)=im2;      % insert the depth map as a fourth field. We insert this first, because this is uint16 and thus we would loose data if the uint8 rgb is inserted first
    im(:,:,1:3)=im1;

end

