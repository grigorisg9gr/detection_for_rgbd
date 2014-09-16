function viewdet(id,cls,onlytp)

if nargin<2
    error(['usage: viewdet(competition,class,onlytp) e.g. viewdet(''comp3'',''car'') or ' ...
            'viewdet(''comp3'',''car'',true) to show true positives']);
end

if nargin<3
    onlytp=false;
end

linewidth=4;
conf=voc_config; 
cachedir = conf.paths.model_dir; 
testset = conf.eval.test_set;
VOCopts    = conf.paths.db_annotation_dir;
tic

% change this path if you install the VOC code elsewhere
addpath([cd '/VOCcode']);

% initialize VOC options
%VOCinit;

% load test set
% cp=sprintf(VOCopts.annocachepath,VOCopts.testset);
% if exist(cp,'file')
%     fprintf('%s: pr: loading ground truth\n',cls);
%     load(cp,'gtids','recs');
% else
    %gtids=textread(sprintf(VOCopts.imgsetpath,VOCopts.testset),'%s');
    [gtids,t]=textread(sprintf('%s%s%s%s%s',VOCopts,cls,'_', testset,'.txt'),'%s %d');
    for i=1:length(gtids)
        % display progress
        if toc>1
            fprintf('%s: load: %d/%d\n',cls,i,length(gtids));
            drawnow;
            tic;
        end

        % read annotation
        %recs(i)=PASreadrecord(sprintf(VOCopts.annopath,gtids{i}));
	recs(i)=PASreadrecord(sprintf('%s%s%s%s%s%s',conf.paths.db_base_dir,'nyu/Annotations/',cls,'/', gtids{i}, '.xml'));
    end
    %save(cp,'gtids','recs');
%end

% extract ground truth objects

npos=0;
gt(length(gtids))=struct('BB',[],'diff',[],'det',[]);
for i=1:length(gtids)
    % extract objects of class
    clsinds=strmatch(cls,{recs(i).objects(:).class},'exact');
    gt(i).BB=cat(1,recs(i).objects(clsinds).bbox)';
    gt(i).diff=[recs(i).objects(clsinds).difficult];
    gt(i).det=false(length(clsinds),1);
    npos=npos+sum(~gt(i).diff);
end

% load results
%[ids,confidence,b1,b2,b3,b4]=textread(sprintf(VOCopts.detrespath,id,cls),'%s %f %f %f %f %f');
[ids,confidence,b1,b2,b3,b4]=textread(sprintf('%s%s', cachedir,cls),'%s %f %f %f %f %f');
BB=[b1 b2 b3 b4]';

% sort detections by decreasing confidence
[sc,si]=sort(-confidence);
ids=ids(si);
BB=BB(:,si);

% view detections

clf;
nd=length(confidence);
tic;
for d=1:nd
    % display progress
    if onlytp&toc>1
        fprintf('%s: viewdet: find true pos: %d/%d\n',cls,i,length(gtids));
        drawnow;
        tic;
    end
    
    % find ground truth image
    i=strmatch(ids{d},gtids,'exact');
    if isempty(i)
        error('unrecognized image "%s"',ids{d});
    elseif length(i)>1
        error('multiple image "%s"',ids{d});
    end

    % assign detection to ground truth object if any
    bb=BB(:,d);
    ovmax=-inf;
    for j=1:size(gt(i).BB,2)
        bbgt=gt(i).BB(:,j);
        bi=[max(bb(1),bbgt(1)) ; max(bb(2),bbgt(2)) ; min(bb(3),bbgt(3)) ; min(bb(4),bbgt(4))];
        iw=bi(3)-bi(1)+1;
        ih=bi(4)-bi(2)+1;
        if iw>0 & ih>0                
            % compute overlap as area of intersection / area of union
            ua=(bb(3)-bb(1)+1)*(bb(4)-bb(2)+1)+...
               (bbgt(3)-bbgt(1)+1)*(bbgt(4)-bbgt(2)+1)-...
               iw*ih;
            ov=iw*ih/ua;
            if ov>ovmax
                ovmax=ov;
                jmax=j;
            end
        end
    end

    % skip false positives
    if onlytp&ovmax<0.5 %VOCopts.minoverlap
        continue
    end
    
    % read image
    %I=imread(sprintf(VOCopts.imgpath,gtids{i}));
    I=imread(sprintf('%s%s%s%s',conf.paths.db_base_dir,'nyu/KinectColor/',gtids{i}, '.png'));

    % draw detection bounding box and ground truth bounding box (if any)
    imagesc(I);
    hold on;
    if ovmax>=0.5 %VOCopts.minoverlap
        bbgt=gt(i).BB(:,jmax);
        plot(bbgt([1 3 3 1 1]),bbgt([2 2 4 4 2]),'y-','linewidth',linewidth);
        plot(bb([1 3 3 1 1]),bb([2 2 4 4 2]),'g--','linewidth',linewidth+2);
    else
        plot(bb([1 3 3 1 1]),bb([2 2 4 4 2]),'r-','linewidth',linewidth);
    end    
    hold off;
    axis image;
    axis off;
%     title(sprintf('det %d/%d: image: "%s" (green=true pos,red=false pos,yellow=ground truth',...
%             d,nd,gtids{i}),'interpreter','none');
    filename=[cachedir '/' cls '_' num2str(d)];
    if d<=10    % write only 10 top positive
        print(gcf, '-depsc2', '-r0', [filename '.eps']);
    end
%     fprintf('press any key to continue with next image\n');
%     pause;
end
