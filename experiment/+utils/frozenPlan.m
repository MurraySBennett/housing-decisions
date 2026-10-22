function frozen = frozenPlan(sess, run, domain, proposed)
%UTILS.FROZENPLAN The per-domain plan, frozen once per run.
%
%   frozen = utils.frozenPlan(sess, run, domain)            read-only:
%       the frozen plan, or [] when this run has not frozen one yet.
%   frozen = utils.frozenPlan(sess, run, domain, proposed)  freeze:
%       stores `proposed` on first call; EVERY later call returns what was
%       frozen first and ignores the new proposal. That is the point: a
%       resumed run must replay the plan it started with, not build a new one.
%
% Each task freezes its own shape (auction: trialPlan rows; preference:
% buildPhotoPreferencePlan; contdc: its elicitation + pairs struct).
file = fullfile(sess.cfg.paths.runs, run.runId, [domain '-plan.mat']);
if isfile(file)
    s = load(file, 'frozen'); frozen = s.frozen;
    return
end
if nargin < 4
    frozen = [];
    return
end
utils.checkpointIO('write', file, struct('frozen', proposed));
frozen = proposed;
end
