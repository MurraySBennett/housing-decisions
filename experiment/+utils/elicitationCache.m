function out = elicitationCache(action, sess, domain, data)
%UTILS.ELICITATIONCACHE  Reuse a participant's budget/attribute ratings
%across tasks run in the SAME session, without re-asking.
%
%   cached = utils.elicitationCache('load', sess, domain)
%       Returns the cached elicitation struct, or [] if none exists yet
%       for this participant + session + domain.
%
%   utils.elicitationCache('save', sess, domain, data)
%       Saves it for reuse by the next task this session.
%
%   Keyed on (participant, sessionNum, domain) and stored on disk, not in
%   memory -- this works whether the two tasks run back-to-back inside one
%   run_battery call or as two completely separate MATLAB invocations later
%   the same day, as long as the session number matches.
%
%   A NEW session number is a deliberate cache miss: if there's a real
%   break between sessions (a different day), re-eliciting is the right
%   call -- it gives a fresh, consistent measurement rather than reusing a
%   stated budget or set of attribute ratings that may no longer reflect
%   how the participant is thinking today.

f = fullfile(sess.cfg.paths.sessions, sprintf('sub-%05d_ses-%02d_%s_elicitation.mat', ...
    sess.participant, sess.sessionNum, lower(char(domain))));

switch lower(action)
    case 'load'
        if exist(f, 'file')
            L = load(f, 'data');
            out = L.data;
            fprintf('Reusing %s elicitation from earlier this session (%s).\n', ...
                domain, f);
        else
            out = [];
        end

    case 'save'
        data.savedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
        save(f, 'data');
        out = [];

    otherwise
        error('hw:elicitationCache:badAction', 'Unknown action "%s".', action);
end

end
