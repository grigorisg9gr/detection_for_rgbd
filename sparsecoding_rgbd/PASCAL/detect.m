function [boxes,model,ex] = detect(cachefile, input, model, thresh, bbox, overlap, id, label)
% [boxes,model,ex] = detect(input, model, thresh, bbox, overlap, label, fid, id, label)
% Detect objects in input using a model and a score threshold.
% Higher threshold leads to fewer detections.
%
% The function returns a matrix with one row per detected object.  The
% last column of each row gives the score of the detection.  The
% column before last specifies the component used for the detection.
% Each set of the first 4 columns specify the bounding box for a part
%
% If bbox is not empty, we pick best detection with significant overlap. 
% If label is included, we write feature vectors to a global QP structure
%
% This function updates the model (by running the QP solver) if upper and lower bound differs

INF = 1e10;


if nargin > 3+1 && ~isempty(bbox)
  latent = true;
  thresh = -1e100;
else
  bbox   = [];
  latent = false;
end

% Define global QP if we are writing features
% Randomize order to increase effectiveness of model updating
write = false;
if nargin > 5+1,
  global qp;
  write  = true;
end
if nargin < 6+1 | isempty(id),
  id = 0;
end
if nargin < 7+1
  label = 0;
end

% Keep track of detected boxes and features
cnt = 0;
boxes.s  = 0;
boxes.c  = 0;
boxes.xy = 0;
boxes(100000) = boxes;
ex.blocks = [];
ex.id   = [label id 0 0 0];

for flip = 0:model.flip,

  % Flip image and bounding box if necessary
  if flip,
    [input,bbox] = lrflip(input,bbox);
  end
  
  % Compute the feature pyramid and prepare filters
  %pyra = featpyramid_xren(input,model);
  if flip==0,
    if exist(cachefile),
      if nargout<1, continue; end;
      try
        load(cachefile,'pyra_i');
        pyra=pyra_byte_to_double(pyra_i);
        pyra=check_maxsize(pyra,model.maxsize);
      catch
        pyra=featpyramid_xren(input,model);
        pyra_i=pyra_double_to_byte(pyra);
        if ~isempty(cachefile), save(cachefile,'pyra_i'); end
      end
    else
      pyra=featpyramid_xren(input,model);
      pyra_i=pyra_double_to_byte(pyra);
      if ~isempty(cachefile), save(cachefile,'pyra_i'); end
    end
  else
    cachefile=[cachefile(1:end-4) '_1.mat'];
    if exist(cachefile),
      if nargout<1, continue; end;
      try
        load(cachefile,'pyra_i');
        pyra=pyra_byte_to_double(pyra_i);
        pyra=check_maxsize(pyra,model.maxsize);
      catch
        pyra=featpyramid_xren(input,model);
        pyra_i=pyra_double_to_byte(pyra);
        if ~isempty(cachefile), save(cachefile,'pyra_i'); end
      end
    else
      pyra=featpyramid_xren(input,model);
      pyra_i=pyra_double_to_byte(pyra);
      if ~isempty(cachefile), save(cachefile,'pyra_i'); end
    end
  end

  if nargout<1, continue; end;

  if isfield(model,'svd') & ~isempty(model.svd),
    pyra=project_feat_pyra(pyra,model.svd);
  end
 
  [components,filters,resp]  = modelcomponents(model,pyra);
  
  % Iterate over random permutation of scales and components,
  % ensuring we have enough resolution to see full model
  % If we're in latent mode, only evaluate the given global mixture
  comps = randperm(length(components));
  if latent,
    comps = bbox.c;
  end
  for c  = comps,
    minlevel = max([components{c}.scale])*model.interval+1;
    levels   = minlevel:length(pyra.feat); 
    for rlevel = levels(randperm(length(levels))),
      parts    = components{c};
      numparts = length(parts);

      % Local part scores
      for k = 1:numparts,
        f     = parts(k).filterid;
        level = rlevel-parts(k).scale*model.interval;
        if isempty(resp{level}),
            flag=false; cnt=0;                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% greg, 26/5: The trick with the flag in the following lines, ony to prevent "error creating thread" 
            while (~flag)
                try
                    resp{level} = fconv_sparse(pyra.feat{level},filters,1,length(filters)); %%%% if size(filter,3) changes, then change the fconvsee_sparse function
                    flag=true;
                catch
                    flag=false; cnt=cnt+1; if mod(cnt,1000)==0, fprintf('warning in convolutions threads (%d)\n',cnt), end
                end
            end
        end
        parts(k).score = resp{level}{f};      
        parts(k).level = level;
      end

      % Force parts to cover their latent locations
      if latent,
        for k = 1:numparts,
          ovmask =...
              testoverlap(parts(k).sizx,parts(k).sizy,pyra,rlevel,bbox.xy(k,:),overlap);
          tmpscore = parts(k).score;
          tmpscore(~ovmask) = -INF;
          parts(k).score = tmpscore;
        end
      end
      
      % Walk from leaves to root of tree, passing message to parent
      % Given a 2D array of filter scores 'child', shiftdt() does the following:
      % (1) Apply distance transform
      % (2) Shift by anchor position (child.startxy) of part wrt parent
      % (3) Downsample by child.step
      for k = numparts:-1:2,
        child = parts(k);
        par   = child.parent;
        [Ny,Nx,foo] = size(parts(par).score);
        [msg,parts(k).Ix,parts(k).Iy] = shiftdt(child.score, child.w(1),child.w(2),child.w(3),child.w(4), ...
                                           child.startx, child.starty, Nx, Ny, child.step);
        parts(par).score = parts(par).score + msg;
      end
      
      % Add bias to root score
      rscore = parts(1).score + parts(1).w;
            
      % In latent mode, find best overlapping detection window
      if latent,
        thresh = max(thresh,max(max(rscore)));
      end
      
      [Y,X] = find(rscore >= thresh);%max(max(rscore))
      
      % Walk back down tree following pointers
      for i = 1:length(X)
        x = X(i);
        y = Y(i);
        cnt = cnt + 1;
        boxes(cnt).c = c;
        boxes(cnt).s = rscore(y,x);
        [boxes(cnt).xy,ex] = backtrack( x, y, parts, pyra, ex, latent || write, flip);
        if write && ~latent,
          qp_write(ex);
          qp.ub = qp.ub + qp.Cneg*max(1+rscore(y,x),0);
        end
      end
      
      % Crucial DEBUG assertion
      % If we're computing features, assert extracted feature re-produces score
      % (see qp_write.m for computing original score)
      if write && ~latent && ~isempty(X) && qp.n < length(qp.a),
        w = -(qp.w + qp.w0.*qp.wreg) / qp.Cneg;
        assert((score(w,qp.x,qp.n) - rscore(y,x)) < 1e-5);   
      end
      
      % Optimize qp with coordinate descent, and update model
      if write && ~latent && ...
            (qp.lb < 0 || 1 - qp.lb/qp.ub > .05 || qp.n == length(qp.sv))
        model = optimize(model);
        [components,filters,resp] = modelcomponents(model,pyra);    
        loss = 0;
      end
    end
  end
end

boxes = boxes(1:cnt);

if latent && ~isempty(boxes),
  boxes = boxes(end);
  if write,
    qp_write(ex);
  end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% other functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% Update QP with coordinate descent
% and return the asociated model
function model = optimize(model);
  global qp;
  fprintf('.');  
  if qp.lb < 0 || qp.n == length(qp.a),
    qp_opt();
    qp_prune();
  else
    qp_one();
  end
  model = vec2model(qp_w(),model);

% Compute the deformation feature given parent locations, 
% child locations, and the child part
function res = defvector(px,py,x,y,part)
  probex = ( (px-1)*part.step + part.startx );
  probey = ( (py-1)*part.step + part.starty );
  dx  = probex - x;
  dy  = probey - y;
  res = -[dx^2 dx dy^2 dy]';
  
% Compute a mask of filter reponse locations (for a filter of size sizy,sizx)
% that sufficiently overlap a ground-truth bounding box (bbox) 
% at a particular level in a feature pyramid
function ov = testoverlap(sizx,sizy,pyra,level,bbox,overlap)
  scale = pyra.scale(level);
  padx  = pyra.padx;
  pady  = pyra.pady;
  [dimy,dimx,foo] = size(pyra.feat{level});
  
  bx1 = bbox(1);
  by1 = bbox(2);
  bx2 = bbox(3);
  by2 = bbox(4);
  
  % Index windows evaluated by filter (in image coordinates)
  x1 = ([1:dimx-sizx+1] - padx - 1)*scale + 1;
  y1 = ([1:dimy-sizy+1] - pady - 1)*scale + 1;
  x2 = x1 + sizx*scale - 1;
  y2 = y1 + sizy*scale - 1;
  
  % clip detection window to image boundary
  imy = pyra.imy;
  imx = pyra.imx;
  x1  = min(max(x1,1),imx);
  x2  = max(min(x2,imx),1);
  y1  = min(max(y1,1),imy);
  y2  = max(min(y2,imy),1);
  
  % Compute intersection with bbox
  xx1 = max(x1,bx1);
  xx2 = min(x2,bx2);
  yy1 = max(y1,by1);
  yy2 = min(y2,by2);
  w   = xx2 - xx1 + 1;
  h   = yy2 - yy1 + 1;
  w(w<0) = 0;
  h(h<0) = 0;
  inter  = h'*w;
  
  % area of (possibly clipped) detection windows and original bbox
  area = (y2-y1+1)'*(x2-x1+1);
  box  = (by2-by1+1)*(bx2-bx1+1);
  
  % thresholded overlap
  ov   = inter ./ (area + box - inter) > overlap;

% Backtrack through dynamic programming messages to estimate part locations
% and the associated feature vector  
function [box,ex] = backtrack(x,y,parts,pyra,ex,write,flip)
  numparts = length(parts);
  ptr = zeros(numparts,2);
  box = zeros(numparts,4);
  k   = 1;
  p   = parts(k);
  ptr(k,:) = [x y];
  % image coordinates of root
  scale = pyra.scale(p.level);
  padx  = pyra.padx;
  pady  = pyra.pady;
  box(k,1) = (x-1-padx)*scale + 1;
  box(k,2) = (y-1-pady)*scale + 1;
  box(k,3) = box(k,1) + p.sizx*scale - 1;
  box(k,4) = box(k,2) + p.sizy*scale - 1;
  % write header and root features
  if write
    ex.id(3:5) = [p.level round(x+p.sizx/2) round(y+p.sizy/2)];
    ex.blocks = [];
    ex.blocks(end+1).i = p.defI;
    ex.blocks(end).x = 1;
    f  = pyra.feat{p.level}(y:y+p.sizy-1,x:x+p.sizx-1,:); 
    ex.blocks(end+1).i = p.filterI;
    ex.blocks(end).x = f;
  end
  for k = 2:numparts,
    p   = parts(k);
    par = p.parent;
    x   = ptr(par,1);
    y   = ptr(par,2);
    ptr(k,1) = p.Ix(y,x);
    ptr(k,2) = p.Iy(y,x);
    % image coordinates of part k
    scale = pyra.scale(p.level);
    box(k,1) = (ptr(k,1)-1-padx)*scale + 1;
    box(k,2) = (ptr(k,2)-1-pady)*scale + 1;
    box(k,3) = box(k,1) + p.sizx*scale - 1;
    box(k,4) = box(k,2) + p.sizy*scale - 1;
    if write,
      ex.blocks(end+1).i = p.defI;
      ex.blocks(end).x = defvector(x,y,ptr(k,1),ptr(k,2),p);
      x  = ptr(k,1);
      y  = ptr(k,2);
      f  = pyra.feat{p.level}(y:y+p.sizy-1,x:x+p.sizx-1,:);
      ex.blocks(end+1).i = p.filterI;
      ex.blocks(end).x = f;
    end
  end

  % Flip boxes and header if necessary
  if flip
    x1  = box(:,1);
    x2  = box(:,3);
    box(:,1) = pyra.imx - x2 + 1;
    box(:,3) = pyra.imx - x1 + 1;
    ex.id(4) = size(pyra.feat{parts(1).level},2) - ex.id(4) + 1;
  end

% Cache various statistics from the model data structure for later use  
function [components,filters,resp] = modelcomponents(model,pyra)
  components = cell(length(model.components),1);
  for c = 1:length(model.components),
    for k = 1:length(model.components{c}),
      p = model.components{c}(k);
      x = model.filters(p.filterid);
      [p.sizy p.sizx foo] = size(x.w);
      p.filterI = x.i;
      x = model.defs(p.defid);
      p.defI = x.i;
      p.w    = x.w;
      
      % store the scale of each part relative to the component root
      par = p.parent;
      assert(par < k);
      ax  = x.anchor(1);
      ay  = x.anchor(2);    
      ds  = x.anchor(3);
      if par > 0,
        p.scale = ds + components{c}(par).scale;
      else
        assert(k == 1);
        p.scale = 0;
      end
      % amount of (virtual) padding to hallucinate
      step     = 2^ds;
      virtpady = (step-1)*pyra.pady;
      virtpadx = (step-1)*pyra.padx;
      % starting points (simulates additional padding at finer scales)
      p.starty = ay-virtpady;
      p.startx = ax-virtpadx;      
      p.step   = step;
      p.level  = 0;
      p.score  = 0;
      p.Ix     = 0;
      p.Iy     = 0;
      components{c}(k) = p;
    end
  end
  
  resp    = cell(length(pyra.feat),1);
  filters = cell(length(model.filters),1);
  for i = 1:length(filters),
    filters{i} = single(model.filters(i).w);
  end
  
  
