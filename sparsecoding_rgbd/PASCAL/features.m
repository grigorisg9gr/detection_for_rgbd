function res = features(im,sbin)
% res = features(im,sbin)
% Let [imy,imx] = size(impatch)
% -Result will be (imy/8-1) by (imx/8-1) by (4+9) for 
% 9 orientation bins and 4 normalizations for every 8x8 pixel-block
% -This won't produce exact same results as features.cc because this
% uses hard-binning rather than soft binning
% [TODO] This currently computes 9+4 features per cell, 
%        augment to compute 18+9+4 features

% Crop/pad image to make its size a multiple of sbin
[ty,tx,tz] = size(im);
imy = round(ty/sbin)*sbin;
if imy > ty,
  im = padarray(im,[imy-ty 0 0],'post');
elseif imy < ty,
  im = im(1:imy,:,:);
end
imx = round(tx/sbin)*sbin;
if imx > tx,
  im = padarray(im,[0 imx-tx 0],'post');
elseif imx < tx,
  im = im(:,1:imx,:);
end
im = double(im);
n  = (imy-2)*(imx-2);

% Pick the strongest gradient across color channels
dx  = im(2:end-1,3:end,:) - im(2:end-1,1:end-2,:); 
dy  = im(3:end,2:end-1,:) - im(1:end-2,2:end-1,:); 
dx  = reshape(dx,n,3);
dy  = reshape(dy,n,3); 
len = dx.^2 + dy.^2;
[len,I] = max(len,[],2);
len = sqrt(len);
I   = (I-1)*n + [1:n]';
dy  = dy(I); 
dx  = dx(I);

% Snap each gradient to an orientation
no = 9;
theta = 0:pi/no:pi-.01;
u = cos(theta);
v = sin(theta);
[foo,I] = max(abs(dx*u +dy*v),[],2);

% Spatially bin orientation channels into 8x8 neighborhoods
indy = ceil([2:imy-1]/sbin);
indx = ceil([2:imx-1]/sbin);
ind  = bsxfun(@plus,indy',(indx-1)*imy/sbin);
feat = full(sparse(ind,I,len,imy/sbin*imx/sbin,no));

mu = mean(feat,2);
mu = reshape(mu,[imy/sbin imx/sbin]);
mu = conv2(mu,.25*ones(2),'valid');
mu = cat(3,mu(1:end-1,1:end-1),mu(2:end,1:end-1),...
             mu(1:end-1,2:end),mu(2:end,2:end));
feat = reshape(feat,[imy/sbin imx/sbin no]);
feat = feat(2:end-1,2:end-1,:);

f1 = zeros(size(feat));
f2 = zeros(size(mu));
for i = 1:size(mu,3),
  f  = bsxfun(@gt,feat,mu(:,:,i));
  f1 = f1 + f;
  f2(:,:,i) = sum(f,3);
end
res = cat(3,f1,f2);

