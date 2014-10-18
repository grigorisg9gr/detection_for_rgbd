function visualizemodel(model,components)

% visualizemodel(model)
% Visualize a model.

clf;

if nargin < 2
  components = 1:length(model.components);
end

scale = 0;
for f = model.filters,
  w = foldHOG(f.w);
  scale = max(scale,max(w(:)));
end
im_scale = 255*3/scale;

k = 1;
for i = components
  visualizecomponent(model, model.components{i},length(components),k,im_scale);
  k = k+1;
end

function visualizecomponent(model, c, nc, k, im_scale)

% make picture of root filter
pad   = 2;
rpad  = 50;
bs    = 20;
p = c(1);
w = model.filters(p.filterid).w;
w = foldHOG(w);
im = HOGpicture(w, bs);
im = imresize(im, 2);
im = padarray(im, [rpad rpad], 0);
im = uint8(im * im_scale);

% draw root
numparts = length(c)-1;
if numparts > 0
  subplot(nc,3,1+3*(k-1));
else
  subplot(nc,1,k);
end
imagesc(im)
colormap gray;
axis equal;
axis off;

% draw parts and deformation model
% assuming a star model (all parts connect to root)
if numparts > 0
  def_im = zeros(size(im));
  def_scale = 500;
  for part = c(2:end),
    % part filter
    w = model.filters(part.filterid).w;
    aa = foldHOG(w);
    p = HOGpicture(foldHOG(w), bs);
    p = padarray(p, [pad pad], 0);
    p = uint8(p * im_scale);   
    def = model.defs(part.defid);
    sc  = def.anchor(3);
    assert(sc == 0 || sc == 1);
    if sc == 0,
      p = imresize(p,2);
      def.anchor(1:2) = (def.anchor(1:2)-1)*2+1;
    end
    % border 
    p(:,1:2*pad) = 128;
    p(:,end-2*pad+1:end) = 128;
    p(1:2*pad,:) = 128;
    p(end-2*pad+1:end,:) = 128;
    % paste into root
    x1 = (def.anchor(1)-1)*bs+1 + rpad;
    y1 = (def.anchor(2)-1)*bs+1 + rpad;
    x2 = x1 + size(p, 2)-1;
    y2 = y1 + size(p, 1)-1;
    im(y1:y2, x1:x2) = p;
    
    % deformation model
    probex = size(p,2)/2;
    probey = size(p,1)/2;
    for y = 2*pad+1:size(p,1)-2*pad
      for x = 2*pad+1:size(p,2)-2*pad
        px = (probex-x)/(bs*(1-sc+1));
        py = (probey-y)/(bs*(1-sc+1));
        v = [px^2; px; py^2; py];
        p(y, x) = def.w * v * def_scale;
      end
    end
    def_im(y1:y2, x1:x2) = p;
  end

  % plot parts
  subplot(nc,3,2+3*(k-1));
  imagesc(im); 
  colormap gray;
  axis equal;
  axis off;
  
  % plot deformation model
  subplot(nc,3,3+3*(k-1));
  imagesc(def_im);
  colormap gray;
  axis equal;
  axis off;
end

% set(gcf, 'Color', 'white')