function T = auctionTrialTable(dom, Tr, anchor)
%UTILS.AUCTIONTRIALTABLE  Long-format one row per trial, for the CSV.
rows = {};
    for t = 1:numel(Tr)
        rows{end+1} = { dom, Tr(t).trial, Tr(t).practice, Tr(t).competition, ...
            Tr(t).block, Tr(t).blockPos, Tr(t).nAttrs, ...
            Tr(t).nPresented, Tr(t).nRejected, rejectedList(Tr(t).rejected), Tr(t).duration, ...
            Tr(t).bidAccepted, Tr(t).bid, Tr(t).bidRT, Tr(t).bidStartFrac, ...
            Tr(t).threshold, Tr(t).pricePaid, ...
            Tr(t).trueValue, Tr(t).bidStimIdx, Tr(t).endReason, ...
            anchor }; %#ok<AGROW>
    end
if isempty(rows), T = table(); return; end
M = vertcat(rows{:});
T = cell2table(M, 'VariableNames', {'domain','trial','practice','competition', ...
    'block','blockPos','nAttrs', ...
    'nPresented','nRejected','rejectedStimIdx','durationSec','bidAccepted','bid','bidRT', ...
    'bidStartFrac','threshold','pricePaid','trueValue','bidStimIdx','endReason','anchor'});
end


%% ======================================================================
function s = rejectedList(idx)
%REJECTEDLIST  Rejected stimulus indices as one semicolon-joined string.
%   '' for none, '14', '14;27;31'; order is rejection order.

if isempty(idx)
    s = "";
    return
end
s = string(strjoin(arrayfun(@(k) sprintf('%d', k), idx(:)', 'UniformOutput', false), ';'));
end
