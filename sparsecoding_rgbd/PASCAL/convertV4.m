function m = convertV4(model,components,nfeat)
% m = convertV4(model,components)
% Converts a model from voc-release-4 format to local format

if nargin < 2,
  %components = 1:length(model.rules{model.start});
  components = 1:2:length(model.rules{model.start});
end
layer = 1;


nd  = 0;
nf  = 0;
len = 0;
len2 = 0;   %  for target nfeat
nc  = 0;
for c = components,
  % Add offset
  offset = model.rules{model.start}(c).offset;
  x.w = offset.w;
  x.i = len + 1;
  x.i2 = len2+1;
  x.anchor = [0 0 0];
  nd  = nd  + 1;
  m.defs(nd) = x;
  len = len + prod(size(x.w));
  assert(ndims(x.w)<3);
  len2 = len2 + prod(size(x.w));
  x = [];
  
  rhs = model.rules{model.start}(c).rhs;  
  % assume the root filter is first on the rhs of the start rules
  if model.symbols(rhs(1)).type == 'T'
    % handle case where there's no deformation model for the root
    root = model.symbols(rhs(1)).filter;
  else
    % handle case where there is a deformation model for the root
    root = model.symbols(model.rules{rhs(1)}(layer).rhs).filter;
  end

  % Add root filter
  x.w = model.filters(root).w;
  x.i = len + 1;
  x.i2 = len2 + 1;
  nf  = nf  + 1;
  m.filters(nf) = x;
  assert(ndims(x.w)==3);
  len = len + prod(size(x.w));
  len2 = len2 + prod(size(x.w,1)*size(x.w,2)*nfeat);
  
  i = 1;
  comp(i).filterid = nf;
  comp(i).defid    = nd;
  comp(i).parent   = 0;
  
  for i = 2:length(rhs)
    % Add part deformation
    x.w    = model.rules{rhs(i)}(layer).def.w;
    x.anchor = model.rules{model.start}(c).anchor{i} + [1 1 0];
    x.i = len + 1;
    x.i2 = len2 + 1;
    nd  = nd  + 1;
    m.defs(nd) = x;
    len = len + prod(size(x.w));
    assert(ndims(x.w)<3);
    len2 = len2 + prod(size(x.w));
    x = [];
    
    % Add part filter
    fi  = model.symbols(model.rules{rhs(i)}(layer).rhs).filter;
    x.w = model.filters(fi).w;
    x.i = len + 1;
    x.i2 = len2 + 1;
    nf  = nf  + 1;
    m.filters(nf) = x;
    len = len + prod(size(x.w));
    assert(ndims(x.w)==3);
    len2 = len2 + prod(size(x.w,1)*size(x.w,2)*nfeat);
    
    % Add part to component
    comp(i).filterid = nf;
    comp(i).defid    = nd;
    comp(i).parent   = 1;
  end 
  nc = nc + 1;
  m.components{nc} = comp;
end

m.maxsize  = model.maxsize;
m.minsize  = model.minsize;
m.len      = len;
m.len2    = len2;
m.interval = model.interval;
m.sbin     = model.sbin;
m.flip     = 1;
m.thresh   = model.thresh;
