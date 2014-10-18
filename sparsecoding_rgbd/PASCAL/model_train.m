function model = model_train(name,pos,neg,n)
% model = pascal_train(cls,pos,neg,n)
% Train a n-mixture part model using positive/negative images of bounding boxes
globals; 

%k    = min(length(pos),500*n);
%kpos = pos(1:k);
kpos = pos;
spos = split(pos, n);
k    = min(length(neg),200);
kneg = neg(1:k);

% record a log of the training procedure
file = [cachedir name '.log'];
delete(file);
diary(file);

% train root filters using warped positives 
file = [cachedir name '_lrsplit'];
try
  load(file);
catch
  for i=1:n
    models{i} = initmodel(name,spos{i});
    models{i} = train(name, models{i}, spos{i}, kneg, 4);
  end
  save(file, 'models');
end

% merge models and train using latent detections
file = [cachedir name '_mix'];
try 
  load(file);
catch
  model = mergemodels(models);
  model = train(name, model, kpos, kneg, 1);
  save(file, 'model');
end

% add parts and update models using latent detections
file = [cachedir name '_parts'];
try 
  load(file);
catch
  for i=1:n
    model = addchildren(model, i, 1, 8, 1);
  end 
  model = train(name,model,kpos,kneg,8);
  save(file,'model');
end

% update models using full set of negatives.
file = [cachedir name '_final'];
try 
  load(file);
catch
  model = train(name, model, pos, neg);
  clear global qp;
  save(file,'model');
end

function spos = split(pos, n)

% spos = split(pos, n)
% Split examples based on aspect ratio.
% Used for initializing mixture models.

h = [pos(:).y2]' - [pos(:).y1]' + 1;
w = [pos(:).x2]' - [pos(:).x1]' + 1;
aspects = h ./ w;
aspects = sort(aspects);

for i=1:n+1  
  j = ceil((i-1)*length(aspects)/n)+1;
  if j > length(pos)
    b(i) = inf;
  else
    b(i) = aspects(j);
  end
end

aspects = h ./ w;
for i=1:n
  I = find((aspects >= b(i)) .* (aspects < b(i+1)));
  spos{i} = pos(I);
end

function model = mergemodels(models)

% model = mergemodels(models)
% Merge a set of models into a multiple mixture model.

model = models{1};
for m = 2:length(models)

  % merge defs
  nd = length(model.defs);
  for i = 1:length(models{m}.defs)
    x   = models{m}.defs(i);
    if x.i > 0,
      x.i = x.i + model.len;
    end
    model.defs(nd+i) = x;
  end

  % mergefilters
  nf = length(model.filters);
  for i = 1:length(models{m}.filters)
    x   = models{m}.filters(i);
    if x.i > 0,
      x.i = x.i + model.len;
    end
    model.filters(nf+i) = x;
  end

  % merge components
  nc = length(model.components);
  for i = 1:length(models{m}.components)
    x = models{m}.components{i};
    for j = 1:length(x),
      x(j).defid    = x(j).defid    + nd;
      x(j).filterid = x(j).filterid + nf;
    end
    model.components{nc+i} = x;
  end

  model.maxsize = max(model.maxsize, models{m}.maxsize);
  model.minsize = min(model.minsize, models{m}.minsize);
  model.thresh  = min(model.thresh,models{m}.thresh);
  model.len     = model.len + models{m}.len;
end
