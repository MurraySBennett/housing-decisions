function [f, a] = checkpoint_fixture(root)
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
a = utils.blockStore('begin',f.cfg,c,struct('seed',1));
tr = struct('level',2,'taskType','choice','pairIdx',1,'timedOut',false,'choseMoney',true, ...
    'isMoneyOption',NaN,'price',NaN);
p = struct('trials',tr,'trialTable',table("houses",1,'VariableNames',{'domain','trial'}), ...
    'events',table(),'metadata',struct(),'clockSync',struct(),'gaze',[], 'nextState',struct('seed',2));
utils.blockStore('commit',f.cfg,a,p);
end
