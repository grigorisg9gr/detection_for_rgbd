
function pyra=project_feat_pyra(pyra,proj)
%
% function pyra=project_feat_pyra(pyra,proj)
%
%

nf_proj=size(proj,2);

n=length(pyra.feat);
for s=1:n,
  f=pyra.feat{s};
  [h,w,nf]=size(f);
  f=reshape(f,h*w,nf);
  f1=f(:,1:nf/2)*proj(:,1:nf_proj/2); f1=reshape(f1,[h w nf_proj/2]);
  f2=f(:,nf/2+1:end)*proj(:,nf_proj/2+1:end); f2=reshape(f2,[h w nf_proj/2]);
  
  ft1=shiftdim(f1,2);
  ft2=shiftdim(f2,2);
  ft=[ft1;ft2];
  f=shiftdim(ft,1);
%   f=f*proj;
  pyra.feat{s}=single(f); %reshape(f,[h w nf_proj]);
end


