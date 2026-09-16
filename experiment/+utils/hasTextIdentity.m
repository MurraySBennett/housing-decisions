function tf = hasTextIdentity(sel)
%UTILS.HASTEXTIDENTITY  Does this selection have a non-image identity header?
%
%   Houses' identity is six photos and nothing else, so their cards carry no
%   text header; jobs' is industry/title, which does. Whether the header is
%   there decides where the attribute grid starts, so this has to give the
%   same answer to the code that DRAWS the card and the code that records
%   its AOIs -- which is why it lives here rather than in either of them.

tf = false;
for k = 1:numel(sel.identity)
    tf = tf || ~strcmp(sel.identity(k).kind, 'image');
end
end
