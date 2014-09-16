function compile(opt, verb, mex_file)
% Build MEX source code.
%   All compiled binaries are placed in the bin/ directory.
%
%   Windows users: Windows is not yet supported. You can likely 
%   get the code to compile with some modifications, but please 
%   do not email to ask for support.
%
% Arguments
%   opt   Compile with optimizations (default: on)
%   verb  Verbose output (default: off)

if ispc
  error('This code is not supported on Windows.');
end

if nargin < 1
  opt = true;
end

if nargin < 2
  verb = false;
end

% Start building the mex command
mexcmd = 'mex -outdir bin';

% Add verbosity if requested
if verb
  mexcmd = [mexcmd ' -v'];
end

% Add optimizations if requested
if opt
  mexcmd = [mexcmd ' -O'];
  mexcmd = [mexcmd ' CXXOPTIMFLAGS="-O3 -DNDEBUG"'];
  mexcmd = [mexcmd ' LDOPTIMFLAGS="-O3"'];
else
  mexcmd = [mexcmd ' -g'];
end

% Turn all warnings on
mexcmd = [mexcmd ' CXXFLAGS="\$CXXFLAGS -Wall"'];
mexcmd = [mexcmd ' LDFLAGS="\$LDFLAGS -Wall"'];

if nargin < 3
  % Build feature vector cache code
  fv_compile(opt, verb);
  % Build the star-cascade code
  cascade_compile(opt, verb);

  eval([mexcmd ' features/resize.cc']);
  eval([mexcmd ' features/features.cc']);
  eval([mexcmd ' features/features_64.cc']);
%   eval([mexcmd ' features/features_only_depth.cc -o features_only_depth']);
  eval([mexcmd ' gdetect/dt.cc']);
  eval([mexcmd ' gdetect/bounded_dt.cc']);
  eval([mexcmd ' gdetect/get_detection_trees.cc']);
  eval([mexcmd ' gdetect/compute_overlap.cc']);
  
  eval([mexcmd ' features/im2blocks.cc']);
  eval([mexcmd ' features/make_feats_idea7.cc']);

  % Convolution routine
  %   Use one of the following depending on your setup
  %   (0) is fastest, (1) is slower

  % 0) multithreaded convolution using SSE
  eval([mexcmd ' gdetect/fconvsse.cc -o fconv']);
%   eval([mexcmd ' gdetect/fconvsse_dispF.cc -o fconv_dispF']);
  % 1) multithreaded convolution
  eval([mexcmd ' gdetect/fconv_var_dim_MT_voc5.cc -o fconv_var_dim_voc5']);

  % Convolution routine that displacement features are computed:
  eval([mexcmd ' gdetect/fconv_var_dim_MT.cc -o fconv_var_dim']);    
  eval([mexcmd ' gdetect/fconv_var_dim_MT_separate.cc -o fconv_var_dim_separate']);     % Version of idea_7, but the convolution and the computation of displacement feats is in different functions
else
  eval([mexcmd ' ' mex_file]);
end
