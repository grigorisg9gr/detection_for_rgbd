function model = initmodel(name, pos, sbin, size)

% model = initmodel(name, pos, sbin, size)
% Initialize model structure.
% model.maxsize = [y,x] size of root filter in HOG cells
% model.len     = length of weight vector
% model.filters(i)
%  .w  = 8x8xf filter
%  .i = starting index in final weight vector
% model.defs(i)
%  .w      = 5x1 deformation parameters (x x^2 y y^2 bias)
%  .i     = starting index in weight vector
%  .anchor = 3x1 array of relative x, y, and scale of part wrt parent
% model.components{j}{k}
%  .filterid = (pointer to filter)
%  .defid    = (pointer to deformation)
%  .parent   = (pointer to parent node)

% pick mode of aspect ratios
h = [pos(:).y2]' - [pos(:).y1]' + 1;
w = [pos(:).x2]' - [pos(:).x1]' + 1;
xx = -2:.02:2;
filter = exp(-[-100:100].^2/400);
aspects = hist(log(h./w), xx);
aspects = convn(aspects, filter, 'same');
[peak, I] = max(aspects);
aspect = exp(xx(I));

% size of HOG features
if nargin < 3
  sbin = 8;
else
  sbin = sbin;
end

% pick 20 percentile area
areas = sort(h.*w);
area = areas(max(floor(length(areas) * 0.2),1));
area = max(min(area, 5000/64*sbin^2), 3000/64*sbin^2);

% pick dimensions
w  = sqrt(area/aspect);
h  = w*aspect;
nf = length(features(zeros([3 3 3]),1));

if nargin < 4
  size = [round(h/sbin) round(w/sbin) nf];
end

len = 0;

% deformation
d.w  = 0;
d.i  = 1;
d.anchor = [0 0 0];

% filter
f.w = zeros(size);
f.i = 1+1;

% set up one component model
c(1).filterid = 1;
c(1).defid    = 1;
c(1).parent   = 0;
model.defs(1)    = d;
model.filters(1) = f;
model.components{1} = c;

% initialize the rest of the model structure
% Biggest  root filter (maxsize) is used to pad  images
% Smallest root filter (minsize) is used to skip images
model.maxsize  = size(1:2);
model.minsize  = size(1:2);
model.len      = 1+prod(size);
model.interval = 10;
model.sbin     = sbin;
model.flip     = 1;


model = poswarp(name,0,model,pos);

% get positive examples by warping positive bounding boxes
% we create virtual examples by flipping each image left to right
function model = poswarp(name, t, model,pos)
  warped = warppos(name, model, pos);
  siz    = size(model.filters(1).w);
  len    = prod(siz);
  feat   = zeros(len,1);
  ny = siz(1);
  nx = siz(2);
  nf = siz(3)-1;
  
  % Cache features
  num  = length(warped);
  feats = zeros(ny*nx*nf,2*num);
  for i = 1:num,
    im = warped{i};
    feat = features(double(im),model.sbin);
    feat = feat(:,:,1:end-1);
    feats(:,2*i-1) = feat(:);
    feat = flipfeat(feat);
    feats(:,2*i)   = feat(:);
  end
  
  if model.flip,
    [w,score] = flipcluster(feats,200);
  else
    w = mean(feats,2);
    score = w'*w;
  end
  
  w = reshape(w,[ny nx nf]);
  w(:,:,end+1) = 0;
  model.filters(1).w = w;
  model.lb    = -score;
  
function [w,best] = flipcluster(feats,k)
 % Iterate to convergence with random restarts
   fprintf('Clustering');
   best   = -inf;
   num    = size(feats,2)/2;
   starts = randperm(num*2);
   starts = starts(1:min(k,length(starts)));
   
   for i = starts
     fprintf('.');
     cen = feats(:,i);
     ind = zeros(num*2,1);
     while 1,
       val = cen'*feats;
       ind_prev = ind;
       ind = zeros(num*2,1);
       for i = 1:num,
         i1 = 2*i-1;
         i2 = 2*i;
         if val(i1) > val(i2),
            ind(i1) = 1;
          else
            ind(i2) = 1;
          end
        end
        cen = feats*ind/num;
        if isequal(ind,ind_prev),
          break;
        end
     end
     assert(sum(ind) == num);
     val = cen'*(feats*ind);
     if val > best,
       best = val;
       w    = cen;
     end
   end
   fprintf('\n');
 
   
function warped = warppos(name, model, pos)
  
% warped = warppos(name, model, pos)
% Warp positive examples to fit model dimensions.
% Used for training root filters from positive bounding boxes.
  f   = model.components{1}(1).filterid;
  siz = size(model.filters(f).w);
  siz = siz(1:2);
  pixels = siz * model.sbin; 
  heights = [pos(:).y2]' - [pos(:).y1]' + 1;
  widths = [pos(:).x2]' - [pos(:).x1]' + 1;
  numpos = length(pos);
  cropsize = (siz+2) * model.sbin;
  minsize = prod(pixels);
  warped  = [];
  for i = 1:numpos
    fprintf('%s: warp: %d/%d\n', name, i, numpos);
    % skip small examples
    if widths(i)*heights(i) < minsize
      continue
    end    
    im   = imread(pos(i).im);
    padx = model.sbin * widths(i) / pixels(2);
    pady = model.sbin * heights(i) / pixels(1);
    x1 = round(pos(i).x1-padx);
    x2 = round(pos(i).x2+padx);
    y1 = round(pos(i).y1-pady);
    y2 = round(pos(i).y2+pady);
    window = subarray(im, y1, y2, x1, x2, 1);
    warped{end+1} = imresize(window, cropsize, 'bilinear');
  end
  

function B = subarray(A, i1, i2, j1, j2, pad)
  
% B = subarray(A, i1, i2, j1, j2, pad)
% Extract subarray from array
% pad with boundary values if pad = 1
% pad with zeros if pad = 0
  
  dim = size(A);
  is = i1:i2;
  js = j1:j2;
  
  if pad,
    is = max(is,1);
    js = max(js,1);
    is = min(is,dim(1));
    js = min(js,dim(2));
    B  = A(is,js,:);
  else
    error('Not implemented');
    % todo
  end
  
  
  
function f = flipfeat(f)
% f = flipfeat(f)
% Horizontal-flip HOG features.
% Used for learning symmetric models.

% flip permutation
  if size(f,3) == 31,
    p = [10 9 8 7 6 5 4 3 2 1 18 17 16 15 14 13 12 11 19 27 26 25 24 23 ...
         22 21 20 30 31 28 29];
  else
    p = [10 9 8 7 6 5 4 3 2 1 18 17 16 15 14 13 12 11 19 27 26 25 24 23 ...
         22 21 20 30 31 28 29 32];
  end
  f = f(:,end:-1:1,p);
  