
function ap=run_hsc_PASCAL(cls)

addpath ../hsc_cvpr13/
addpath ../hsc_cvpr13/dictionaries
addpath ../hsc_cvpr13/modelsvd

clear -global cachedir_feat_pos cachedir_feat_neg cachedir_feat_test sched_g

modelsvd_dim=100;

%cls    = 'car';
%suffix = 'debug';
suffix = [];
load(['./dpm_outputs/' cls '_final.mat']);
note1=model.note; [~, name] = system('hostname'); note=[note1 ' Sparse in PC: ' name];
model=model_attach_weights(model); % in order to make the model (constructed from voc-release-5) compatible with the convertV4 
pyr = featpyramid_xren(rand(100,100,4),model);
nf  = size(pyr.feat{1},3)/2;

startup;
% Instantiate 6 mixtures with explicit mirror flipping 
% (avoids the need to explicitly flip)
model = convertV4(model,1:6, nf); % Converts a model from voc-release-4 format to local format
model.flip = 0;
model.interval=10;
model.wreg_root=0.01;
model.wreg_part=2.5;
model.w0_part=0.04;

[pos, neg] = pascal_data(cls);
%test       = pascal_test('test',cls);
test       = pascal_test('val',cls); %collects the names, id of test images
name       = [cls suffix];
overlap    = .7;

%% reduce neg size
use_small_neg=0;
if use_small_neg,
  r=ceil( (1:length(neg))/length(neg)*200 );
  [~,ir,jr]=unique(r);
  neg=neg(ir);
end

if strcmp(suffix,'debug')
  i    = 1:20;
  pos  = pos(i); 
  neg  = neg(i); 
  test = test(i);   
end

globals;

modelfile=[cachedir name '_model_' num2str(1) '.mat']
model.note=note;
if ~exist(modelfile),

% Run on positive data and store part locations
numpos  = length(pos);
pixels  = model.minsize * model.sbin;
minsize = prod(pixels);

if ~exist([cachedir name '_latentpos_orig.mat']),
    for i=1:numpos
        pos(i).ex=[]; pos(i).ex2=[];
    end
  parfor i = 1:numpos
    fprintf('%s: latent positive: %d/%d\n', name, i, numpos);
    bbox = [pos(i).x1 pos(i).y1 pos(i).x2 pos(i).y2];
    % skip small examples
    if (bbox(3)-bbox(1)+1)*(bbox(4)-bbox(2)+1) < minsize
      continue
    end
    im = imreadx_greg(pos(i).im);
    [im, bbox] = croppos(im, bbox);
    [box,foo,ex] = detect_orig(im, model, 0, bbox, overlap); % Detect objects in input using a model and a score threshold.
    %showboxes(uint8(im(:,:,1:3)),box.xy)
    if ~isempty(box),
%      showboxes(im, box);
      ex.header(1:2) = [1 i];
      ex.id(1)=1;  % manually fix label
      pos(i).ex  = ex;
   % else
    %  pos(i).ex = [];
    end
    %% flip image
    im  = im(:,end:-1:1,:);
    imx = size(im,2);
    bbox(1) = imx - bbox(3) + 1;
    bbox(3) = imx - bbox(1) + 1;
    [box,foo,ex] = detect_orig(im, model, 0, bbox, overlap);
    if ~isempty(box),
%      showboxes(im, box);
      ex.header(1:2) = [1 i];
      ex.id(1)=1;  % manually fix label
      pos(i).ex2  = ex;
   % else
    %  pos(i).ex2 = [];
    end
  end
  save([cachedir name '_latentpos_orig.mat'],'pos');
else
  load([cachedir name '_latentpos_orig.mat']);
end

% Initialize model to use new feature set
% (actual initial weights don't matter because 
%  we are in a convex world with supervision)

assert(length(model.defs)==length(model.filters));

len = 0;
for i = 1:length(model.defs),
  x = model.defs(i);
  model.defs(i).i = len + 1;
  len = len + numel(x.w);

  x   = model.filters(i);
  siz = size(x.w);
  siz(3) = nf;
  model.filters(i).w = zeros(siz);
  model.filters(i).i = len + 1;
  len = len + numel(model.filters(i).w);
end
model.len = len;

%[model,pos]=get_rootonly(model,pos);

if 1,
load modelsvd-voc-rootonly-omp5x5-297.mat U
svd1= U(:,1:modelsvd_dim);
model.svd=[svd1,svd1]; %U(:,1:2*modelsvd_dim);  % greg, 29/4: 2*modelsvd_dim due to RGB-D form 
[model,pos]=remap_model_nfeat_2(model,pos,size(model.svd,2));
end

% Train model
model = train(name,model,pos,neg);

else

load(modelfile,'model');

end

%visualizemodel(model);pause();
% Lower threshold to get higher recall
model.thresh = max(-1.0, model.thresh);
model.thresh = min(-1.0, model.thresh);

% Test model
if 1,

if exist([cachedir '/' name '_results_test.mat']),
  load([cachedir '/' name '_results_test.mat'],'boxes');
else
  boxes = model_test(name,model,test);
  save([cachedir '/' name '_results_test.mat'],'boxes');
end
  ap = pascal_eval(cls, boxes, test, [name]);

end


