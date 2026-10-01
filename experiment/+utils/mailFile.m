function mailFile(cfg, to, subject, body, attachments)
%UTILS.MAILFILE  Send one email with attachments, using the shared credential.
%
%   utils.mailFile(cfg, to, subject, body)
%   utils.mailFile(cfg, to, subject, body, attachments)
%
%   attachments is a char path or a cellstr of paths. THROWS on failure -- the
%   caller decides whether that is recoverable. utils.mailSession treats it as
%   recoverable (the zip stays queued); scripts/test_mail.m wants the error.
%
%   The credential is read fresh on every call from cfg.mail.credentialFile (or
%   HW_MAIL_CRED), never from the calling user's environment or MATLAB prefs,
%   because the rig is run by different people on different days. See
%   docs/mail-setup.md.
%
%   See also UTILS.MAILSESSION, UTILS.CONFIG.

if nargin < 5
    attachments = {};
end
if ischar(attachments) || isstring(attachments)
    attachments = cellstr(attachments);
end
for k = 1:numel(attachments)
    if ~exist(attachments{k}, 'file')
        error('hw:mailFile:noAttachment', ...
            'Attachment does not exist: %s', attachments{k});
    end
end

cred = loadCredential(cfg);

% setpref writes into the CURRENT USER's matlabprefs.mat, which on a shared lab
% machine would leave the app password on disk under whichever account happened
% to run the session. The onCleanup restores the previous pref state -- removing
% prefs that did not exist beforehand -- even if sendmail throws.
keys = {'E_mail', 'SMTP_Server', 'SMTP_Username', 'SMTP_Password'};
before = struct('key', keys, 'existed', num2cell(false(1, numel(keys))), 'value', '');
for k = 1:numel(keys)
    before(k).existed = ispref('Internet', keys{k});
    if before(k).existed
        before(k).value = getpref('Internet', keys{k});
    end
end
restore = onCleanup(@() restorePrefs(before)); %#ok<NASGU>

setpref('Internet', 'E_mail',        cred.from);
setpref('Internet', 'SMTP_Server',   cred.server);
setpref('Internet', 'SMTP_Username', cred.from);
setpref('Internet', 'SMTP_Password', cred.password);

% Implicit SSL on 465. Gmail has refused plain account passwords over SMTP
% since 2022, so this needs an app password -- and the socketFactory properties
% below, without which sendmail fails during the TLS handshake.
props = java.lang.System.getProperties;
props.setProperty('mail.smtp.auth', 'true');
props.setProperty('mail.smtp.starttls.enable', 'true');
props.setProperty('mail.smtp.socketFactory.port', num2str(cred.port));
props.setProperty('mail.smtp.socketFactory.class', 'javax.net.ssl.SSLSocketFactory');

if isempty(attachments)
    sendmail(to, subject, body);
else
    sendmail(to, subject, body, attachments);
end

end


% =====================================================================
function cred = loadCredential(cfg)
if ~isfield(cfg, 'mail') || ~isfield(cfg.mail, 'credentialFile')
    error('hw:mailFile:noConfig', 'cfg.mail.credentialFile is not set.');
end

candidates = {};
envPath = getenv('HW_MAIL_CRED');
if ~isempty(envPath)
    candidates{end+1} = envPath;
end
candidates{end+1} = char(cfg.mail.credentialFile);

credFile = '';
for k = 1:numel(candidates)
    if exist(candidates{k}, 'file')
        credFile = candidates{k};
        break
    end
end
if isempty(credFile)
    error('hw:mailFile:noCredential', ...
        ['No mail credential found. Looked for:\n    %s\n' ...
         'See docs/mail-setup.md -- it is a one-off, roughly five minutes.'], ...
        strjoin(candidates, sprintf('\n    ')));
end

raw = fileread(credFile);
try
    c = jsondecode(raw);
catch
    error('hw:mailFile:badCredential', ...
        '%s is not valid JSON. docs/mail-setup.md has the expected shape.', ...
        credFile);
end

for f = {'from', 'password'}
    if ~isfield(c, f{1}) || isempty(c.(f{1}))
        error('hw:mailFile:badCredential', ...
            'Credential %s is missing the "%s" field.', credFile, f{1});
    end
end
if contains(lower(char(c.password)), 'paste')
    error('hw:mailFile:badCredential', ...
        ['Credential %s still holds the placeholder password -- replace it ' ...
         'with the real Gmail app password.'], credFile);
end

cred = struct('from', char(c.from), 'password', char(c.password), ...
              'server', 'smtp.gmail.com', 'port', 465);
if isfield(c, 'server') && ~isempty(c.server), cred.server = char(c.server); end
if isfield(c, 'port')   && ~isempty(c.port),   cred.port   = double(c.port); end
end


function restorePrefs(before)
for k = 1:numel(before)
    if before(k).existed
        setpref('Internet', before(k).key, before(k).value);
    elseif ispref('Internet', before(k).key)
        rmpref('Internet', before(k).key);
    end
end
end
