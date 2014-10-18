function f = flipfeat_voc5(f)
%greg, 5/11: Same as used in voc-release 5 in order to adapt the model to sparse coding form
% Horizontally flip HOG features (or filters).
%   f = flipfeat(f)
% 
%   Used for learning models with mirrored filters.
%
% Return value
%   f   Output, flipped features
%
% Arguments
%   f   Input features

% flip permutation
p1 = [10  9  8  7  6  5  4  3  2 ... % 1st set of contrast sensitive features
      1 18 17 16 15 14 13 12 11 ... % 2nd set of contrast sensitive features
     19 27 26 25 24 23 22 21 20 ... % Contrast insensitive features
     30 31 28 29 ...                % Gradient/texture energy features
     32];                           % Boundary truncation feature
 %error('wrong place, flipfeat');
 if (size(f,3)>32) %dld stin periptwsi poy exoyme kai depth
     p2=p1+32;
     p=[p1,p2];
 else
     
     p=p1;
 end
f = f(:,end:-1:1,p);
