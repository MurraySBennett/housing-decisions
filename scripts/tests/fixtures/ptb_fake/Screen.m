function out = Screen(action,varargin) %#ok<INUSD>
if strcmp(action,'Rect'), out = [0 0 1920 1080];
elseif strcmp(action,'Flip'), out = GetSecs;
else, out = []; end
end
