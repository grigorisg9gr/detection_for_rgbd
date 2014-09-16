function [ posN,pos, impos ] = add_rendered( cls,pos, impos,dataid )
% greg, 6/1/2014: Add rendered items to the training set

conf=voc_config();
Zc=70000;a=150;
dataset_bg = conf.training.train_set_bg;
cachedir   = conf.paths.model_dir;
se = strel('disk',1);
scaling_factor=0.5;


try
  load([cachedir cls '_' dataset_bg '_added_rendered' ]); 
catch
    %% for pos 
    s1_pos=size(pos,2);
    for i=1:s1_pos
        pos(1,i).render.im=[];
    end
    startpos=0;


    other.a=a; other.scaling_factor=scaling_factor; other.Zc=Zc; other.se=se; 
    other.path='../../Databases/'; % this is for the not inpainted rendered depth images. 
    pool=[2,6];  % choice of rendering angle
    direction={'top','left'}; % rendering directions
    posN=[];
if 1,
    for i=1:size(pool,2)
        for d=1:size(direction,2)
            [posNew1,pos,dataid,startpos]= call_rendering_pos(pool(i)*1000,[direction{d} '_' num2str(pool(i)) 'k'], pos,d,dataid,startpos,other);
            posN=[posN posNew1];
        end
    end
end


    %% for impos
    s1_impos=size(impos,2);
    for i=1:s1_impos
        impos(1,i).render=[];
    end

         imposN=impos;
     for i=1:size(pool,2)
         for d=1:size(direction,2)
             [imposNew1,dataid]= call_rendering_impos(pool(i)*1000,[direction{d} '_' num2str(pool(i)) 'k'], impos,d,dataid,other);
             imposN=[imposN imposNew1];
         end
     end
     impos=imposN;

    save([cachedir cls '_' dataset_bg '_added_rendered' ],'pos','impos','posN');
end
end

function [posNew,pos,dataid,startpos]= call_rendering_pos(ts,c1,pos,render,dataid,startpos,other)
matRD=matfile([other.path '/nyu/render_v2/RegisteredDepthData_render_' c1 '/rendered_depth.mat'  ]);
[posNew,pos]=horizontal_rendering_pos(pos,ts,other.Zc,other.a,dataid,render,other.scaling_factor,other.se,c1,matRD,startpos); 
startpos=startpos+size(posNew,2);dataid=dataid+size(pos,2);

end

function [imposNew,dataid]= call_rendering_impos(ts,c1,impos,render,dataid,other)
matRD=matfile([other.path '/nyu/render_v2/RegisteredDepthData_render_' c1 '/rendered_depth.mat'  ]);
imposNew=horizontal_rendering_impos(impos,ts,other.Zc,other.a,dataid,render,other.scaling_factor,other.se,c1,matRD); dataid=dataid+size(imposNew,2);
end


function imD=imreadD2(ex)
    ex.im =strrep(ex.im, '.png','_abs_smooth.png'); % greg, 19/11: change img_name to parse the depth images
    ex.im=strrep(ex.im, 'KinectColor','RegisteredDepthData');
    imD=imread(ex.im);
    
    if ex.flip
      imD = imD(:,end:-1:1,:);
    end
end



function [posNew1,pos]=horizontal_rendering_pos(pos,ts,Zc,a,dataid,render,scaling_factor,se,loc_ren,matRD,start_pos)
posNew=pos;
black_thres=0.2;
minpixels=14; % if the bbox is less than those pixels in any direction, then it will fail to create features
s1_pos=size(posNew,2);
cc=2;
if render==1||render==3
    cc=1;
end
parfor i=1:s1_pos %parfor i=1:s1_pos 
    tic_toc_print('Rendering bbox for positive=%d  with %s\n',i,loc_ren);
    posNew(1,i).render=render; 
    
    bb=round(posNew(1,i).boxes);
    im=imreadD2(posNew(1,i));
    if render==1
        im=imrotate(im,90); % for rendering from the top
        bb=circshift(bb,[1 -1]);
        bb(2)=size(im,1)-bb(2)+1;bb(4)=size(im,1)-bb(4)+1; % new bbox for rendering from the top
    elseif render==3
        im=imrotate(im,-90); % for rendering from the bottom
        bb=circshift(bb,[-1 1]);
        bb(1)=size(im,2)-bb(1)+1;bb(3)=size(im,2)-bb(3)+1;
    end
    
    % do the actual rendering/adaptation of the bbox
    if (render==2) && (posNew(1,i).flip)
        [imNew,out_cnt]=horizontal_rendering_depth_reliable(im,bb,ts,Zc,a,-1); %flipped image is practically rendered from the other side
    else
        [imNew,out_cnt]=horizontal_rendering_depth_reliable(im,bb,ts,Zc,a,1);
    end
    % post-processing of the bbox
    mask=imNew~=0; mask2=imerode(mask,se);mask2=imdilate(mask2,se); %in order to reduce the small pieces that are not adding value to the bbox
    [r1,c1]=find(mask2~=0);
    if isempty(r1)
        bbN=[1 1 1 1]; % dump values to get it out
    else 
    	bbN=[min(c1) min(r1) max(c1) max(r1)];
        if render==1
            bbN=circshift(bbN,[1 1]);  % new bb for rendering from the top
            bbN(1)=size(im,1)-bbN(1)+1;bbN(3)=size(im,1)-bbN(3)+1;
        elseif render==3
            bbN=circshift(bbN,[1 -1]);
            bbN(2)=size(im,2)-bbN(2)+1;bbN(4)=size(im,2)-bbN(4)+1;
        end
        start1= strfind(posNew(1,i).im,'/'); end1=strfind(posNew(1,i).im,'.');
        numImg=str2double(posNew(1,i).im(start1(end)+1:end1-1)); 
        xs=bbN(1):bbN(3);
        if (posNew(1,i).flip)
            xs=(size(im,cc)-bbN(3)+1):(size(im,cc)-bbN(1)+1);
        end
        imdepth=matRD.depth(bbN(2):bbN(4),xs,numImg); %update 26/9 to read from the depths.mat, less RAM needed
        blacks=length(imdepth(imdepth==0));
    end

    new_size=(bbN(3)-bbN(1)+1)*(bbN(4)-bbN(2)+1);
    if (new_size<scaling_factor*posNew(1,i).sizes)||(blacks>black_thres*posNew(1,i).sizes)||(bbN(3)-bbN(1)+1<minpixels)||(bbN(4)-bbN(2)+1<minpixels) % if the new bbox is too small, then we discard this example
      	posNew(1,i).render=[]; 
        bbN=bb;
    end
    posNew(1,i).boxes=bbN;
    posNew(1,i).x1=bbN(1);
    posNew(1,i).x2=bbN(3);
    posNew(1,i).sizes=new_size;
end

% erase the examples that the object is out of the pic due to rendering
cnt=0;
for i=1:s1_pos
    if ~isempty(posNew(1,i).render)
       cnt=cnt+1;
       posNew1(1,cnt)=posNew(1,i);
       dataid=dataid+1;
       posNew1(1,cnt).dataids=dataid;
%        st=strfind(posNew1(1,cnt).im,'KinectColor'); % greg, 22/5: Trick for Sid's splits 
%        posNew1(1,cnt).im(1:st-1)=''; posNew1(1,cnt).im=['/home/users/grigoris/Databases/nyu/' posNew1(1,cnt).im];
       posNew1(1,cnt).im=strrep(posNew1(1,cnt).im,'KinectColor',['render_v2/KinectColor_render_' loc_ren]);  % change the location of image, in order to read it from the rendered file
       pos(1,i).render.im=[pos(1,i).render.im;cnt+start_pos];
    end
end
end

function imposNew=horizontal_rendering_impos(imposNew,ts,Zc,a,dataid,render,scaling_factor,se,loc_ren,matRD)
% assumption: in the first for loop there are no flipped images. Following
% DPM 5 hypothesis that all flipped are saved right after the original
% image
black_thres=0.2; 
s1_impos=size(imposNew,2);
im=imreadD2(imposNew(1)); s1=size(im,1); s2=size(im,2);
not_valid=[];not_valid_id=0;
step=2;
cc=1;
if render==2    % in case we have render from the left, we cannot create automatically the flipped images, should be rendered
    step=1; cc=2;
end
for i=1:step:s1_impos
%     imD=imreadD(imposNew(1,i).im, imposNew(1,i).flip);
    tic_toc_print('Positive image=%d with %s\n',i,loc_ren);
    imposNew(1,i).render=render; %rendering (for imreadx)
%      st=strfind(imposNew(1,i).im,'KinectColor'); % greg, 22/5: Trick for Sid's splits 
%        imposNew(1,i).im(1:st-1)=''; imposNew(1,i).im=['/home/users/grigoris/Databases/nyu/' imposNew(1,i).im];
    imposNew(1,i).im=strrep(imposNew(1,i).im,'KinectColor',['render_v2/KinectColor_render_' loc_ren]);  % change the location of image, in order to read it from the rendered file
    im=imreadD2(imposNew(i));
    start1= strfind(imposNew(1,i).im,'/'); end1=strfind(imposNew(1,i).im,'.');
    numImg=str2double(imposNew(1,i).im(start1(end)+1:end1-1));
    if render==1
        im=imrotate(im,90); % for rendering from the top
    elseif render==3
        im=imrotate(im,-90); % for rendering from the bottom
    end
    for j=1:size(imposNew(1,i).dataids,1)
        dataid=dataid+step;
        imposNew(1,i).dataids(j)=dataid;
        bb=round(imposNew(1,i).boxes(j,:));
        if render==1
            bb=circshift(bb,[1 -1]); % new bb for rendering from the top
            bb(2)=size(im,1)-bb(2);bb(4)=size(im,1)-bb(4);
        elseif render==3
            bb=circshift(bb,[-1 1]);
            bb(1)=size(im,2)-bb(1);bb(3)=size(im,2)-bb(3);
        end
        if (render==2)&&(imposNew(1,i).flip)
            [imNew,~]=horizontal_rendering_depth_reliable(im,bb,ts,Zc,a,-1);
        else
            [imNew,~]=horizontal_rendering_depth_reliable(im,bb,ts,Zc,a,1);
        end
        mask=imNew~=0; mask2=imerode(mask,se); mask2=imdilate(mask2,se);
        [r1,c1]=find(mask2~=0);
	    if isempty(r1)
	        bbN=[1 1 1 1]; % dump values to get it out
	    else
	        bbN=[min(c1) min(r1) max(c1) max(r1)];%subplot(2,1,1);showboxes(im,posNew(i).boxes);subplot(2,1,2);showboxes(imNew,bbN)
            if render==1
                bbN=circshift(bbN,[1 1]);  % new bb for rendering from the top
                bbN(1)=size(im,1)-bbN(1)+1;bbN(3)=size(im,1)-bbN(3)+1;
            elseif render==3
                bbN=circshift(bbN,[1 -1]);
                bbN(2)=size(im,2)-bbN(2)+1;bbN(4)=size(im,2)-bbN(4)+1;
            end
            xs=bbN(1):bbN(3);
            if (imposNew(1,i).flip)
                xs=(size(im,cc)-bbN(3)+1):(size(im,cc)-bbN(1)+1);
            end
            imdepth=matRD.depth(bbN(2):bbN(4),xs,numImg); %update 26/9 to read from the depths.mat, less RAM needed
            blacks=length(imdepth(imdepth==0));
      end

        new_size=(bbN(3)-bbN(1)+1)*(bbN(4)-bbN(2)+1);
        if (new_size<scaling_factor*imposNew(1,i).sizes(j))||(blacks>black_thres*imposNew(1,i).sizes(j)) % if the new bbox is too small, then we discard this example
            not_valid_id=not_valid_id+1;
            not_valid(not_valid_id,1)=i;
            not_valid(not_valid_id,2)=j; 
        end    
        imposNew(1,i).boxes(j,:)=bbN;
        imposNew(1,i).sizes(j)=new_size;
    end
end



if (not_valid_id>0)
    % discard the empty boxes
    imposNew1=discard_empty_boxes(imposNew,not_valid,not_valid_id);
    clear imposNew;
    imposNew=imposNew1;
end

% create the flipped example for each image
if render~=2
    for i=1:2:size(imposNew,2)
        imposNew(1,i+1).im=imposNew(1,i).im;
        imposNew(1,i+1).render=imposNew(1,i).render;
         for j=1:size(imposNew(1,i).dataids,1)
             imposNew(1,i+1).boxes(j,:)=[s2-imposNew(1,i).boxes(j,3)+1 imposNew(1,i).boxes(j,2) s2-imposNew(1,i).boxes(j,1)+1 imposNew(1,i+1).boxes(j,4)];
             imposNew(1,i+1).dataids(j)=imposNew(1,i).dataids(j)+1;
         end

    end
end
end

function imposNew_ret=discard_empty_boxes(imposNew,not_valid,not_valid_id)
s1_impos=size(imposNew,2);
imposNew1=imposNew;
for i=not_valid_id:-1:1 % reverse order in order to keep the indices correct in case of more empty boxes in the same image
    idx=not_valid(i,1); idx_ob=not_valid(i,2);
    if ~isfield(imposNew(1,idx),'deleted')
        imposNew(1,idx).deleted=0;
    else
        imposNew(1,idx).deleted=imposNew(1,idx).deleted+1;
    end
    if (size(imposNew(1,idx).sizes,1)-imposNew(1,idx).deleted>1)    % simply remove this item
        cnt=0;
        for obj=1:size(imposNew(1,idx).sizes,1) %copy all elements apart from the one that has empty boxes
            if (obj~=idx_ob)
                cnt=cnt+1;
                imposNew1(1,idx).boxes(cnt,:)=imposNew(1,idx).boxes(obj,:);
                imposNew1(1,idx).sizes(cnt)=imposNew(1,idx).sizes(obj);
                imposNew1(1,idx).dataids(cnt)=imposNew(1,idx).dataids(obj);
            end
        end
        imposNew1(1,idx).boxes=imposNew1(1,idx).boxes(1:end-1,:);
        imposNew1(1,idx).sizes=imposNew1(1,idx).sizes(1:end-1);
        imposNew1(1,idx).dataids=imposNew1(1,idx).dataids(1:end-1);
    else
        imposNew1(1,idx).render=[];
    end
end 

% discard the impos that don't have any "new" bbox
%clear imposNew;
cnt=0;
for i=1:2:s1_impos
    if ~isempty(imposNew1(1,i).render)
       cnt=cnt+1;
       imposNew_ret(1,cnt)=imposNew1(1,i);
       cnt=cnt+1;                        %for the flipped image
       imposNew_ret(1,cnt)=imposNew1(1,i+1);
    end
end
end


function [imNew,out_cnt]=horizontal_rendering_depth_reliable(im,box,ts,Zc,a,render)
% gia orizontia metatopisi
%render: -1 gia deksia apospi, +1 gia aristeri
imNew=zeros(size(im), 'uint16');imD=double(im);
%imNew=im;
s2=size(imNew,2); 
out_cnt=0; %used to count how many elements are out of the image after the bbox is placed in its new position
for cnt=box(2):box(4)                       %only interested for rendering what is inside our box
    for j=box(1):box(3)
      
        Z=imD(cnt,j);
        new_place=round(j+render*a*ts/2*(1/Z-1/Zc));
        if (new_place>0)&&(new_place<=s2)
             imNew(cnt,new_place,:)=im(cnt,j,:);
        else
            out_cnt=out_cnt+1;
        end
    end
end

end
