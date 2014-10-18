
function [model,pos]=get_rootonly(model,pos)
%
% function [model,pos]=get_rootonly(model,pos)
%
%

ncomp=length(model.components);

%npart=8+1;
npart=length((model.components{1}));
assert(length(model.defs)==ncomp*npart);

model.defs=model.defs(1:npart:end);
model.filters=model.filters(1:npart:end);

for k=1:ncomp,
  c=model.components{k};
  model.components{k}=c(1);
  model.components{k}.filterid=k;
  model.components{k}.defid=k;
end

% now need to fix i, etc.
map=containers.Map('KeyType','int32','ValueType','int32');

len = 0;
for i = 1:length(model.defs),
  x = model.defs(i);
     map( model.defs(i).i ) = len+1;
  model.defs(i).i = len + 1;
  len = len + numel(x.w);

  x   = model.filters(i);
  siz = size(x.w);
  %siz(3) = nf;
  model.filters(i).w = zeros(siz);
     map( model.filters(i).i ) = len+1;
  model.filters(i).i = len + 1;
  len = len + numel(model.filters(i).w);
end
model.len = len;

for i=1:length(pos),
  if isempty(pos(i).ex), continue; end;
  pos(i).ex.blocks=pos(i).ex.blocks(1:2);
  pos(i).ex.blocks(1).i = map(  pos(i).ex.blocks(1).i );
  pos(i).ex.blocks(2).i = map(  pos(i).ex.blocks(2).i );
end

