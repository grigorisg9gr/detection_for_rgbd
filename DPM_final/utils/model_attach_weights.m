function model = model_attach_weights(model)

for i = 1:model.numfilters
  w = model_get_block(model, model.filters(i));
  model.filters(i).w = w;
end

for i = 1:length(model.rules)
  if isempty(model.rules{i}), continue; end

  for j = 1:length(model.rules{i})
    fns = fieldnames(model.rules{i}(j));
    for k = 1:length(fns)
      f = fns{k};
      %if isfield(model.rules{i}(j), 'blocklabel')
      if isfield(model.rules{i}(j).(f), 'blocklabel')
        w = model_get_block(model, model.rules{i}(j).(f));
        model.rules{i}(j).(f).w = w;
        %greg, 5/11: .loc also considered in the if
      end
    end
  end
end
