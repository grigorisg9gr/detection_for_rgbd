function model = addchildren(model, c, k, numparts, scale)
% model = addchildren(model, c, k, num)
% add num children to k^th part from c^th mixture component 
% at a relative scale of scale (scale = 0 means parts are at same scale)

p = model.components{c}(k);
f = model.filters(p.filterid);

% Call Ross's code
filters = mkpartfilters(f.w, 6, numparts, scale);

for i = 1:length(filters),
  model = add(model,filters(i),c,k);
end

function model = add(model, filter,c,k)

% add deformation parameter
nd  = length(model.defs);
d.w = [0.01 0 0.01 0];
d.i = model.len + 1;
d.anchor = filter.anchor + [1 1 0];
model.defs(nd+1) = d;
model.len = model.len + prod(size(d.w));

% add filter
nf  = length(model.filters);
f.w = filter.w;
f.i = model.len + 1;
model.filters(nf+1) = f;
model.len = model.len + prod(size(f.w));

% add child to component c
np = length(model.components{c});
p.filterid = nf+1;
p.defid    = nd+1;
p.parent   = k;
model.components{c}(np+1) = p;

function pfilters = mkpartfilters(filter, psize, num, scale)
% Make part filters from a source filter.
%
% filter  source filter
% psize   size for parts
% num     number of parts to make

% interpolate source filter
filter2x = imresize(filter, 1+scale, 'bicubic');
template = fspecial('average', psize);
alpha = 0.1;

% Initial part placement based on greedy location selection.
energy = sum(max(filter2x, 0).^2, 3);
for k = 1:num
  [x y] = placepart(energy, template);
  f = mkfilter(filter2x, template, x, y, alpha);

  pfilters(k).anchor = [x-1 y-1 scale];
  pfilters(k).w = f;
  pfilters(k).alpha = alpha;

  % zero energy in source
  energy = zeroenergy(energy, x, y, template);
end

% sample part placements and pick the best energy covering
maxiter = 1000;
retries = 10;
bestcover = -inf;
best = [];
% retry from randomized starting points
for j = 1:retries
  tmp = pfilters;
  progress = ones(num,1);
  % relax:
  % remove a part at random and look for the best place to put it
  % continue until no more progress can be made (or maxiters)
  for k = 1:maxiter
    if sum(progress) == 0
      break;
    end
    energy = sum(max(filter2x, 0).^2, 3);
    p = ceil(num*rand(1));
    for i = 1:num
      if i ~= p
        energy = zeroenergy(energy, tmp(i).anchor(1)+1, ...
                                    tmp(i).anchor(2)+1, template);
      end
    end
    [x y] = placepart(energy, template);

    if tmp(p).anchor(1)+1 == x && tmp(p).anchor(2)+1 == y
      % new location equals old location
      progress(p) = 0;
      continue;
    end
    progress(p) = 1;

    f = mkfilter(filter2x, template, x, y, alpha);

    tmp(p).anchor = [x-1 y-1 1];
    tmp(p).w = f;
    tmp(p).alpha = alpha;
  end

  % compute the energy covered by this part arrangement
  covered = 0;
  energy = sum(max(filter2x, 0).^2, 3);
  for i = 1:num
    covered = covered + ...
              coveredenergy(energy, tmp(i).anchor(1)+1, ...
                                    tmp(i).anchor(2)+1, template);
    energy = zeroenergy(energy, tmp(i).anchor(1)+1, ...
                                tmp(i).anchor(2)+1, template);
  end
  % record best covering
  if covered > bestcover
    bestcover = covered;
    best = tmp;
  end
end
pfilters = best;


function [x y] = placepart(energy, template)

score = conv2(energy, template, 'valid');
score = padarray(score, [1 1], -inf, 'post');
v     = max(score(:));
[y,x] = find(score == v,1);

function f = mkfilter(w, template, x, y, alpha)

f = w(y:y+size(template,1)-1, x:x+size(template,2)-1, :);
f = max(f, 0);
f = alpha*f/norm(f(:));

function energy = zeroenergy(energy, x, y, template)

energy(y:y+size(template,1)-1, x:x+size(template,2)-1) = 0;


function covered = coveredenergy(energy, x, y, template)

e = energy(y:y+size(template,1)-1, x:x+size(template,2)-1);
covered = sum(e(:).^2);