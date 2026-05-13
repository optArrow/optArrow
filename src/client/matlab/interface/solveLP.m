function result = solveLP(LPproblem, varargin)
% solveLP Solve a linear program through OptArrow (general MATLAB interface).
%
% NOTE:
%    'optarrow.solveLP(...)' is MATLAB package namespace syntax from the
%    '+optarrow' folder, not object-oriented method dispatch.
%
% USAGE:
%
%    result = optarrow.solveLP(LPproblem)
%    result = optarrow.solveLP(LPproblem, opts)
%    import optarrow.*
%    result = solveLP(LPproblem)
%    result = solveLP(LPproblem, opts)
%
% INPUTS:
%    LPproblem:    struct with LP model data.
%                  Required fields:
%                    - A        double/sparse [m x n], constraint matrix
%                    - b        double [m x 1] or [1 x m], RHS vector
%                    - c        double [n x 1] or [1 x n], objective coeffs
%                  Optional fields:
%                    - lb       double [n x 1] or [1 x n], lower bounds
%                    - ub       double [n x 1] or [1 x n], upper bounds
%                    - csense   char/string/cellstr [m x 1], {'L','E','G'}
%                    - osense   numeric scalar or string ('min'/'max')
%
% OPTIONAL INPUTS:
%    opts:         struct with request options.
%                    - modelName  char/string, model label for backend
%                    - engine     char/string, backend engine override
%                    - solver     struct, backend solver specification
%                    - time_limit numeric scalar, backend time limit
%                    - endpoint   char/string, OptArrow API endpoint URL
%                    - timeoutSec numeric scalar, HTTP timeout in seconds
%
% OUTPUT:
%    result:       struct, decoded JSON response returned by OptArrow.
%
% EXAMPLE:
%    LP.A = sparse([1 1; 1 0; 0 1]);
%    LP.b = [1; 0.7; 0.8];
%    LP.c = [-1; -1];
%    LP.lb = [0; 0];
%    LP.csense = ['L'; 'L'; 'L'];
%    LP.osense = 1;   % 1=min, -1=max
%    out = optarrow.solveLP(LP, struct('timeoutSec', 60));

if nargin < 1 || ~isstruct(LPproblem)
    error('LPproblem must be provided as a struct.');
end

opts = struct();
if nargin >= 2 && isstruct(varargin{1})
    opts = varargin{1};
end

cfg = optarrow.getOptArrowConfig();

payload = struct();
payload.problem_type = 'LP';
payload.model = localBuildModelDict(LPproblem);
payload.model_name = 'optarrow_lp_model';
payload.engine = cfg.engine;
payload.solver_name = cfg.backendSolver;
payload.solver_params = cfg.backendOptions;

if isfield(opts, 'modelName') && ~isempty(opts.modelName)
    payload.model_name = opts.modelName;
end

if isfield(opts, 'engine') && ~isempty(opts.engine)
    payload.engine = opts.engine;
end

if isfield(opts, 'solver') && ~isempty(opts.solver)
    payload.solver = opts.solver;
    if isfield(opts.solver, 'solver_name')
        payload.solver_name = opts.solver.solver_name;
    end
    if isfield(opts.solver, 'solver_params')
        payload.solver_params = opts.solver.solver_params;
    end
end

if isfield(opts, 'time_limit')
    payload.time_limit = opts.time_limit;
end

computeOpts = struct();
if isfield(opts, 'endpoint')
    computeOpts.endpoint = opts.endpoint;
end
if isfield(opts, 'timeoutSec')
    computeOpts.timeoutSec = opts.timeoutSec;
end
if isfield(opts, 'transport')
    computeOpts.transport = opts.transport;
end

if isempty(fieldnames(computeOpts))
    response = optarrow.compute(payload);
else
    response = optarrow.compute(payload, computeOpts);
end

result = response;
end

function model = localBuildModelDict(LPproblem)
if ~isfield(LPproblem, 'A') || ~isfield(LPproblem, 'b') || ~isfield(LPproblem, 'c')
    error('LPproblem must include fields A, b, and c.');
end

A = LPproblem.A;
if ~issparse(A)
    A = sparse(A);
end

[rowIdx, colIdx, val] = find(A);

model = struct();
model.A = struct('row', rowIdx - 1, 'col', colIdx - 1, 'val', val);
model.b = LPproblem.b(:)';
model.c = LPproblem.c(:)';

if isfield(LPproblem, 'lb') && ~isempty(LPproblem.lb)
    model.lb = LPproblem.lb(:)';
else
    model.lb = zeros(1, size(A, 2));
end

if isfield(LPproblem, 'ub') && ~isempty(LPproblem.ub)
    model.ub = LPproblem.ub(:)';
end

model.csense = localNormalizeCsense(LPproblem, size(A, 1));
model.osense = localNormalizeOsense(LPproblem);
end

function csense = localNormalizeCsense(LPproblem, nRows)
if isfield(LPproblem, 'csense') && ~isempty(LPproblem.csense)
    raw = LPproblem.csense;
    if ischar(raw)
        csense = cellstr(raw(:));
    elseif isstring(raw)
        csense = cellstr(raw(:));
    elseif iscell(raw)
        csense = raw;
    else
        error('Unsupported csense format.');
    end
else
    csense = repmat({'E'}, nRows, 1);
end

csense = upper(string(csense));
csense = cellstr(csense);
end

function osense = localNormalizeOsense(LPproblem)
if ~isfield(LPproblem, 'osense') || isempty(LPproblem.osense)
    osense = 'min';
    return;
end

if isnumeric(LPproblem.osense)
    if LPproblem.osense == -1
        osense = 'max';
    else
        osense = 'min';
    end
else
    raw = lower(string(LPproblem.osense));
    if raw == "max"
        osense = 'max';
    else
        osense = 'min';
    end
end
end
