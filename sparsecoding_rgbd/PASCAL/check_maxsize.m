
function pyra=check_maxsize(pyra,maxsize)
%
% function pyra2=check_maxsize(pyra)
%

padx = max(maxsize(2)-1-1,0);
pady = max(maxsize(1)-1-1,0);
padx = ceil(padx/2)*2;
pady = ceil(pady/2)*2;

nscale=length(pyra.feat);
for i=1:nscale,
  f=pyra.feat{i};
  f=f(pyra.pady+2:end-pyra.pady-1,pyra.padx+2:end-pyra.padx-1,:);
  f=padarray(f, [pady+1 padx+1 0], 0);
  f(1:pady+1, :, end) = 1;
  f(end-pady:end, :, end) = 1;
  f(:, 1:padx+1, end) = 1;
  f(:, end-padx:end, end) = 1;
  pyra.feat{i}=f;
end
pyra.pady=pady;
pyra.padx=padx;

