function str = identityString(stimTbl, sel, idx)
%UTILS.IDENTITYSTRING  Text header for the identity attributes.
%
%   Image-kind identity attributes are SKIPPED: they are rendered as
%   pictures by utils.drawIdentityStrip, and their column values are
%   filenames -- including them here printed "ext1.png - kit1.png -
%   bed1.png ..." as the header, which is what the stray label text under
%   the photos actually was.

parts = {};
for k = 1:numel(sel.identity)
    if strcmp(sel.identity(k).kind, 'image'), continue; end
    v = sel.identity(k).var;
    if ismember(v, stimTbl.Properties.VariableNames)
        val = stimTbl.(v)(idx);
        if iscell(val), val = val{1}; end
        if ischar(val) || isstring(val)
            parts{end+1} = char(val); %#ok<AGROW>
        end
    end
end
if isempty(parts), str = ''; else, str = strjoin(parts, '  -  '); end
end
