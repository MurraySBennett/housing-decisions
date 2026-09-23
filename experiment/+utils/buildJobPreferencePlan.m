function plan = buildJobPreferencePlan(stimTbl, nPwc, rngStream)
%UTILS.BUILDJOBPREFERENCEPLAN  Pairwise job-preference trials.
%
%   plan = utils.buildJobPreferencePlan(stimTbl, 160, rs)
%
%   The stimulus unit is one job shown as industry + job title only --
%   no wage, no attributes. Unlike the houses version, pairs mix freely
%   across industries. Pass the ECOLOGICAL arm's table: the synthetic arm
%   carries placeholder titles (title_001) that must never reach a screen.

if nargin < 3 || isempty(rngStream), rngStream = RandStream.getGlobalStream; end

if any(startsWith(string(stimTbl.title), 'title_'))
    error('hw:jobPref:placeholderTitles', ...
        ['Job titles look like synthetic placeholders (title_...). ' ...
         'The preference task needs the ecological stimulus file.']);
end

jobTable = table((1:height(stimTbl))', string(stimTbl.industry), ...
    string(stimTbl.title), ...
    'VariableNames', {'jobIdx','industry','title'});

plan.jobTable = jobTable;
plan.pwcPairs = utils.samplePairs(1:height(jobTable), nPwc, rngStream);
plan.nPwc     = nPwc;
end
