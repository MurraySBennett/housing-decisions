function done = runComplete(sess, run)
%UTILS.RUNCOMPLETE True when every domain has all its frozen blocks committed.
%
% A run is complete when, for each domain, a plan was frozen AND the number of
% verified block receipts equals the plan's blockCount. Anything less -- no
% plan yet, or fewer receipts than blocks -- is an incomplete run that
% recovery will resume, never a complete one.
done = true;
for k = 1:numel(run.domains)
    domain = run.domains{k};
    frozen = utils.frozenPlan(sess, run, domain);
    if isempty(frozen) || ~isfield(frozen, 'blockCount'), done = false; return; end
    state = utils.blockStore('recover', sess.cfg, [run.runId '_' domain]);
    if numel(state.receipts) ~= frozen.blockCount, done = false; return; end
end
end
