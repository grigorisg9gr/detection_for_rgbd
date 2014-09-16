function im = imreadx(ex)
% Read a training example image.
%   im = imreadx(ex)
%
% Return value
%   im    The image specified by the example ex
%
% Argument
%   ex    An example returned by pascal_data.m
% if (isfield(ex,'DB')==0) %an den yparxei dld to ex.DB san pedio 
%     %ex.im   %o parakatw kwdikas prepei na fygei otan den anaferomaste se
%     %pascal
%     error('Error in imreadx, because DB does not exist, why?')
% %     im = color(imread(ex.im));
% %     if ex.flip
% %         im = im(:,end:-1:1,:);
% %     end
% return 
% end
% 


    im1 = imread(ex.im);
    
    ex.im=strrep(ex.im, '.png','_abs_smooth.png'); % greg, 19/11: change img_name to parse the depth images
    ex.im=strrep(ex.im, 'KinectColor','RegisteredDepthData'); % greg, 19/11: change img_name to parse the depth images
    im2=imread(ex.im);
    im(:,:,4)=im2;      % insert the depth map as a fourth field. We insert this first, because this is uint16 and thus we would loose data if the uint8 rgb is inserted first
    im(:,:,1:3)=im1;

if ex.flip
  im = im(:,end:-1:1,:);
end
% im = color(imread(ex.im));
% if ex.flip
%   im = im(:,end:-1:1,:);
% end
