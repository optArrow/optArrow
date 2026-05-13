function cfg = setOptArrowConfig(cfg)
% setOptArrowConfig Set global configuration for the OptArrow MATLAB adapter.
%
% NOTE:
%    'optarrow.setOptArrowConfig(...)' is MATLAB package namespace syntax
%    from the '+optarrow' folder, not object-oriented method dispatch.
%
% USAGE:
%
%    cfg = optarrow.setOptArrowConfig(cfg)
%    import optarrow.*
%    cfg = setOptArrowConfig(cfg)
%
% INPUTS:
%    cfg:          struct, adapter configuration.
%                  Supported fields:
%                    - name              char/string, adapter label
%                    - engine            char/string, backend engine name
%                    - backendSolver     char/string, solver name
%                    - backendSolverType char/string, problem class (e.g., 'LP')
%                    - backendOptions    struct, solver parameter dictionary
%                    - endpoint          char/string, OptArrow API URL
%                    - timeoutSec        numeric scalar, timeout in seconds
%                    - transport         char/string, 'auto' | 'arrow' | 'json'
%
% OUTPUT:
%    cfg:          struct, resolved configuration (input merged with defaults)
%                  and stored in global variable OPTARROW_CONFIG.
%
% EXAMPLE:
%    cfg = optarrow.setOptArrowConfig(struct( ...
%        'endpoint', 'http://127.0.0.1:8000/compute', ...
%        'backendSolver', 'HiGHS', ...
%        'timeoutSec', 120));

global OPTARROW_CONFIG

if nargin < 1 || ~isstruct(cfg)
    error('setOptArrowConfig expects a struct input.');
end

defaults = struct( ...
    'name', 'optarrow', ...
    'engine', 'python', ...
    'backendSolver', '', ...
    'backendSolverType', '', ...
    'backendOptions', struct(), ...
    'endpoint', 'http://127.0.0.1:8000/compute', ...
    'timeoutSec', 120, ...
    'transport', 'auto');

fields = fieldnames(defaults);
for i = 1:numel(fields)
    fieldName = fields{i};
    if ~isfield(cfg, fieldName) || isempty(cfg.(fieldName))
        cfg.(fieldName) = defaults.(fieldName);
    end
end

transport = lower(char(string(cfg.transport)));
if ~ismember(transport, {'auto', 'arrow', 'json'})
    error('transport must be one of: auto, arrow, json.');
end
cfg.transport = transport;

OPTARROW_CONFIG = cfg;
end
