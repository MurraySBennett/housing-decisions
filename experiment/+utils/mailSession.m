function info = mailSession(sess)
%UTILS.MAILSESSION  Zip this session's CSVs and mail them off the rig.
%
%   info = utils.mailSession(sess)
%
%   Collects every CSV belonging to this participant and session -- the task
%   run files and the session timing file, matched on the sub-%05d_ses-%02d_
%   prefix that utils.beginRun stamps on everything -- zips them, and mails the
%   zip to cfg.mail.to. Gaze buffers and .mat files are deliberately excluded:
%   the attachment is kilobytes, so no size limit is in play.
%
%   Delivery is eventually consistent, not best-effort. The zip is written to
%   cfg.mail.outbox FIRST and only moved to outbox/sent/ once sendmail returns,
%   so a blocked SMTP port, a dropped network or an RA who closes MATLAB loses
%   nothing -- the zip is still sitting there and scripts/flush_outbox.m sweeps
%   it later from any machine that can reach the share.
%
%   NEVER THROWS. By the time this runs the session is over and the data is
%   already saved; a mail problem is a warning on the console, not a failed
%   session. Nothing an RA sees here should look like lost data.
%
%   See also UTILS.CONFIG, FLUSH_OUTBOX.

info = struct('enabled', false, 'skipped', '', 'zipFile', '', ...
              'nFiles', 0, 'sent', false, 'error', '');

cfg = sess.cfg;
if ~isfield(cfg, 'mail') || ~cfg.mail.enabled
    info.skipped = 'cfg.mail.enabled is false';
    return
end
info.enabled = true;

% Real participant data only. A testing run is participant 9999 and a practice
% run is rehearsal; neither is worth mailing anywhere.
if sess.testing
    info.skipped = 'testing run';
elseif ~strcmp(sess.runKind, 'participant')
    info.skipped = sprintf('%s run', sess.runKind);
end
if ~isempty(info.skipped)
    fprintf('Mail: skipped (%s).\n', info.skipped);
    return
end

try
    files = collectCsvs(sess);
    if isempty(files)
        info.skipped = 'no CSVs found for this session';
        warning('hw:mailSession:noFiles', ...
            ['No CSVs found for participant %d session %d, so nothing was ' ...
             'mailed. The data may be under the fallback tree only -- check ' ...
             'the console above for save warnings.'], ...
            sess.participant, sess.sessionNum);
        return
    end
    info.nFiles = numel(files);

    info.zipFile = writeZip(sess, files);
    fprintf('Mail: %d CSV(s) zipped to\n    %s\n', info.nFiles, info.zipFile);
catch ME
    % Could not even stage the zip. Nothing to recover later, so say so
    % plainly rather than leaving the RA thinking a copy is in flight.
    info.error = ME.message;
    warning('hw:mailSession:zipFailed', ...
        ['Could not zip this session''s CSVs: %s\n' ...
         'The session data itself is unaffected and still on disk. Nothing ' ...
         'was mailed and nothing is queued.'], ME.message);
    return
end

% --- Send, and record the outcome in the outbox ------------------------
try
    subject = sprintf('[housing-decisions] sub-%05d ses-%02d -- %d CSV(s)', ...
        sess.participant, sess.sessionNum, info.nFiles);
    utils.mailFile(cfg, cfg.mail.to, subject, bodyText(sess, files), info.zipFile);

    info.sent = true;
    info.zipFile = markSent(info.zipFile);
    fprintf('Mail: sent to %s.\n', cfg.mail.to);
catch ME
    info.error = ME.message;
    % The zip stays in the outbox on purpose. This is the recoverable case.
    fprintf(2, ['\nMail: could not send (%s).\n' ...
                '    This is NOT data loss. The zip is queued at\n' ...
                '        %s\n' ...
                '    and will go out when scripts/flush_outbox.m is next run.\n' ...
                '    Nothing for you to do -- carry on with the participant.\n\n'], ...
        ME.message, info.zipFile);
end

end


% =====================================================================
function files = collectCsvs(sess)
%COLLECTCSVS  Every CSV stamped with this participant/session prefix.
prefix = sprintf('sub-%05d_ses-%02d_', sess.participant, sess.sessionNum);
p = sess.cfg.paths;

dirsToScan = {p.sessions, p.taskData.auction, p.taskData.contdc, p.taskData.pref};

% The fallback tree is scanned too. If the share went unreachable mid-session
% then utils.saveRun wrote locally instead, and those are precisely the runs
% whose only copy is on this machine -- the ones most worth mailing out.
if isfield(p, 'fallbackData')
    fb = p.fallbackData;
    dirsToScan = [dirsToScan, {fullfile(fb, 'sessions'), ...
        fullfile(fb, 'auction'), fullfile(fb, 'cont_dc'), fullfile(fb, 'pref')}];
end

files = {};
seen = {};
for k = 1:numel(dirsToScan)
    d = dirsToScan{k};
    if isempty(d) || ~exist(d, 'dir')
        continue
    end
    hits = dir(fullfile(d, [prefix '*.csv']));
    for j = 1:numel(hits)
        if hits(j).isdir
            continue
        end
        % A primary and a fallback copy of the same run would collide in the
        % zip; keep the first seen (primary is scanned first).
        if any(strcmp(hits(j).name, seen))
            continue
        end
        seen{end+1}  = hits(j).name;      %#ok<AGROW>
        files{end+1} = fullfile(d, hits(j).name); %#ok<AGROW>
    end
end
end


function zipFile = writeZip(sess, files)
%WRITEZIP  Stage the attachment in the outbox before any network is touched.
outbox = sess.cfg.mail.outbox;
if ~exist(outbox, 'dir')
    mkdir(outbox);
end
stamp = char(datetime('now', 'Format', 'yyyy-MM-dd_HHmmss'));
zipFile = fullfile(outbox, sprintf('sub-%05d_ses-%02d_csv_%s.zip', ...
    sess.participant, sess.sessionNum, stamp));

% The files are collected from the share AND possibly the local fallback tree,
% so they have no common root folder. zip() derives archive entry names from the
% root, which for a UNC share path plus a C:\ path produces either an error or
% absurd nested entries. Copy them flat into a staging folder first and zip that
% with an explicit root, so the archive holds bare filenames.
staging = fullfile(tempdir, sprintf('hw_mail_%05d_%02d_%s', ...
    sess.participant, sess.sessionNum, stamp));
mkdir(staging);
cleanup = onCleanup(@() rmdirQuiet(staging)); %#ok<NASGU>

for k = 1:numel(files)
    [~, n, e] = fileparts(files{k});
    copyfile(files{k}, fullfile(staging, [n e]));
end

zip(zipFile, '*.csv', staging);
end


function rmdirQuiet(d)
try
    if exist(d, 'dir')
        rmdir(d, 's');
    end
catch
    % A leftover temp folder is harmless; never let it break the session.
end
end


function newPath = markSent(zipFile)
%MARKSENT  Move a delivered zip out of the queue so it is not sent twice.
[outbox, name, ext] = fileparts(zipFile);
sentDir = fullfile(outbox, 'sent');
newPath = zipFile;
try
    if ~exist(sentDir, 'dir')
        mkdir(sentDir);
    end
    dest = fullfile(sentDir, [name ext]);
    movefile(zipFile, dest);
    newPath = dest;
catch werr
    % Delivered but still in the queue: flush_outbox would send a duplicate.
    % A duplicate email is harmless; silence here would not be.
    warning('hw:mailSession:notFiled', ...
        ['Mailed successfully but could not move the zip to %s: %s\n' ...
         'It may be sent a second time by flush_outbox. Harmless, but ' ...
         'delete it by hand if you want to avoid the duplicate.'], ...
        sentDir, werr.message);
end
end


function body = bodyText(sess, files)
names = cell(1, numel(files));
for k = 1:numel(files)
    [~, n, e] = fileparts(files{k});
    names{k} = ['  ' n e];
end
% taskOrder is the permutation INDEX (1-6) that utils.batteryPlan resolves into
% a task sequence, not a sequence itself -- and it is [] when the run used the
% participant's default parity. Formatted the same way utils.launchSurvey does.
orderStr = sprintf('%d', sess.assignment.taskOrder);
if isempty(orderStr)
    orderStr = '(default for this participant)';
end

body = sprintf([ ...
    'Participant %d, session %d finished at %s.\n\n' ...
    'Task order index: %s\n' ...
    'Domain order:     %s\n' ...
    'Code version:     %s\n\n' ...
    'Attached CSVs (%d):\n%s\n\n' ...
    'The share remains the system of record; this is a convenience copy.\n' ...
    'Sent automatically by utils.mailSession.\n'], ...
    sess.participant, sess.sessionNum, ...
    char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
    orderStr, sess.domainOrderStr, sess.codeVersion, ...
    numel(files), strjoin(names, newline));
end

