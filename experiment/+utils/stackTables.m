function result = stackTables(tables)
%UTILS.STACKTABLES Join optional event/behavior columns without changing types.
tables = tables(~cellfun(@isempty, tables));
if isempty(tables), result = table(); return; end
names = {};
for k = 1:numel(tables), names = union(names, tables{k}.Properties.VariableNames, 'stable'); end
for j = 1:numel(names)
    name = names{j}; present = cellfun(@(t) ismember(name,t.Properties.VariableNames), tables);
    examples = cellfun(@(t) t.(name),tables(present),'UniformOutput',false);
    useCells = any(cellfun(@iscell,examples));
    useStrings = ~useCells && all(cellfun(@(v) isstring(v) || ischar(v),examples));
    for k = 1:numel(tables)
        if ~present(k)
            if useStrings, tables{k}.(name) = strings(height(tables{k}),1);
            elseif useCells, tables{k}.(name) = repmat({NaN},height(tables{k}),1);
            else, tables{k}.(name) = nan(height(tables{k}),1); end
        elseif useCells && ~iscell(tables{k}.(name))
            if ischar(tables{k}.(name)), tables{k}.(name) = cellstr(tables{k}.(name));
            else, tables{k}.(name) = num2cell(tables{k}.(name)); end
        elseif useStrings
            tables{k}.(name) = string(tables{k}.(name));
        end
    end
end
for k = 1:numel(tables), tables{k} = tables{k}(:,names); end
result = vertcat(tables{:});
end
