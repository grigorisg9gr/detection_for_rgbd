function model = pascal(cls,n,suffix)
% model = pascal(cls, n)
% Train and score a model with n components.

if nargin < 1,
  cls = 'person';
end
if nargin < 2,
  n = 3;
end
if nargin < 3,
  suffix = [];
end

% Define training and testing data
globals;
pascal_init;
[pos, neg] = pascal_data(cls);
%test       = pascal_test('test',cls);
test       = pascal_test('test');
name       = [cls suffix];

% DEBUG: clear out files and run on subset of data
if strcmp(suffix,'debug')
  %  unix(['rm ' cachedir name '*']);
  unix(['rm ' cachedir name '_parts.mat']);
  unix(['rm ' cachedir name '_final.mat']);
  i    = 1:10;
  pos  = pos(i); 
  neg  = neg(i); 
  test = test(i);   
end

% Train model
model = model_train(name,pos,neg,n);

% Lower threshold to get higher recall
model.thresh = min(-1.1, model.thresh);

% Test model
boxes = model_test(name,model,test);
ap = pascal_eval(cls, boxes, test, [suffix VOCyear]);
