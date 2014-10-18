function ims = pascal_test(testset,cls)
% Collect pascal test images
globals;
pascal_init;

%ids = textread(sprintf(VOCopts.imgsetpath, testset), '%s');
ids = textread(sprintf('%s%s%s%s%s',DB_SPLIT, cls, '_', testset, '.txt'), '%s');
% if nargin >1, %greg: not updated, in nyu NOT correct
%   % Only grab test images containing class (to make evaluation faster)
%   [ids,labels] = textread(sprintf(VOCopts.clsimgsetpath, cls, testset), '%s %d');
%   ids = ids(labels == 1);
% end
for i = 1:length(ids),
  %ims(i).im = sprintf(VOCopts.imgpath, ids{i}); 
  rec = PASreadrecord(sprintf('%s%s%s%s%s%s',DB_BASE_DIR,'Annotations/',cls,'/', ids{i}, '.xml')); % read record to load the filename
%   rec.filename=strrep(rec.filename, '.png','_abs_smooth.png'); % greg, 19/11: change img_name to parse the depth images
%   rec.imgname=strrep(rec.imgname, '.png','_abs_smooth.png'); % greg, 19/11: change img_name to parse the depth images
  ims(i).im = sprintf('%s%s',DB_BASE_DIR, 'KinectColor/', rec.filename);
  ims(i).id = ids{i};
      [pathstr, name, ext] = fileparts(ims(i).im);
      ims(i).cacheid=str2num(name(isstrprop(rec.imgname, 'digit')))*100;
end  
