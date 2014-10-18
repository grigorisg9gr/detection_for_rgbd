function [pos, neg] = pascal_data(cls)

% [pos, neg] = pascal_data(cls)
% Get training data from the PASCAL dataset.

globals; 
pascal_init; %kanei addpath gia to VOCdevkit, tpt perissotero

try
  load([cachedir cls '_train']);
catch
  % positive examples from train
  %ids = textread(sprintf(VOCopts.imgsetpath, 'trainval'), '%s');
  %ids = textread(sprintf(VOCopts.imgsetpath, 'train'), '%s');
  ids = textread(sprintf('%s%s%s',DB_SPLIT, cls,'_train.txt'), '%s');
  pos = [];
  numpos = 0;
  for i = 1:length(ids);
    fprintf('%s: parsing positives: %d/%d\n', cls, i, length(ids));
    %rec = PASreadrecord(sprintf(VOCopts.annopath, ids{i}));
    rec = PASreadrecord(sprintf('%s%s%s%s%s%s',DB_BASE_DIR,'Annotations/',cls,'/', ids{i}, '.xml'));
%     rec.filename=strrep(rec.filename, '.png','_abs_smooth.png'); % greg, 19/11: change img_name to parse the depth images
%     rec.imgname=strrep(rec.imgname, '.png','_abs_smooth.png'); % greg, 19/11: change img_name to parse the depth images
    clsinds = strmatch(cls, {rec.objects(:).class}, 'exact');
    % skip difficult examples
    diff = [rec.objects(clsinds).difficult];
    clsinds(diff) = [];
    count=0;
    for j = clsinds(:)'
      numpos = numpos+1;
      pos(numpos).im = [DB_BASE_DIR 'KinectColor/' rec.filename];
      bbox = rec.objects(j).bbox;
      pos(numpos).x1 = bbox(1);
      pos(numpos).y1 = bbox(2);
      pos(numpos).x2 = bbox(3);
      pos(numpos).y2 = bbox(4);
      %greg, 4/11: flip and trunc parts of the struct do not exist, next 3
      %lines not present in dpm original. Also, no flip image part
      count=count+1;
      [~, name, ~] = fileparts(rec.imgname);
      pos(numpos).cacheid=str2num(name(isstrprop(rec.imgname, 'digit')))*100+count;
    end
  end

  % negative examples from train (this seems enough!)
  %ids = textread(sprintf(VOCopts.imgsetpath, 'train'), '%s');
  ids = textread(sprintf('%s%s%s',DB_SPLIT, cls,'_train.txt'), '%s');
  neg = [];
  numneg = 0;
  for i = 1:length(ids);
    fprintf('%s: parsing negatives: %d/%d\n', cls, i, length(ids));
    %rec = PASreadrecord(sprintf(VOCopts.annopath, ids{i}));
    rec = PASreadrecord(sprintf('%s%s%s%s%s%s',DB_BASE_DIR,'Annotations/', cls,'/',ids{i}, '.xml'));
%     rec.filename=strrep(rec.filename, '.png','_abs_smooth.png'); % greg, 19/11: change img_name to parse the depth images
%     rec.imgname=strrep(rec.imgname, '.png','_abs_smooth.png'); % greg, 19/11: change img_name to parse the depth images
    clsinds = strmatch(cls, {rec.objects(:).class}, 'exact');
    if length(clsinds) == 0
      numneg = numneg+1;
      %neg(numneg).im = [VOCopts.datadir rec.imgname];
      neg(numneg).im = [DB_BASE_DIR 'KinectColor/' rec.filename];
      [~, name, ~] = fileparts(rec.imgname); %greg, 4/11: this and next line not present in dpm original.
      neg(numneg).cacheid=str2num(name(isstrprop(rec.imgname, 'digit')))*100;
    end
  end
  
  save([cachedir cls '_train'], 'pos', 'neg');
end  
