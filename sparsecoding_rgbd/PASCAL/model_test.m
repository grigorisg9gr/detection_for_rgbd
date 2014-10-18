function res = model_test(name,model,ims)
% boxes = model_test(name,model,ims)
% Compute bounding boxes in a test set.
% boxes1 are bounding boxes from root placements
% boxes2 are bounding boxes using predictor function

global cachedir_feat_test sched_g

if matlabpool('size')==0, matlabpool open 8; end;

res = cell(length(ims),1);

cachedir_feat_test2=cachedir_feat_test;
ind=randperm(length(ims));
parfor ii = 1:length(ims),
  i=ind(ii);
  fprintf('%s: testing: %d/%d\n', name, i, length(ims));
  im = imreadx_greg(ims(i).im);
  cachefile=[cachedir_feat_test2 '/' num2str(ims(i).cacheid,'%10d') '.mat'];
  boxes = detect(cachefile, im, model, model.thresh);
  if ~isempty(boxes)
    b1 = clipboxes(im, boxes);
    res{ii} = nms(b1,0.5);
  end
end

%if matlabpool('size')>0, matlabpool close; end;

res(ind)=res(:); % Put the results in the right order after the permutation in line 14

function boxes = clipboxes(im, boxes, rootonly)
% boxes = clipboxes(im, boxes, rootonly)
% Clips boxes to image boundary.
imy = size(im,1);
imx = size(im,2);
for i = 1:length(boxes),
  b = boxes(i).xy;
  if nargin > 2 && rootonly
    b = b(1,:);
  end
  b(:,1) = max(b(:,1), 1);
  b(:,2) = max(b(:,2), 1);
  b(:,3) = min(b(:,3), imx);
  b(:,4) = min(b(:,4), imy);
  boxes(i).xy = b;
end

function [top,pick] = nms(boxes, overlap)

% [top,pick] = nms(boxes, overlap) 
% Non-maximum suppression.
% Greedily select high-scoring detections and skip detections
% that are significantly covered by a previously selected detection.

if isempty(boxes)
  pick = [];
else
  s = [boxes.s];
  [vals, I] = sort(s);
  pick = [];
  while ~isempty(I)
    last = length(I);
    i    = I(last);
    pick = [pick; i];
    suppress = [last];
    bi  = boxes(i).xy(1,:);
    for pos = 1:last-1
      j   = I(pos);
      bj  = boxes(j).xy(1,:);
      xx1 = max(bi(1), bj(1));
      yy1 = max(bi(2), bj(2));
      xx2 = min(bi(3), bj(3));
      yy2 = min(bi(4), bj(4));
      w = xx2-xx1+1;
      h = yy2-yy1+1;
      if w > 0 && h > 0
        % compute overlap 
        wj = bj(3)-bj(1)+1;
        hj = bj(4)-bj(2)+1;
        o = w * h / (wj * hj);
        if o > overlap
          suppress = [suppress; pos];
        end
      end
    end
    I(suppress) = [];
  end  
end

top = boxes(pick);

