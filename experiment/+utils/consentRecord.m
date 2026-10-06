function out = consentRecord(action, sess, varargin)
%UTILS.CONSENTRECORD  The on-disk consent confirmation for one participant/session.
%
%   file = utils.consentRecord('file', sess)
%   info = utils.consentRecord('read', sess)   % [] when none is on file
%          utils.consentRecord('write', sess, info)
%
%   One record per participant and session, written once. A resumed session
%   reads it instead of consenting again, so this file is the evidence that
%   consent preceded participation -- including its original timestamps. It is
%   therefore never overwritten: a second write keeps the first file untouched
%   and lands beside it, because an audit trail that can be replaced by a later
%   run is not an audit trail.
%
%   Lives in the LOCAL session tree, so a different rig sees no record and will
%   consent again. That is the safe direction: re-asking is recoverable,
%   silently skipping consent is not.

switch lower(action)
    case 'file'
        out = fullfile(sess.cfg.paths.sessions, ...
            sprintf('sub-%05d_ses-%02d_survey.mat', sess.participant, sess.sessionNum));

    case 'read'
        out = [];
        file = utils.consentRecord('file', sess);
        if ~isfile(file), return; end
        try
            loaded = load(file, 'info');
        catch err
            % An unreadable record is not consent. Say so and let the caller
            % put the participant through the survey again.
            warning('hw:consentRecord:unreadable', ...
                ['Could not read the consent record %s (%s). Treating this ' ...
                 'participant as not yet consented.'], file, err.message);
            return
        end
        if isfield(loaded, 'info'), out = loaded.info; end

    case 'write'
        info = varargin{1};
        file = utils.consentRecord('file', sess);
        if isfile(file)
            target = fullfile(sess.cfg.paths.sessions, ...
                sprintf('sub-%05d_ses-%02d_survey_%s.mat', ...
                    sess.participant, sess.sessionNum, utils.checkpointIO('id')));
            warning('hw:consentRecord:existing', ...
                ['A consent record already exists for participant %d session %d. ' ...
                 'The original is unchanged; this one was written to %s.'], ...
                sess.participant, sess.sessionNum, target);
            file = target;
        end
        try
            save(file, 'info');
        catch werr
            % The session itself is unaffected; a missing audit file must not
            % stop a consented participant, but it must not pass quietly.
            warning('hw:consentRecord:writeFailed', ...
                'Could not write the consent record to %s: %s', file, werr.message);
        end
        out = file;

    otherwise
        error('hw:consentRecord:action', 'Unknown consent record action %s.', action);
end
end
