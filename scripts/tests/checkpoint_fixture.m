function [f, a] = checkpoint_fixture(root, overrides)
%CHECKPOINT_FIXTURE  A committed one-block run, without running a task.
%
%   [f,a] = checkpoint_fixture(root)
%   [f,a] = checkpoint_fixture(root, overrides)
%
% overrides is an optional struct whose fields replace fields of the committed
% block payload (trials, trialTable, events, metadata, clockSync, gaze). Omit it
% and the payload is exactly what it has always been, so existing cases are
% untouched. test_session_tail uses it to supply the `metadata.eyeTracking` and
% non-empty `events` that the derived exports are built from -- the default
% payload carries neither, so export_gaze_csv writes no _et.csv and no
% events CSV for it.
if nargin < 2 || isempty(overrides), overrides = struct(); end
f.root = root; f.cfg.paths.checkpoints = fullfile(root,'blocks');
id = 'sub-09999_ses-01_task-contdc_dom-houses';
f.run = struct('runId',id,'task','contdc','domains',{{'houses'}},'participant',9999, ...
    'sessionNum',1,'runKind','practice');
record = struct('run',f.run,'signature',struct('schemaVersion',1));
utils.checkpointIO('write',fullfile(root,'runs',id,'run.mat'),struct('record',record));
frozen = struct('blockCount',1);
utils.checkpointIO('write',fullfile(root,'runs',id,'houses-plan.mat'),struct('frozen',frozen));
c = struct('schemaVersion',1,'participant',9999,'session',1,'task','contdc', ...
    'domain','houses','runKind','practice','logicalRunId',[id '_houses'], ...
    'blockOrdinal',1,'parentAttemptId','');
a = utils.beginBlock(f.cfg,c,struct('seed',1));
tr = struct('level',2,'taskType','choice','pairIdx',1,'timedOut',false,'choseMoney',true, ...
    'isMoneyOption',NaN,'price',NaN);
p = struct('trials',tr,'trialTable',table("houses",1,'VariableNames',{'domain','trial'}), ...
    'events',table(),'metadata',struct(),'clockSync',struct(),'gaze',[], 'nextState',struct('seed',2));
for fn = reshape(fieldnames(overrides),1,[])
    p.(fn{1}) = overrides.(fn{1});
end
utils.commitBlock(f.cfg,a,p);
end
