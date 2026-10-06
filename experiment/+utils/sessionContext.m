function context = sessionContext(action,sess,varargin)
%UTILS.SESSIONCONTEXT Bind a battery/task independent of its domain-derived ID.
prefix = sprintf('sub-%05d_ses-%02d',sess.participant,sess.sessionNum);
context = struct('participant',sess.participant,'session',sess.sessionNum, ...
    'runKind',sess.runKind,'assignment',sess.assignment, ...
    'signature',utils.runCheckpoint('signature',sess));
switch lower(action)
    case 'battery'
        context.battery = varargin{1};
        file = fullfile(sess.cfg.paths.sessions,[prefix '_battery-context.mat']);
    case 'run'
        context.task = char(varargin{1}); context.domains = varargin{2};
        file = fullfile(sess.cfg.paths.sessions,[prefix '_task-' context.task '-context.mat']);
        batteryFile = fullfile(sess.cfg.paths.sessions,[prefix '_battery-context.mat']);
        if isfile(batteryFile)
            saved = load(batteryFile,'context'); battery = saved.context.battery;
            matches = cellfun(@(r) strcmp(r.task,context.task) && isequal(r.domains,context.domains),battery);
            assert(sum(matches) == 1 && isequaln(saved.context.signature,context.signature), ...
                'hw:sessionContext:incompatible', 'Run differs from the frozen session battery.');
        end
    otherwise
        error('hw:sessionContext:action','Unknown session context action.');
end
if isfile(file)
    saved = load(file,'context');
    assert(isequaln(saved.context,context),'hw:sessionContext:incompatible', ...
        'Session battery, assignment, task domains or configuration changed; refusing a second logical run.');
else
    utils.checkpointIO('write',file,struct('context',context));
end
end
