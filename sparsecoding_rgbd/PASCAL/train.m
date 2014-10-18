function [model,cnts] = train(name, model, pos, neg, iter, C, wpos, maxsize, overlap) 
% model = train(name, model, pos, neg, iter, C, Jpos, maxsize, overlap)
%                  1,     2,   3,   4,    5, 6,    7,       8,       9
% Train LSVM.
%
% warp=1 uses warped positives
% warp=0 uses latent positives
% iter is the number of training iterations
% maxsize is the maximum size of the training data cache (in GB)
% overlap is the minimum overlap in latent positive search
% C & Jpos are the parameters for LSVM objective function

if nargin < 5
  iter = 1;
end

if nargin < 6
  C = 0.002*length(model.components);
  %C = 0.002*length(model.components)/100*32;
  %C = 0.004*length(model.components)/100*32;  %  C3
  %C = 0.001*length(model.components)/100*32;  %  C1
end

if nargin < 7
  wpos = 1;
end

if nargin < 8
  % Use less than 2G of memory
  maxsize = 8.0; 
end

fprintf('Using %.1f GB\n',maxsize);

if nargin < 9
  overlap = 0.5;
end

% Vectorize the model
len  = sparselen(model);
nmax = round(maxsize*.25e9/len)

rand('state',0);
globals;

% Define global QP problem
global qp;
qp_init(len,nmax,5);
[w,qp.wreg,qp.w0,qp.noneg] = model2vec(model);
qp.Cpos = C*wpos;
qp.Cneg = C;
qp.w    = (w - qp.w0).*qp.wreg;

for t = 1:iter,
  fprintf('\niter: %d/%d\n', t, iter);

  cachefile_qp=[cachedir '/' name '_qp_init.mat'];
  if ~exist(cachefile_qp),
    updatepos(model, pos);
    qp.x=qp.x(:,1:qp.n);
    save(cachefile_qp,'qp','-V7.3');
  else
    load(cachefile_qp,'qp');
  end
  qp.x(:,end+1:length(qp.a))=0;

  % Fix positive examples as permenant support vectors
  % Initialize QP soln to a valid weight vector
  % Update QP with coordinate descent
  qp.svfix = 1:qp.n;
  qp.sv(qp.svfix) = 1;
  qp_prune();
  qp_opt(.5);
  model = vec2model(qp_w(),model);
  model.interval = 2; % 4; % 4;

  %if matlabpool('size')==0 & ~isempty(sched_g), sched=sched_g; matlabpool 2; end;
    fprintf('precomputing features of negative images...\n');
  cachedir_feat_neg2=cachedir_feat_neg;
  ind=randperm(length(neg));
  parfor ii=1:length(neg),
    i=ind(ii);
    im  = imreadx_greg(neg(i).im);
    fprintf('Negative image %d\n',ii);
    cachefile=[cachedir_feat_neg2 '/' num2str(neg(i).cacheid,'%010d') '.mat'];
    detect(cachefile, im, model);
  end
  if matlabpool('size')>0, matlabpool close; end
 
  for i = 1:length(neg),
    fprintf('\n Image(%d/%d)',i,length(neg));
    im  = imreadx_greg(neg(i).im);
    cachefile=[cachedir_feat_neg '/' num2str(neg(i).cacheid,'%010d') '.mat'];
    [box,model] = detect(cachefile, im, model, -1, [], 0, i, -1); % Detect objects in input using a model and a score threshold.
    fprintf(' #cache+%d=%d/%d, #sv=%d, #sv>0=%d, (est)UB=%.4f, LB=%.4f,',length(box),qp.n,nmax,sum(qp.sv),sum(qp.a>0),qp.ub,qp.lb);
    % Stop if cache is full
    if sum(qp.sv) == nmax,
      break;
    end
  end
  
  % One final pass of optimization
  qp_opt();
  model = vec2model(qp_w(),model);

  fprintf('\nDONE iter: %d/%d #sv=%d/%d, LB=%.4f\n',t,iter,sum(qp.sv),nmax,qp.lb);

  % Compute minimum score on positive example (with raw, unscaled features)
  r = sort(qp_scorepos());
  model.thresh   = r(ceil(length(r)*.05));
  model.interval = 10; % 10;
  model.lb = qp.lb;
  model.ub = qp.ub;

  % cache model
  save([cachedir name '_model_' num2str(t)], 'model');
end
fprintf('qp.x size = [%d %d]\n',size(qp.x));

   
%%%%%%%%%%%%%%%%
%% auxiliary functions
%%%%%%%%%%%%%%%%


% Use supervised parts (passed in as arguments) to extract features
function updatepos(model,pos)

global cachedir_feat_pos sched_g

  global qp;
  qp.n = 0;

  %if matlabpool('size')==0 & ~isempty(sched_g), sched=sched_g; matlabpool 2; end;
    fprintf('precomputing features of positive images...\n');
  cachedir_feat_pos2=cachedir_feat_pos;
  ind=randperm(length(pos));
  parfor ii=1:length(pos),
    fprintf('Positive %d\n',ii);
    i=ind(ii);
    ex = pos(i).ex;
    if ~isempty(ex),
      im = imreadx_greg(pos(i).im);
      bbox = [pos(i).x1 pos(i).y1 pos(i).x2 pos(i).y2];
      [im, bbox] = croppos(im, bbox);
    cachefile=[cachedir_feat_pos2 '/' num2str(pos(i).cacheid,'%010d') '.mat'];
     if ~exist(cachefile),
        pyra=featpyramid_xren(im,model);
        pyra_i=pyra_double_to_byte(pyra);
        %save(cachefile,'pyra_i');
        save_pyra_i(cachefile,pyra_i);
      end

    %% flip image
     im  = im(:,end:-1:1,:);
      imx = size(im,2);
      bbox(1) = imx - bbox(3) + 1;
      bbox(3) = imx - bbox(1) + 1;
    cachefile=[cachedir_feat_pos2 '/' num2str(pos(i).cacheid,'%010d') '_1.mat'];
     if ~exist(cachefile),
        pyra=featpyramid_xren(im,model);
        pyra_i=pyra_double_to_byte(pyra);
        %save(cachefile,'pyra_i');
        save_pyra_i(cachefile,pyra_i);
      end
    end
  end
  %if matlabpool('size')>0, matlabpool close; end

  for i = 1:length(pos),
    ex = pos(i).ex;

    % Extract feature pyramid and recompute HOG features in "ex"
    if ~isempty(ex),
      im = imreadx_greg(pos(i).im);
      bbox = [pos(i).x1 pos(i).y1 pos(i).x2 pos(i).y2];
      [im, bbox] = croppos(im, bbox);


    cachefile=[cachedir_feat_pos '/' num2str(pos(i).cacheid,'%010d') '.mat'];
      %pyra = featpyramid_xren(im,model);
    if exist(cachefile),
      try
        load(cachefile,'pyra_i');
        pyra=pyra_byte_to_double(pyra_i);
        pyra=check_maxsize(pyra,model.maxsize);
      catch
        pyra=featpyramid_xren(im,model);
        pyra_i=pyra_double_to_byte(pyra);
        save(cachefile,'pyra_i');
      end
    else
      pyra=featpyramid_xren(im,model);
      pyra_i=pyra_double_to_byte(pyra);
      save(cachefile,'pyra_i');
    end

    if isfield(model,'svd') & ~isempty(model.svd),
       pyra=project_feat_pyra(pyra,model.svd);
    end

      for j = 1:length(ex.blocks),
        ind = ex.blocks(j).ind;
        if ~isempty(ind),
          x  = ind(1);
          y  = ind(2);
          s  = ind(3);
          [dy,dx,foo] = size(ex.blocks(j).x);
          %f = pyra.feat{s}(y:y+dy-1,x:x+dx-1,:);
          f = pyra.feat{s};
          if size(f,1)<y+dy-1 | size(f,2)<x+dx-1,
            % should be enough
            f=padarray(f,[max(y+dy-1-size(f,1),0) max(x+dx-1-size(f,2),0) 0],'replicate','post'); %greg, 23/11: modification here
          end
          f=f(y:y+dy-1,x:x+dx-1,:);
          %assert(isequal(f,ex.blocks(j).x)); % Sanity check if we use original HOG
          ex.blocks(j).x = f;
        end
      end
      qp_write(ex);
    %end

    %% flip pos
    
    ex = pos(i).ex2;

    if ~isempty(ex),

      im  = im(:,end:-1:1,:);
      imx = size(im,2);
      bbox(1) = imx - bbox(3) + 1;
      bbox(3) = imx - bbox(1) + 1;

    cachefile=[cachedir_feat_pos '/' num2str(pos(i).cacheid,'%010d') '_1.mat'];
      %pyra = featpyramid_xren(im,model);
    if exist(cachefile),
      try
        load(cachefile,'pyra_i');
        pyra=pyra_byte_to_double(pyra_i);
        pyra=check_maxsize(pyra,model.maxsize);
      catch
        pyra=featpyramid_xren(im,model);
        pyra_i=pyra_double_to_byte(pyra);
        save(cachefile,'pyra_i');
      end
    else
      pyra=featpyramid_xren(im,model);
      pyra_i=pyra_double_to_byte(pyra);
      save(cachefile,'pyra_i');
    end

    if isfield(model,'svd') & ~isempty(model.svd),
       pyra=project_feat_pyra(pyra,model.svd);
    end

      for j = 1:length(ex.blocks),         
        ind = ex.blocks(j).ind;
        if ~isempty(ind),
          x  = ind(1);
          y  = ind(2);
          s  = ind(3);
          [dy,dx,foo] = size(ex.blocks(j).x);
          %f = pyra.feat{s}(y:y+dy-1,x:x+dx-1,:);
          f = pyra.feat{s};
          if size(f,1)<y+dy-1 | size(f,2)<x+dx-1,
            % should be enough
            f=padarray(f,[max(y+dy-1-size(f,1),0) max(x+dx-1-size(f,2),0) 0],'replicate','post'); %greg, 23/11: modification here
          end
          f=f(y:y+dy-1,x:x+dx-1,:);
          %assert(isequal(f,ex.blocks(j).x)); % Sanity check if we use original HOG
          ex.blocks(j).x = f;
        end
      end
      qp_write(ex);
    end

   end   %  empty(ex)

   fprintf('.');
  end
   fprintf('DONE\n');

% Compute score (weights*x) on positives examples
% Standardized QP stores w*x' where w = (weights-w0)*r, x' = c_i*(x/r)
% (w/r + w0)*(x'*r/c_i) = (v + w0*r)*x'/ C
function scores = qp_scorepos()
global qp;
y = qp.i(1,1:qp.n);
I = find(y == 1);
w = qp.w + qp.w0.*qp.wreg;
scores = score(w,qp.x,I) / qp.Cpos;

function len = sparselen(model)

len = 0;
for c = 1:length(model.components),
 feat = zeros(model.len,1);
 for p = model.components{c},
   x  = model.filters(p.filterid);
   i1 = x.i;
   i2 = i1 + numel(x.w) - 1;
   feat(i1:i2) = 1;
   
   x  = model.defs(p.defid);
   i1 = x.i;
   i2 = i1 + numel(x.w) - 1;
   feat(i1:i2) = 1;
 end
 
 % Number of entries needed to encode a block-sparse representation
 % 1 + 2*numberofblocks + #nonzeronumbers
 i1  = find([0; feat(1:end-1)] == 0 & feat ~= 0);
 i2  = find(feat ~= 0 & [feat(2:end); 0] == 0);
 assert(length(i1) == length(i2));
 n   = 1 + length(i1) + length(i2) + sum(feat);
 len = max(len,n);
end

function [im, box] = croppos(im, box)

% [newim, newbox] = croppos(im, box)
% Crop positive example to speed up latent search.

% crop image around bounding box
pad = 0.5*((box(3)-box(1)+1)+(box(4)-box(2)+1));
x1 = max(1, round(box(1) - pad));
y1 = max(1, round(box(2) - pad));
x2 = min(size(im, 2), round(box(3) + pad));
y2 = min(size(im, 1), round(box(4) + pad));

im = im(y1:y2, x1:x2, :);
box([1 3]) = box([1 3]) - x1 + 1;
box([2 4]) = box([2 4]) - y1 + 1;
