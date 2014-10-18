% Set up global variables used throughout the code
% More specifically: cachedir, VOCdevkit

% directory for caching models, intermediate data, and results
cachedir = 'models/';
if ~exist(cachedir),
  unix(['mkdir ' cachedir]);
end

% dataset to use
VOCyear = '2007';
%VOCyear = '2011';

% directory with PASCAL VOC development kit and dataset
%VOCdevkit = ['~/VOC/VOC' VOCyear '/VOCdevkit/'];
VOCdevkit = ['/VOCdevkit/'];
%VOCdevkit = ['/home/users/grigoris/Databases/PASCAL/VOC' VOCyear '/VOCdevkit/'];
% which development kit is being used
% this does not need to be updated
VOCdevkit2006 = false;
VOCdevkit2007 = false;
VOCdevkit2008 = false;
switch VOCyear
  case '2006'
    VOCdevkit2006=true;
  case '2007'
    VOCdevkit2007=true;
  case '2008'
    VOCdevkit2008=true;
end

assert(VOCdevkit2006 == false);

global cachedir_feat_pos cachedir_feat_neg cachedir_feat_test
if isempty(cachedir_feat_pos) | isempty(cachedir_feat_neg) | isempty(cachedir_feat_test),
  %cachedir_feat='./cache_feats/';
  cachedir_feat='/data2/grigoris/new_encoder/cache_feats/'; 
  cachedir_feat_pos=[cachedir_feat '/PASCAL_feat_pos/' cls];
  cachedir_feat_neg=[cachedir_feat '/PASCAL_feat_neg_int2'];
  cachedir_feat_test=[cachedir_feat '/PASCAL_feat_test'];
  system(['mkdir -p ' cachedir_feat_pos]);
  system(['mkdir -p ' cachedir_feat_neg]);
  system(['mkdir -p ' cachedir_feat_test]);
end

%global sched_g
%if isempty(sched_g),
%  sched_g=findResource('scheduler','type','local');
%  %sched_dir=['/home/xren/.matlab/local_scheduler_data/R2010b_' num2str(icpu) '/'];
%  sched_dir=['.local_scheduler_data/R2010b_' cls '/'];
%  system(['mkdir -p ' sched_dir]);
%  sched_g.DataLocation = sched_dir;
%end

startup; globals_new;

