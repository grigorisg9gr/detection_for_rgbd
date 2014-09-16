function [ap, prec, recall] = pascal_eval(cls, ds, testset, suffix)
% Score detections using the PASCAL development kit.
%   [ap, prec, recall] = pascal_eval(cls, ds, testset, suffix)
%
% Return values
%   ap        Average precision score
%   prec      Precision at each detection sorted from high to low confidence
%   recall    Recall at each detection sorted from high to low confidence
%
% Arguments
%   cls       Object class to evaluate
%   ds        Detection windows returned by pascal_test.m
%   testset   Test set to evaluate against (e.g., 'val', 'test')
%   year      Test set year to use  (e.g., '2007', '2011')
%   suffix    Results are saved to a file named:
%             [cls '_pr_' testset '_' suffix]

conf = voc_config();
cachedir = conf.paths.model_dir;                  
%VOCopts  = conf.pascal.VOCopts;
VOCopts    = conf.paths.db_annotation_dir;

if strcmp('nyu',conf.dataset)
  file_loc=[cls,'_'];
else
  file_loc='';
end
ids =  textread(sprintf('%s%s%s%s',VOCopts,file_loc, testset,'.txt'), '%s');

% write out detections in PASCAL format and score
%fid = fopen(sprintf(VOCopts.detrespath, 'comp3', cls), 'w');
fid = fopen(sprintf('%s%s', cachedir,cls), 'w');
for i = 1:length(ids);
  bbox = ds{i};
  for j = 1:size(bbox,1)
    fprintf(fid, '%s %f %d %d %d %d\n', ids{i}, bbox(j,end), bbox(j,1:4));
  end
end
fclose(fid);

recall = [];
prec = [];
ap = 0;

do_eval = 1;
if do_eval
    tic;
    [recall, prec, ap] = VOCevaldet(VOCopts, 'comp3', cls, true); 

  % force plot limits
  ylim([0 1]);
  xlim([0 1]);

  print(gcf, '-djpeg', '-r0', [cachedir cls '_pr_' testset '_' suffix '.jpg']);
end

% save results
save([cachedir cls '_pr_' testset '_' suffix], 'recall', 'prec', 'ap');
