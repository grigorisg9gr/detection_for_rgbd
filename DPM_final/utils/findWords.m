function findWords( nameTocheck,option_for_mex,searchOption )
%greg, 22/9/2013 skopos na vriskei lekseis poy yparxoyn mesa se arxeia, eite einai se ayto ton fakelo eite se ypofakeloys 
%option_for_mex: epilogi na scanarei kai ta arxeia c++. An option_for_mex=1
%tote ta skanarei

if nargin < 2
  option_for_mex=0;
end
if nargin<3
   searchOption=1;
end

addpath('/home/grigoris/Documents/repos/feats_displacement/idea7_clean2/new_code_greg'); %wste na trexei stoys emfwlemeynoys fakeloys
initialDir=dir; 
parfor i=3:size(initialDir,1) %ta dyo prwta einai: . kai ..
    if (initialDir(i).isdir) %tote prepei anadromika na diavasei ta arxeia ston fakelo
%         i
%         initialDir(i).name
        cd(initialDir(i).name)
        findWords( nameTocheck,option_for_mex,searchOption );
        cd ../
    else %dld an einai arxeio 
        U=strfind(initialDir(i).name,'.');
        if (isempty(U)==0) %dld an periexetai i '.'
            temp=U(end); %theloyme tin teleytaia . toy arxeioy gia tin kataliksi
            fileType=initialDir(i).name(temp:end); %kataliksi toy arxeioy
            if ((option_for_mex)&&((strcmp(fileType,'.cc'))||(strcmp(fileType,'.c'))))
                %tote prepei na elegxthei
                check_option(nameTocheck,initialDir(i).name,searchOption)
            elseif strcmp(fileType,'.m')
                %initialDir(i).name
                %tote prepei na elegxthei
                check_option(nameTocheck,initialDir(i).name,searchOption)
            end
        end
    end
end
end


function check_option(nameTocheck,fileName,searchOption)
if (searchOption==1)
    %searchOption
    check_inside_file(nameTocheck,fileName)
else
    check_inside_file_complex(nameTocheck,fileName)   
end
end

function check_inside_file(nameTocheck,fileName) %anoigei sygekrimeno arxeio kai kanei ton eelgxogia tin leksi
  fid = fopen(fileName);        
  results = textscan(fid, '%s');
  cnt2=0; %counter of times the word appears
  for cnt=1:size(results{1,1},1)
      U = strfind(results{1,1}(cnt), nameTocheck);
      if (isempty(U{1})==0) %dld an periexetai i frasi
          cnt2=cnt2+1;
      end
  end
  if (cnt2>0)
      fprintf('In the \"%s\"\t the name \"%s\" appears %d times\n',fileName,nameTocheck,cnt2);
  end
end

function check_inside_file_complex(nameTocheck,fileName)
    Str   = fileread(fileName);
    match = strfind(Str, nameTocheck);
    if (isempty(match)==0) %then found 
       fprintf('The \"%s\"\t appears in the \"%s\"\n',nameTocheck,fileName); 
    end
end
%αντι για την τελευταία μπορεί να χρησιμοποιηθεί και η εξής εναλλακτική
%(alternative): 
% Str   = fileread('execute_inria.m');
% match = strfind(Str, 'compile');

