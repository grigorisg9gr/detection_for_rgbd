% function model = anchorshift(model)
% Shifts anchor points of each deformation parameter to 
% lie at the minimum of quadratic deformation cost
  function model = anchorshift(model)
  
  for i = 1:length(model.defs),
    d = model.defs(i);
    w = d.w;
    if length(w) > 1,
      % compute minimum of  f(x) = ax^2 + bx
      % shifted quadratic f(x-s) = a(x-s)^2 + b(x-s) = ax^2 - 2asx + bx + c
      a = w(1);
      b = w(2);
      s = round(b/(-2*a));
      s = -s;
      d.anchor(1) = d.anchor(1) + s;
      d.w(2) = b - 2*a*s;
      
      a = w(3);
      b = w(4);
      s = round(b/(-2*a));
      s = -s;
      d.anchor(2) = d.anchor(2) + s;
      d.w(4) = b - 2*a*s;
      
      model.defs(i) = d;
    end
  end
