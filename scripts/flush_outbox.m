function flush_outbox(varargin)
%FLUSH_OUTBOX  Send any session zips that utils.mailSession could not deliver.
%
%   flush_outbox()                 % the participant outbox
%   flush_outbox('practice', true) % the practice tree instead
%   flush_outbox('dryRun', true)   % list what would be sent, send nothing
%
%   utils.mailSession stages every zip in the outbox BEFORE touching the
%   network, and only moves it to outbox/sent/ once delivery succeeds. So
%   whatever is still sitting in the outbox is precisely what never went out --
%   a blocked port, a dead network, a closed MATLAB. This sends it.
%
%   Safe to run repeatedly and from any machine that can reach the share; it is
%   the mechanism that makes a mail failure at the rig a non-event. Nothing is
%   ever deleted, only moved into sent/.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'experiment'));

p = inputParser;
p.addParameter('practice', false, @islogical);
p.addParameter('dryRun',   false, @islogical);
p.addParameter('to',       '', @(x) ischar(x) || isstring(x));
p.parse(varargin{:});

runKind = 'participant';
if p.Results.practice
    runKind = 'practice';
end
cfg = utils.config('runKind', runKind);
to = char(p.Results.to);
if isempty(to)
    to = cfg.mail.to;
end

outbox = cfg.mail.outbox;
fprintf('\n=== flush outbox ===\n  outbox: %s\n  to:     %s\n\n', outbox, to);
if ~exist(outbox, 'dir')
    fprintf('Outbox does not exist. Nothing queued -- nothing to do.\n\n');
    return
end

queued = dir(fullfile(outbox, '*.zip'));
queued = queued(~[queued.isdir]);
if isempty(queued)
    fprintf('Outbox is empty. Every session zip was delivered at the rig.\n\n');
    return
end

fprintf('%d zip(s) queued:\n', numel(queued));
for k = 1:numel(queued)
    fprintf('  %s  (%.1f kB, %s)\n', queued(k).name, queued(k).bytes / 1024, ...
        datestr(queued(k).datenum, 'yyyy-mm-dd HH:MM'));
end
fprintf('\n');

if p.Results.dryRun
    fprintf('dryRun: nothing sent.\n\n');
    return
end

sentDir = fullfile(outbox, 'sent');
if ~exist(sentDir, 'dir')
    mkdir(sentDir);
end

nSent = 0;
nFailed = 0;
for k = 1:numel(queued)
    zipFile = fullfile(outbox, queued(k).name);
    [~, stem] = fileparts(queued(k).name);
    subject = sprintf('[housing-decisions] queued: %s', stem);
    body = sprintf([ ...
        'Queued session zip, delivered late by scripts/flush_outbox.\n\n' ...
        'File:   %s\n' ...
        'Zipped: %s\n\n' ...
        'It did not send at the rig -- most likely the lab network blocks\n' ...
        'outbound SMTP, or the machine was offline at the time.\n'], ...
        queued(k).name, datestr(queued(k).datenum, 'yyyy-mm-dd HH:MM'));

    fprintf('  sending %s ... ', queued(k).name);
    try
        utils.mailFile(cfg, to, subject, body, zipFile);
        movefile(zipFile, fullfile(sentDir, queued(k).name));
        nSent = nSent + 1;
        fprintf('ok\n');
    catch ME
        nFailed = nFailed + 1;
        fprintf(2, 'FAILED (%s)\n', ME.message);
    end
end

fprintf('\n%d sent, %d still queued.\n', nSent, nFailed);
if nFailed > 0
    fprintf(2, ['Still-queued zips were left in place; nothing was lost. If ' ...
                'every one failed,\nrun scripts/test_mail.m from this machine ' ...
                'to see whether it is the credential\nor the network.\n']);
end
fprintf('\n');

end
