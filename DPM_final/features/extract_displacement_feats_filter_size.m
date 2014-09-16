function f=extract_displacement_feats_filter_size(im_b,fsz,interval_endpoints,nrParams)
% Extract displacement features of filter size. 
% ARGUMENTS: 
% im_b 			image in blocks (instead of pixels)
% fsz			filter size 
% interval_endpoints	Endpoints so as to distinguish the interval that each difference belongs to 
% nrParams		How many intervals we will have
%
%
% Copyright (C) 2014 Grigorios Chrysos
% available under the terms of the Apache License, Version 2.0

middle=floor((fsz+mod(fsz,2))/2);
avgMiddle=im_b(middle(1),middle(2));
N=size(interval_endpoints,2)-2;
diff=im_b-avgMiddle; 

% Naive (and slower) version which is more "intuitive" though:
% tic
% feat1=zeros([size(im_b,1) size(im_b,2) nrParams]); 
% for i=1:size(im_b,1)
%     for j=1:size(im_b,2) 
% %         diff=f(i,j)-avgMiddle;
% %         Y = normpdf(diff,interval_endpoints(1:2:end),interval_endpoints(2:2:end));
%         [~,pos]=max(abs(diff(i,j))-interval_endpoints<0);
%         if diff(i,j)>=0
%             feat1(i,j,min(pos)+N-1)=1;
%         else
%             feat1(i,j,N+3-min(pos))=1;
%         end
%     end
% end
% f_old=feat1;
% t1=toc;



% Vectorised version
inter(1,1,:)=interval_endpoints; 
inter=repmat(inter,[fsz(1),fsz(2),1]);
positives=(diff>=0);   % save the positives
diff=abs(diff); 
diff2=repmat(diff,[1,1,size(interval_endpoints,2)]);
[~,pos1]=max(diff2-inter<0,[],3);  % find the differences from all intervals and then find the biggest non-negative
feat3=(pos1+N-1).*positives+(N+3-pos1).*(1-positives); % indices of the features 

% make feat3 from 2d matrix the 3d required for the features
rowv=repmat([1:fsz(1)],[1,fsz(2)]);
colv=repmat([1:fsz(2)],[fsz(1),1]);
colv=colv(:);
f1=zeros([numel(im_b)*nrParams,1]);
f1(rowv'+(colv-1)*fsz(1)+(feat3(:)-1)*fsz(1)*fsz(2))=1;
f=reshape(f1,[fsz(1),fsz(2), nrParams]);

end

