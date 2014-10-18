
function ap=demo(cls)

addpath ../hsc_cvpr13/
addpath ../hsc_cvpr13/dictionaries
addpath ../hsc_cvpr13/modelsvd

clear -global cachedir_feat_pos cachedir_feat_neg cachedir_feat_test sched_g

modelsvd_dim=100;

%cls    = 'car';
%suffix = 'debug';
suffix = [];
load(['./voc-release4/' cls '_final.mat']);

pyr = featpyramid_xren(rand(100,100,3),model);
nf  = size(pyr.feat{1},3);

% Instantiate 6 mixtures with explicit mirror flipping 
% (avoids the need to explicitly flip)
model = convertV4(model,1:6, nf);
model.flip = 0;
model.interval=10;  %   was 4 in the model as it's intermediate
model.wreg_root=0.01;
model.wreg_part=10/4;
model.w0_part=0.01*4;

[pos, neg] = pascal_data(cls);
test       = pascal_test('test',cls);
%test       = pascal_test('test');
name       = [cls suffix];
overlap    = .7;

globals;

    fprintf('precomputing features of negative images...\n');
  cachedir_feat_neg2=cachedir_feat_neg;
  ind=randperm(length(neg));
  parfor ii=1:length(neg),
    i=ind(ii);
    im  = imread(neg(i).im);
    cachefile=[cachedir_feat_neg2 '/' num2str(neg(i).cacheid,'%010d') '.mat'];
    detect(cachefile, im, model);
  end


