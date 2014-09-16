function [warped,warpedD] = warppos(model, pos)
% Warp positive examples to fit model dimensions.
%   warped = warppos(model, pos)
%
%   Used for training root filters from positive bounding boxes.
%
% Return value
%   warped  Cell array of images
%
% Arguments
%   model   Root filter only model
%   pos     Positive examples from pascal_data.m

fi = model.symbols(model.rules{model.start}.rhs).filter;
fsize = model.filters(fi).size;
pixels = fsize * model.sbin;
heights = [pos(:).y2]' - [pos(:).y1]' + 1;
widths = [pos(:).x2]' - [pos(:).x1]' + 1;
numpos = length(pos);
warped = cell(numpos,1); warpedD = cell(numpos,1);
cropsize2 = (fsize) * model.sbin; cropsize1 = (fsize+2) * model.sbin;
parfor i = 1:numpos
  fprintf('%s %s: warp: %d/%d\n', ...
          procid(), model.class, i, numpos)

  im = imreadx(pos(i));
%         for obj=1:size(pos(i).boxes,1) % to ekswteriko parfor na ginei for gia na deixnei eikones
%            fprintf('i= %d object= %d  \n',i,obj);
%            showboxes(im,pos(i).boxes(obj,1:4));
%            pause();
%         end
  padx = model.sbin * widths(i) / pixels(2);
  pady = model.sbin * heights(i) / pixels(1);
  x1 = round(pos(i).x1-padx);
  x2 = round(pos(i).x2+padx);
  y1 = round(pos(i).y1-pady);
  y2 = round(pos(i).y2+pady);
  window = subarray(im, y1, y2, x1, x2, 1);
  warped{i,1} = imresize(window, cropsize1, 'bilinear'); % hog rgbd
  warpedD{i,1} = imresize(window(:,:,4), cropsize2, 'bilinear'); % displacement feats
end

