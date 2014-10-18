function render3_dir(num, HOME )
% greg, 8/4
%   num 		rendering angle in k (*1000)
%
%
% Copyright (C) 2014 Grigorios Chrysos
% available under the terms of the Apache License, Version 2.0

if nargin<2
    HOME='/home/users/grigoris/Databases/nyu/render_v2/';
end

% load database object 
addpath('/home/users/grigoris/Databases/nyu/');   % should also include the NYU toolbox (bilateral filtering function is used).
readNyuDatabase;

% parameters of rendering (direction, rotation angle (of image))   
direction={'top','left','bottom'};
rotate=[90,0,-90];
for ii=1:size(direction,2)
    argb=[HOME 'KinectColor_render_' direction{ii} '_' num2str(num) 'k'];
    ad=[HOME 'RegisteredDepthData_render_' direction{ii} '_' num2str(num) 'k'];
    exists_or_mkdir(argb); exists_or_mkdir(ad);
    rotation=rotate(ii);
    tic
    %% main rendering for all images
    for i=1:1449
        fprintf('Processing image nr=%d\n',i);
        im=images(:,:,:,i);
        imD=rawDepths(:,:,i); imD_inp=depths(:,:,i);
        im=imrotate(im,rotation); imD=imrotate(imD,rotation); imD_inp=imrotate(imD_inp,rotation);
        [ imNew,imNewD ] = render_raw_image(im,imD,imD_inp,num/10,150,0 ); 
        %imN{floor(i/2)+1}=imNew;
        [~,c]=find(imNewD~=0);
        imNewD(:,1:min(c))=10;  
        depth(:,:,i)=imrotate(imNewD,(-1)*rotation);
        imN_inpainted{i} = inptaint_rgb_background( imNew, imNewD);
        imgDepthFilled{i} = fill_depth_cross_bf(imN_inpainted{i},imNewD);
        
    end
    toc
    
% write results to files 
    for i=1:1449
        imwrite(imrotate(imN_inpainted{i},(-1)*rotation),sprintf('%s/%d%s',argb,i,'.png'),'BitDepth',8);
        fprintf('Writing image nr. %d\n',i);
    end
    try
        save([ad '/rendered_depth.mat'],'depth','-v7.3');
    catch 
        fprintf('Depth rendered not saved\n');
    end
    for i=1:1449
        imwrite(imrotate(uint16(imgDepthFilled{i}*10000),(-1)*rotation),sprintf('%s/%d%s',ad,i,'_abs_smooth.png'),'BitDepth',16);
        fprintf('Writing image nr. %d\n',i);
    end
end
end

% Make directory path if it does not already exist.
function made = exists_or_mkdir(path)
made = false;
if exist(path) == 0
  unix(['mkdir -p ' path]);
  made = true;
end
end
