function validateBlockContext(c)
%VALIDATEBLOCKCONTEXT The identity fields every block attempt must carry.
assert(c.schemaVersion == 1 && isscalar(c.blockOrdinal) && ...
    c.blockOrdinal >= 1 && c.blockOrdinal == fix(c.blockOrdinal), ...
    'hw:blockStore:context', 'Invalid checkpoint schema or block ordinal.');
for name = {'participant','session','task','domain','runKind','logicalRunId','parentAttemptId'}
    assert(isfield(c, name{1}), 'hw:blockStore:context', 'Missing %s', name{1});
end
end
