global G_STARTUP;

if isempty(G_STARTUP)
  G_STARTUP = true;

  % Avoiding addpath(genpath('.')) because .git includes
  % a VERY large number of subdirectories, which makes 
  % startup slow
  incl = {'new_code_greg','greg_code_from_voc_5'};
  for i = 1:length(incl)
    addpath(genpath(incl{i}));
  end
  fprintf('DPM for sparse codes is set up\n');
  clear i incl;
end
