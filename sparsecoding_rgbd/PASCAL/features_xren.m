
function f=features_xren(im,sbin)

assert(sbin==8);

persistent encoder encoderD;
if isempty(encoder),
  %load('greg_5x5_rgb_99_spa1.mat','dic_first');
  load('bsds500_5x5_first_99_spa1.mat','dic_first');
  encoder=dic_first;
  encoder.type='gray';
  encoder.blocksize=8;  % max pooling on 8x8 pixels
  encoder.numblock=1;
  encoder.sparsity=1;
  encoder.power_trans=0.25;
  encoder.pad_zero=3;   %  3 to add three columns of zero
  encoder.threshold=0.001;
  encoder.norm=2; % 'L2';
  
  load('greg_new_5x5_depth_99_spa1.mat','dic_first');
  encoderD=dic_first; 
  encoderD.type='gray';
  encoderD.blocksize=8;  % max pooling on 8x8 pixels
  encoderD.numblock=1;
  encoderD.sparsity=1;
  encoderD.power_trans=0.25;
  encoderD.pad_zero=3;   %  3 to add three columns of zero
  encoderD.threshold=0.001;
  encoderD.norm=2; % 'L2';
  
end

f=features_hsc_3(im,sbin,encoder,encoderD);



