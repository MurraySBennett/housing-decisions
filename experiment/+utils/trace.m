function trace(fmt, varargin)
%UTILS.TRACE  One-line progress logging, toggleable globally.
%
%   utils.trace('opening window on screen %d', screenNumber)
%   utils.trace('on') / utils.trace('off'); off by default.

persistent enabled
if isempty(enabled), enabled = false; end

if nargin == 1 && strcmpi(fmt, 'on'),  enabled = true;  return; end
if nargin == 1 && strcmpi(fmt, 'off'), enabled = false; return; end
if ~enabled, return; end

fprintf('[trace %s] %s\n', datestr(now, 'HH:MM:SS.FFF'), sprintf(fmt, varargin{:}));

end
