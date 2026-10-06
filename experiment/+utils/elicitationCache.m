function out = elicitationCache(action, sess, domain, data)
%UTILS.ELICITATIONCACHE  Reuse a participant's budget/attribute ratings
%across tasks run in the SAME session, without re-asking.
%
%   cached = utils.elicitationCache('load', sess, domain)   [] if none
%   utils.elicitationCache('save', sess, domain, data)
%
%   Keyed on (participant, sessionNum, domain), stored on disk; a new
%   session number is a deliberate cache miss.

f = fullfile(sess.cfg.paths.sessions, sprintf('sub-%05d_ses-%02d_%s_elicitation.mat', ...
    sess.participant, sess.sessionNum, lower(char(domain))));

switch lower(action)
    case 'load'
        if exist(f, 'file')
            L = load(f, 'data');
            out = L.data;
            % Old caches lack coreRatings; normalise here so the second task still runs.
            if ~isfield(out, 'coreRatings'), out.coreRatings = []; end
            if ~isfield(out, 'coreRTs'),     out.coreRTs     = []; end
            fprintf('Reusing %s elicitation from earlier this session (%s).\n', ...
                domain, f);
        else
            out = [];
        end

    case 'save'
        data.savedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
        utils.checkpointIO('write', f, struct('data', data), true);
        out = [];

    otherwise
        error('hw:elicitationCache:badAction', 'Unknown action "%s".', action);
end

end
