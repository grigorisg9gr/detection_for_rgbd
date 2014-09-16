function conf = override_voc(sn)
% Sample config override file
%
% To use this execute:
% >> global VOC_CONFIG_OVERRIDE;
% >> VOC_CONFIG_OVERRIDE = @override_voc;

% AUTORIGHTS
% -------------------------------------------------------
% Copyright (C) 2011-2012 Ross Girshick
%
% This file is part of the voc-releaseX code
% (http://people.cs.uchicago.edu/~rbg/latent/)
% and is available under the terms of an MIT-like license
% provided in COPYING. Please retain this notice and
% COPYING if you use this file (or a portion of it) in
% your project.
% -------------------------------------------------------
% global sn; sn=1; conf=voc_config; 
global sn
conf.split = ['split' num2str(sn)];


