function ap = pascal_eval(cls, boxes, test, name)

% ap = pascal_eval(cls, boxes, test, name)
% Score bounding boxes using the PASCAL development kit.

globals;
pascal_init;

% write out detections in PASCAL format and score
%fid = fopen(sprintf(VOCopts.detrespath, 'comp3', cls), 'w');
fid = fopen(sprintf('%s%s', cachedir,cls), 'w');
for i = 1:length(boxes);
  for b = boxes{i},
    fprintf(fid, '%s %f %d %d %d %d\n', test(i).id, b.s, b.xy(1,1:4));
  end
end
fclose(fid);

[recall, prec, ap] = VOCevaldet(VOCopts, 'comp3', cls, true);
%[recall, prec, ap] = VOCevaldet_edited(VOCopts, 'comp3', cls, true); %greg, 16/1/2014: For multiple diagrams
ap = ap*100

if ap == 0,
  fprintf('WARNING: AP = 0;  VOCopts maybe pointing to incorrect testset');
end

% force plot limits
axis([0 1 0 1]);

% save results
file = [cachedir name '_pr'];
save(file, 'recall', 'prec', 'ap','boxes');
print(gcf, '-djpeg', '-r0', [file '.jpg']);
