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
%                    - transport         char/string, must be 'arrow'
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
    'transport', 'arrow');

fields = fieldnames(defaults);
for i = 1:numel(fields)
    fieldName = fields{i};
    if ~isfield(cfg, fieldName) || isempty(cfg.(fieldName))
        cfg.(fieldName) = defaults.(fieldName);
    end
end

if ~strcmpi(cfg.transport, 'arrow')
    error('Only Arrow transport is supported in this interface.');
end

OPTARROW_CONFIG = cfg;
end
