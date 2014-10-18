function [im,imD] = inptaint_rgb_background( im, imD)
% In-paint the RGB image

  
[~,c]=find(im(:,:,1)~=0&im(:,:,1)~=0);
im(:,1:min(c),1:3)=255;
%mask=imD==0;
maxIter=2;
iter=1; mask=im(:,:,1)==0&im(:,:,2)==0&im(:,:,3)==0;
while (max(max(mask))&&iter<maxIter)
    im=loop_over_empty(im,imD,mask);
    mask=im(:,:,1)==0&im(:,:,2)==0&im(:,:,3)==0;
    iter=iter+1;
end

end


function im=loop_over_empty(im,imD,mask)
thres=25;
[s1,s2]=size(imD);
[r,c]=find(mask);  
for cnt=1:size(r,1)
    if (r(cnt)==1||c(cnt)==s2||r(cnt)==s1)||(im(r(cnt),c(cnt),1)~=0)
        continue;
    end
    d(1)=non_zero_neighbour_rowwise(r(cnt)-1,c(cnt)+1,imD,min(s2,c(cnt)+thres));
    d(2)=non_zero_neighbour_rowwise(r(cnt),c(cnt)+1,imD,min(s2,c(cnt)+thres));
    d(3)=non_zero_neighbour_rowwise(r(cnt)+1,c(cnt)+1,imD,min(s2,c(cnt)+thres));
    d(4)=non_zero_neighbour_colwise(r(cnt)+1,c(cnt),imD,min(s1,r(cnt)+thres));
    %d(4)=find(imD(r(cnt)+1:end,c(cnt))~=0, 1 ); 
%     d(5)=non_zero_neighbour_back_col(r(cnt)+1,c(cnt)-1,imD,max(1,c(cnt)-thres));
%     d(6)=non_zero_neighbour_back_col(r(cnt),c(cnt)-1,imD,max(1,c(cnt)-thres));
%     d(7)=non_zero_neighbour_back_col(r(cnt)-1,c(cnt)-1,imD,max(1,c(cnt)-thres));
    d(5:8)=1;d1=1./(d.*d);
    depths=[imD(r(cnt)-1,d(1)+c(cnt)) imD(r(cnt),d(2)+c(cnt)) imD(r(cnt)+1,d(3)+c(cnt)) imD(r(cnt)+d(4),c(cnt)) imD(r(cnt)+1,c(cnt)-1) imD(r(cnt),c(cnt)-1) imD(r(cnt)-1,c(cnt)-1) imD(r(cnt)-1,c(cnt))];
%     depths=[imD(r(cnt)-1,d(1)+c(cnt)) imD(r(cnt),d(2)+c(cnt)) imD(r(cnt)+1,d(3)+c(cnt)) ... 
%         imD(r(cnt)+d(4),c(cnt)) imD(r(cnt)+1,c(cnt)-d(5)) imD(r(cnt),c(cnt)-d(6)) imD(r(cnt)-1,c(cnt)-d(7)) imD(r(cnt)-1,c(cnt))];
    depths2=depths; 
    values=[im(r(cnt)-1,d(1)+c(cnt),:) im(r(cnt),d(2)+c(cnt),:) im(r(cnt)+1,d(3)+c(cnt),:) im(r(cnt)+d(4),c(cnt),:) im(r(cnt)+1,c(cnt)-1,:) im(r(cnt),c(cnt)-1,:) im(r(cnt)-1,c(cnt)-1,:) im(r(cnt)-1,c(cnt),:)];
    idx=1:8; 
    [depths,si]=sort(depths);
    idx=idx(si);
    depths=nonzeros(depths); idx=idx(size(idx,2)-size(depths,1)+1:end); % keep only non-zero elements 
    if isempty(depths)
        continue;
    end
    background= depths(end)-depths<0.5;
    f(1:8)=0;
    f(idx(background))=1;
    fact=f.*d1; fact(isnan(fact))=0; fact(isinf(fact))=0; s=sum(fact);
    
    imD(r(cnt),c(cnt))=sum(fact.*depths2(:,:))/s;
    color=1;im(r(cnt),c(cnt),color)=uint8(sum(fact.*double(values(:,:,color)))/s);
    color=2;im(r(cnt),c(cnt),color)=uint8(sum(fact.*double(values(:,:,color)))/s);
    color=3;im(r(cnt),c(cnt),color)=uint8(sum(fact.*double(values(:,:,color)))/s);
end
end

function f=non_zero_neighbour_rowwise(row,col,imD,limit)
    flag=0;col_init=col;
    while ~flag&&col<=limit
        flag=imD(row,col)~=0; col=col+1;
    end
    if ~flag 
        f=0; 
    else 
        f=col-col_init;
    end  
end


function f=non_zero_neighbour_colwise(row,col,imD,limit)
    flag=0;row_init=row;
    while ~flag&&row<=limit
        flag=imD(row,col)~=0; row=row+1;
    end
    if ~flag 
        f=0; 
    else 
        f=row-row_init;
    end  
end

function f=non_zero_neighbour_back_col(row,col,imD,limit)
    flag=0;col_init=col;
    while ~flag&&col>limit
        flag=(imD(row,col)~=0); col=col-1;
    end
    if ~flag 
        f=0; 
    else 
        f=col_init-col;
    end  
end
