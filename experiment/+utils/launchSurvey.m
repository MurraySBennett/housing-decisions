function info = launchSurvey(sess)
%UTILS.LAUNCHSURVEY  Open the consent survey in the browser, before the battery.
%
%   info = utils.launchSurvey(sess)
%
%   Called once from run_battery BEFORE any task runs. The participant reads
%   the approved IRB document and checks the consent box inside this survey,
%   so it has to precede participation and it has to be able to stop the
%   session. It is the only thing standing between "an RA clicked Run" and
%   data being collected from someone who did not consent.
%
%   One Qualtrics response, two sittings, one browser tab that stays open the
%   whole session. The survey itself ends its consent block on a page telling
%   the participant to minimise the window and ask the RA to set up the next
%   step; the battery then runs (each task opens and closes its own PTB
%   window), and afterwards the RA brings the same tab back up so the
%   participant finishes the remaining questions.
%
%   The tab must not be CLOSED. An anonymous link reopened in a fresh tab
%   starts a NEW response, which strands the consent record and the intake
%   answers in two rows with nothing linking them.
%
%   Numeric money questions still do not belong in either sitting:
%   utils.elicitAnchor measures budget/reservation wage inside the battery, and
%   a money question in front of it primes the anchor under the primary DV.
%
%   The participant number is typed into the survey by the participant, not
%   passed on the query string -- see cfg.survey.passParams in utils.config for
%   the automatic alternative and what it needs in Survey Flow first.
%
%   MATLAB cannot see into Qualtrics -- web() returns as soon as the browser
%   has the URL -- so the RA confirming at the console IS the gate. That is
%   why the prompt names consent explicitly rather than asking whether the
%   survey is "done", and why the answer is written to disk.

info = runSurvey(sess);
recordSurvey(info, sess);

end


function info = runSurvey(sess)
info = struct('enabled', false, 'url', '', 'opened', false, 'consented', false, ...
              'startedAt', char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));

cfg = sess.cfg;

if cfg.testing.enabled
    % Participant 9999 is not a person. Nothing to consent.
    fprintf('Survey skipped: testing mode.\n');
    return
end

if ~isfield(cfg, 'survey') || ~cfg.survey.enabled
    % Not blocked: the flag exists so the battery can be rehearsed without
    % Qualtrics. But a real participant run with the survey off means no
    % consent record will exist for them, and that must not pass quietly.
    if strcmpi(sess.runKind, 'participant')
        fprintf(2, ['\n*** cfg.survey.enabled is FALSE on a participant run. ***\n' ...
                    '    No consent record will exist for participant %d.\n' ...
                    '    Consent must have been obtained some other way.\n\n'], ...
                sess.participant);
    end
    return
end

if isempty(strtrim(cfg.survey.baseUrl))
    % Misconfiguration, not a choice. Carrying on would run the battery with
    % the consent step silently absent, which is the failure this whole
    % function exists to prevent.
    error('hw:launchSurvey:noUrl', ...
        ['cfg.survey.enabled is true but cfg.survey.baseUrl is empty, so the ' ...
         'consent survey cannot be shown. Paste the Qualtrics anonymous link ' ...
         'into utils.config, or set cfg.survey.enabled = false if consent is ' ...
         'being collected another way.']);
end

info.enabled = true;

% Off by default: the live survey asks the participant to type their number,
% and query parameters vanish silently unless Survey Flow declares them.
if isfield(cfg.survey, 'passParams') && cfg.survey.passParams
    info.url = buildUrl(cfg.survey.baseUrl, { ...
        'pid',     sprintf('%d', sess.participant), ...
        'ses',     sprintf('%d', sess.sessionNum), ...
        'domain',  sess.assignment.domain, ...
        'order',   sprintf('%d', sess.assignment.taskOrder), ...
        'runkind', sess.runKind, ...
        'version', sess.codeVersion});
else
    info.url = strtrim(char(cfg.survey.baseUrl));
end

% The participant number is printed large because the participant has to type
% it into the survey from what is on this screen, and a transcription error
% here is a response that cannot be matched to any run.
fprintf('\n=== Consent and intake survey ===\n');
fprintf('PARTICIPANT NUMBER TO TYPE INTO THE SURVEY:  %d\n', sess.participant);
fprintf('Session %d, domain %s\n', sess.sessionNum, sess.assignment.domain);
fprintf('%s\n', info.url);

try
    web(info.url, '-browser');
    info.opened = true;
catch ME
    % Not fatal. The URL is already on screen and can be pasted by hand; losing
    % the session over a browser that would not launch is the worse outcome.
    fprintf(2, ['Could not open a browser automatically (%s).\n' ...
                'Copy the link above into the browser by hand.\n'], ME.message);
end

% Consent gate. There is deliberately no skip: the consent box is inside this
% survey, so "carry on without it" is not a thing an RA should be able to do
% with one keystroke at the end of a long day. y proceeds, anything else stops
% the session before a single trial is collected. The default is to stop --
% an RA who taps Enter without reading gets the safe outcome, not the
% convenient one.
%
% The question is about the CONSENT BLOCK, not the whole survey: the rest of it
% is answered after the battery, in the same tab.
fprintf('\n');
fprintf('Leave the browser tab OPEN -- minimised, not closed. The participant\n');
fprintf('returns to it after the battery to finish the survey.\n');
answ = lower(strtrim(input( ...
    'Consent box checked, and the survey minimised at its handover page? (y/n): ', 's')));

if ~strcmp(answ, 'y')
    % startSession has already written the manifest by this point, so without
    % this the declined number would be counted as used and an empty manifest
    % would sit in the session tree describing someone who did not consent.
    released = releaseParticipantNumber(sess);
    if released
        tail = sprintf(['The empty manifest for %d has been removed, so that ' ...
                        'number will be offered again.'], sess.participant);
    else
        tail = sprintf(['Participant %d already has completed runs, so their ' ...
                        'manifest was left alone.'], sess.participant);
    end
    error('hw:launchSurvey:noConsent', ...
        ['Consent not confirmed for participant %d. Session stopped before any ' ...
         'task ran. %s'], sess.participant, tail);
end

info.consented = true;

end


function released = releaseParticipantNumber(sess)
%RELEASEPARTICIPANTNUMBER  Remove the not-yet-used manifest after a refusal.
%   Deletes ONLY a manifest with zero runs on it. A participant partway
%   through who declines to continue keeps everything they already did -- this
%   never touches a manifest that has runs, and never touches task data.
released = false;
if ~isfield(sess, 'manifest') || ~isfield(sess.manifest, 'runs') ...
        || ~isempty(sess.manifest.runs)
    return
end
if ~exist(sess.manifestFile, 'file')
    return
end
try
    delete(sess.manifestFile);
    released = true;
catch werr
    warning('hw:launchSurvey:manifestNotRemoved', ...
        ['Could not remove the empty manifest %s: %s\n' ...
         'Participant %d will be treated as used. Delete it by hand to ' ...
         'free the number.'], sess.manifestFile, werr.message, sess.participant);
end
end


function recordSurvey(info, sess)
%RECORDSURVEY  Persist the consent confirmation beside the session files.
%   Only reached when consent was given -- a refusal throws, so nothing is
%   written about someone who declined, and their participant number is left
%   unused for the next person.
if ~info.enabled
    return
end
info.finishedAt = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
f = fullfile(sess.cfg.paths.sessions, ...
    sprintf('sub-%05d_ses-%02d_survey.mat', sess.participant, sess.sessionNum));
try
    save(f, 'info');
catch werr
    % The session is already complete and saved; a missing audit file is not
    % worth an error here, but it should not pass quietly either.
    warning('hw:launchSurvey:recordFailed', ...
        'Could not write the survey record to %s: %s', f, werr.message);
end
end


function url = buildUrl(baseUrl, kv)
base = strtrim(char(baseUrl));
parts = cell(1, numel(kv)/2);
for k = 1:2:numel(kv)
    parts{(k+1)/2} = sprintf('%s=%s', kv{k}, urlEncode(kv{k+1}));
end
query = strjoin(parts, '&');

% An anonymous link may already carry a parameter (?Q_Language=EN, a preview
% token); append to it rather than replacing it.
if contains(base, '?')
    url = [base '&' query];
else
    url = [base '?' query];
end
end


function out = urlEncode(s)
s = char(s);
out = '';
for k = 1:numel(s)
    c = s(k);
    if isstrprop(c, 'alphanum') || any(c == '-_.~')
        out(end+1) = c; %#ok<AGROW>
    else
        out = [out sprintf('%%%02X', double(c))]; %#ok<AGROW>
    end
end
end
