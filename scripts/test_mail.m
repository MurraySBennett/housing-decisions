function test_mail(varargin)
%TEST_MAIL  Prove the rig can actually send mail, before a session depends on it.
%
%   test_mail()              % send to cfg.mail.to
%   test_mail('to', 'someone@example.com')
%
%   Run this ONCE at the rig after creating the credential (docs/mail-setup.md),
%   and again on any new machine. It builds a two-line CSV, zips it, and mails
%   it -- the same code path utils.mailSession uses, so a pass here means a real
%   session will deliver.
%
%   This is the check that cannot be done anywhere but the rig: institutional
%   networks often block outbound SMTP on 465/587, and that fact is invisible
%   from a laptop on a different network. Thirty seconds here beats discovering
%   it with a participant in the chair.
%
%   Errors loudly on failure, and the message says which failure it is.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'experiment'));

p = inputParser;
p.addParameter('to', '', @(x) ischar(x) || isstring(x));
p.parse(varargin{:});

cfg = utils.config();
to = char(p.Results.to);
if isempty(to)
    to = cfg.mail.to;
end

fprintf('\n=== mail smoke test ===\n');
fprintf('  to:         %s\n', to);
fprintf('  credential: %s\n', cfg.mail.credentialFile);
if ~isempty(getenv('HW_MAIL_CRED'))
    fprintf('  HW_MAIL_CRED override: %s\n', getenv('HW_MAIL_CRED'));
end

tmpDir = fullfile(tempdir, 'housing_decisions_mailtest');
if ~exist(tmpDir, 'dir')
    mkdir(tmpDir);
end
cleanup = onCleanup(@() rmdirQuiet(tmpDir)); %#ok<NASGU>

csvFile = fullfile(tmpDir, 'mail_test.csv');
writetable(table((1:2)', ["a"; "b"], 'VariableNames', {'row', 'label'}), csvFile);
zipFile = fullfile(tmpDir, 'mail_test.zip');
zip(zipFile, {csvFile});
fprintf('  attachment: %s (%d bytes)\n\n', zipFile, dir(zipFile).bytes);

host = char(java.net.InetAddress.getLocalHost().getHostName());
body = sprintf([ ...
    'Mail smoke test from the housing-decisions rig.\n\n' ...
    'Machine: %s\n' ...
    'User:    %s\n' ...
    'Sent:    %s\n\n' ...
    'If this arrived with a zip attached, utils.mailSession will work for a\n' ...
    'real session from this machine and this login.\n'], ...
    host, getUser(), char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));

fprintf('Sending...\n');
try
    utils.mailFile(cfg, to, '[housing-decisions] mail smoke test', body, zipFile);
catch ME
    fprintf(2, '\n*** FAILED: %s\n\n', ME.message);
    switch true
        case contains(lower(ME.message), 'credential') || ...
             strcmp(ME.identifier, 'hw:mailFile:noCredential')
            fprintf(2, ['This is a setup problem, not a network problem.\n' ...
                        'Follow docs/mail-setup.md and run this again.\n\n']);
        case contains(lower(ME.message), 'authentic') || ...
             contains(lower(ME.message), 'username and password')
            fprintf(2, ['The credential was found but Gmail rejected it.\n' ...
                        'Almost always: the account password was pasted in ' ...
                        'instead of an APP password.\nSee docs/mail-setup.md.\n\n']);
        otherwise
            fprintf(2, ['Most likely this network blocks outbound SMTP.\n' ...
                        'That is a real possibility on OSU wired networks and ' ...
                        'it is not fixable from MATLAB.\nIf so, say the word ' ...
                        'and the outbox can be flushed from elsewhere instead ' ...
                        '--\nsessions keep queuing zips either way, so no data ' ...
                        'is at risk.\n\n']);
    end
    rethrow(ME);
end

fprintf('\n*** PASS: sent to %s. Check that inbox.\n\n', to);

end


function u = getUser()
u = getenv('USERNAME');
if isempty(u), u = getenv('USER'); end
if isempty(u), u = '(unknown)'; end
end


function rmdirQuiet(d)
try
    rmdir(d, 's');
catch
end
end
