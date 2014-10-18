
function ap=run_hsc_PASCAL_root(cls,DB)

addpath ../hsc_cvpr13/
addpath ../hsc_cvpr13/dictionaries
addpath ../hsc_cvpr13/modelsvd

clear -global cachedir_feat_pos cachedir_feat_neg cachedir_feat_test sched_g

if nargin < 2  % an klithei me mia parametro paei se default gia pascal voc
    DB=[];
end
modelsvd_dim=100;


%cls    = 'car';
%suffix = 'debug';
suffix = [];
load(['./dpm_outputs/' cls '_final.mat']);

pyr = featpyramid_xren(rand(100,100,3),model);
nf  = size(pyr.feat{1},3);

if ~isempty(DB) %dld se periptwsi poy einai gia NYU h Berkeley
    globals;  % greg, 4/11: not sure it's ok to be here
    startup;
    if (DB==1)
        a=sprintf('%s%s%s%s',DB_BASE_DIR,'nyu/extracted_data/',cls,'_objects.mat');
    else
        a=sprintf('%s%s%s%s',DB_BASE_DIR,'berkeley_VOCB3DO/extracted_data/',cls,'_objects_berkeley.mat');
    end
    load(a);
    model=model_attach_weights(model); % in order to make the model (constructed from voc-release-5) compatible with the convertV4 function
end


% Instantiate 6 mixtures with explicit mirror flipping 
% (avoids the need to explicitly flip)
model = convertV4(model,1:6, nf);
model.flip = 0;
model.interval=10; 
model.wreg_root=0.01;
model.wreg_part=2.5;
model.w0_part=0.04;

if isempty(DB)                  % default periptwsi gia vasi pascal voc
    [pos, neg] = pascal_data(cls);
else
    [pos, neg] = form_training_data_SC(cls,ImagesofObject,totalImages,DB);
end
%test       = pascal_test('test',cls);
test       = pascal_test('test');
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
if isempty(DB) 
    modelfile=[cachedir name '_model_' num2str(1) '.mat']; % to antistoixo save vrisketai sto telos tis synartisis train
else
    modelfile=[cachedir name '_'  DB '_model_' num2str(1) '.mat']; % to antistoixo save vrisketai sto telos tis synartisis train
end

if ~exist(modelfile),

% Run on positive data and store part locations
numpos  = length(pos);
pixels  = model.minsize * model.sbin;
minsize = prod(pixels);

if ~exist([cachedir name '_latentpos_orig.mat']),
  for i = 1:numpos
    fprintf('%s: latent positive: %d/%d\n', name, i, numpos);
    bbox = [pos(i).x1 pos(i).y1 pos(i).x2 pos(i).y2];
    % skip small examples
    if (bbox(3)-bbox(1)+1)*(bbox(4)-bbox(2)+1) < minsize
      continue
    end
    im = imread(pos(i).im);
    [im, bbox] = croppos(im, bbox);
    [box,foo,ex] = detect_orig(im, model, 0, bbox, overlap);
    if ~isempty(box),
      showboxes(im, box);
      ex.header(1:2) = [1 i];
      ex.id(1)=1;  % manually fix label
      pos(i).ex  = ex;
    else
      pos(i).ex = [];
    end
    %% flip image
    im  = im(:,end:-1:1,:);
    imx = size(im,2);
    bbox(1) = imx - bbox(3) + 1;
    bbox(3) = imx - bbox(1) + 1;
    [box,foo,ex] = detect_orig(im, model, 0, bbox, overlap);
    if ~isempty(box),
      showboxes(im, box);
      ex.header(1:2) = [1 i];
      ex.id(1)=1;  % manually fix label
      pos(i).ex2  = ex;
    else
      pos(i).ex2 = [];
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

[model,pos]=get_rootonly(model,pos);

% Train model
if isempty(DB) 
    model = train(name,model,pos,neg);
else
    model = train_DB(name,model,pos,neg,DB);
end

else

load(modelfile,'model');

end


% Lower threshold to get higher recall
model.thresh = max(-1.0, model.thresh);
model.thresh = min(-1.0, model.thresh);

% Test model
if 1,

if exist([cachedir '/' name '_results_test.mat']),
    load([cachedir '/' name '_results_test.mat'],'boxes');
else
    if isempty(DB)
        boxes = model_test(name,model,test);
    else
        boxes = model_test_DB(name,model,ImagesofObject,DB);
    end
    save([cachedir '/' name '_results_test.mat'],'boxes');
end
    if isempty(DB)
        ap = pascal_eval(cls, boxes, test, [name]);
    else
        trainingImages=ceil(size(ImagesofObject,2)*70/100);
        elem_nums=(trainingImages+1):size(ImagesofObject,2);
        [~,~,ap] = doeval2_SC( cls,elem_nums,boxes,true,DB )
    end
end


