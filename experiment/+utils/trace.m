function trace(fmt, varargin)
%UTILS.TRACE  One-line progress logging, toggleable globally.
%
%   utils.trace('opening window on screen %d', screenNumber)
%
%   Prints a timestamped line to the console if utils.trace('on') has been
%   called this session (default off). Meant for exactly the debugging
%   problem we keep hitting: "which line were we actually on when it went
%   white" -- cheap enough to leave scattered through the display-setup and
%   task-loop code, silent by default so it doesn't clutter real sessions.
%
%   utils.trace('on')   -- enable
%   utils.trace('off')  -- disable (default)

persistent enabled
if isempty(enabled), enabled = false; end

if nargin == 1 && strcmpi(fmt, 'on'),  enabled = true;  return; end
if nargin == 1 && strcmpi(fmt, 'off'), enabled = false; return; end
if ~enabled, return; end

fprintf('[trace %s] %s\n', datestr(now, 'HH:MM:SS.FFF'), sprintf(fmt, varargin{:}));

end
