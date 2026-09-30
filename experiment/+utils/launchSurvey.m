function info = launchSurvey(sess)
%UTILS.LAUNCHSURVEY  Open the intake survey for this participant, then wait.
%
%   info = utils.launchSurvey(sess)
%
%   Called once from run_battery after the assignment is confirmed and BEFORE
%   any Psychtoolbox window exists. That ordering is deliberate: the browser
%   comes up over the desktop, not over a fullscreen PTB window it would have
%   to fight for focus with.
%
%   The participant number is passed on the query string so the survey response
%   can be joined to the run CSVs later. Qualtrics only keeps a query parameter
%   if a matching Embedded Data field is declared (and left blank) in Survey
%   Flow -- declaring pid/ses/domain/order there is what turns them into export
%   columns. Without that the values are silently dropped and every response
%   comes back unjoinable.
%
%   MATLAB cannot tell when the survey is submitted -- web() returns as soon as
%   the browser is handed the URL -- so the experimenter gates the battery at
%   the console.

info = struct('enabled', false, 'url', '', 'opened', false, 'skipped', false, ...
              'startedAt', char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));

cfg = sess.cfg;

if ~isfield(cfg, 'survey') || ~cfg.survey.enabled
    return
end
if cfg.testing.enabled
    fprintf('Survey skipped: testing mode.\n');
    return
end
if isempty(strtrim(cfg.survey.baseUrl))
    fprintf(2, ['\n*** Survey is enabled but cfg.survey.baseUrl is empty. ***\n' ...
                '    Paste the Qualtrics anonymous link into utils.config, or set\n' ...
                '    cfg.survey.enabled = false. Continuing without the survey.\n\n']);
    return
end

info.enabled = true;
info.url = buildUrl(cfg.survey.baseUrl, { ...
    'pid',     sprintf('%d', sess.participant), ...
    'ses',     sprintf('%d', sess.sessionNum), ...
    'domain',  sess.assignment.domain, ...
    'order',   sprintf('%d', sess.assignment.taskOrder), ...
    'runkind', sess.runKind, ...
    'version', sess.codeVersion});

fprintf('\n=== Intake survey ===\n');
fprintf('Participant: %d (%s)\n', sess.participant, sess.assignment.domain);
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

fprintf('\n');
while true
    answ = lower(strtrim(input( ...
        'Press Enter when the survey is submitted, s to skip, q to abort: ', 's')));
    if isempty(answ)
        return
    elseif strcmp(answ, 's')
        % Recorded rather than silent: a run with no survey response is a data
        % gap someone has to explain later, so make it visible now.
        info.skipped = true;
        fprintf(2, 'Survey SKIPPED for participant %d -- note this in the session log.\n', ...
            sess.participant);
        return
    elseif strcmp(answ, 'q')
        error('hw:launchSurvey:aborted', 'Aborted by experimenter at the survey step.');
    end
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
