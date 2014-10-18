
function [model,pos]=remap_model_nfeat(model,pos,nf_new)
%
% function [model,pos]=remap_model_nfeat(model,pos,nf0,nf1)
%
%

map=containers.Map('KeyType','int32','ValueType','int32');

len = 0;
for i = 1:length(model.defs),
  x = model.defs(i);
     map( model.defs(i).i ) = len+1;
  model.defs(i).i = len + 1;
  len = len + numel(x.w);

  x   = model.filters(i);
  siz = size(x.w);
  siz(3) = nf_new;
  model.filters(i).w = zeros(siz);
     map( model.filters(i).i ) = len+1;
  model.filters(i).i = len + 1;
  len = len + numel(model.filters(i).w);
end
model.len = len;

for i=1:length(pos),
  ex=pos(i).ex;
  if ~isempty(ex),
    for k=1:length(ex.blocks),
      ex.blocks(k).i = map( ex.blocks(k).i );
    end
    pos(i).ex=ex;
  end
  ex=pos(i).ex2;
  if ~isempty(ex),
    for k=1:length(ex.blocks),
      ex.blocks(k).i = map( ex.blocks(k).i );
    end
    pos(i).ex2=ex;
  end
end

