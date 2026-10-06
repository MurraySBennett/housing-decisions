function chunks = preferenceChunks(sections, nRating, nPwc)
%UTILS.PREFERENCECHUNKS Consecutive storage boundaries; never reshuffle trials.
chunks = struct('section', {}, 'indices', {}, 'globalIndices', {});
offset = 0;
for k = 1:numel(sections)
    section = sections{k};
    if strcmp(section, 'rating'), n = nRating; else, n = nPwc; end
    for first = 1:40:n
        indices = first:min(first+39, n);
        chunks(end+1) = struct('section', section, 'indices', indices, ...
            'globalIndices', offset + indices); %#ok<AGROW>
    end
    offset = offset + n;
end
end
