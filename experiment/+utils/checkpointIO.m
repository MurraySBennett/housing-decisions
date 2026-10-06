function out = checkpointIO(action, varargin)
%UTILS.CHECKPOINTIO Verified local writes and streamed SHA-256 fingerprints.
switch lower(action)
    case 'write'
        file = varargin{1}; variables = varargin{2};
        replace = numel(varargin) > 2 && varargin{3};
        parent = fileparts(file);
        if ~isfolder(parent)
            [ok,msg] = mkdir(parent); assert(ok, 'hw:checkpointIO:mkdir', '%s', msg);
        end
        if isfile(file) && ~replace
            old = load(file);
            assert(isequaln(old, variables), 'hw:checkpointIO:exists', ...
                'Refusing to overwrite different checkpoint: %s', file);
            out = utils.checkpointIO('hash', file); return;
        end
        tmp = [file '.' char(java.util.UUID.randomUUID) '.partial.mat'];
        save(tmp, '-struct', 'variables', '-v7.3');
        check = load(tmp);
        assert(isequaln(check, variables), 'hw:checkpointIO:verify', ...
            'Checkpoint failed read-back validation: %s', tmp);
        if replace
            [ok,msg] = movefile(tmp, file, 'f');
        else
            assert(~isfile(file), 'hw:checkpointIO:exists', 'Checkpoint appeared during write.');
            [ok,msg] = movefile(tmp, file);
        end
        assert(ok, 'hw:checkpointIO:rename', '%s', msg);
        out = utils.checkpointIO('hash', file);
    case 'copy'
        source = varargin{1}; file = varargin{2};
        digest = utils.checkpointIO('hash', source);
        if isfile(file)
            assert(strcmp(digest, utils.checkpointIO('hash', file)), ...
                'hw:checkpointIO:conflict', 'Different content already exists at %s', file);
            out = digest; return;
        end
        parent = fileparts(file);
        if ~isfolder(parent)
            [ok,msg] = mkdir(parent); assert(ok, 'hw:checkpointIO:mkdir', '%s', msg);
        end
        tmp = [file '.' utils.checkpointIO('id') '.partial'];
        [ok,msg] = copyfile(source, tmp); assert(ok, 'hw:checkpointIO:copy', '%s', msg);
        assert(strcmp(digest, utils.checkpointIO('hash', tmp)) && ...
            strcmp(digest, utils.checkpointIO('hash', source)), ...
            'hw:checkpointIO:verify', 'Copy/source changed during transfer: %s', source);
        assert(~isfile(file), 'hw:checkpointIO:conflict', 'Destination appeared during transfer.');
        [ok,msg] = movefile(tmp, file); assert(ok, 'hw:checkpointIO:rename', '%s', msg);
        out = digest;
    case 'hash' 
        file = varargin{1};
        fid = fopen(file, 'rb'); assert(fid >= 0, 'hw:checkpointIO:open', 'Cannot read %s', file);
        closer = onCleanup(@() fclose(fid)); %#ok<NASGU>
        md = java.security.MessageDigest.getInstance('SHA-256');
        while ~feof(fid)
            chunk = fread(fid, 1048576, '*uint8');
            md.update(typecast(chunk, 'int8'));
        end
        [msg,err] = ferror(fid); assert(err == 0, 'hw:checkpointIO:read', '%s', msg);
        out = lower(reshape(dec2hex(typecast(md.digest(), 'uint8'), 2).', 1, []));
    case 'id'
        out = char(java.util.UUID.randomUUID);
    otherwise
        error('hw:checkpointIO:action', 'Unknown checkpoint IO action %s.', action);
end
end
