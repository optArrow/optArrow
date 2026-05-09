function result = solveQP(QPproblem, varargin)
% solveQP Solve a quadratic program through OptArrow (general MATLAB interface).
%
% NOTE:
%    'optarrow.solveQP(...)' is MATLAB package namespace syntax from the
%    '+optarrow' folder, not object-oriented method dispatch.
%
% USAGE:
%
%    result = optarrow.solveQP(QPproblem)
%    result = optarrow.solveQP(QPproblem, opts)
%    import optarrow.*
%    result = solveQP(QPproblem)
%    result = solveQP(QPproblem, opts)
%
% INPUTS:
%    QPproblem:    struct with QP model data.
%                  Required fields:
%                    - F        double/sparse [n x n], quadratic cost matrix
%                               (objective: 0.5 * x' * F * x + c' * x)
%                    - c        double [n x 1] or [1 x n], linear cost coefficients
%                  Optional fields:
%                    - A        double/sparse [m x n], constraint matrix
%                    - b        double [m x 1] or [1 x m], RHS vector
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
%    QP.F = sparse([2 0; 0 2]);
%    QP.c = [-2; -5];
%    QP.A = sparse([1 1]);
%    QP.b = 3;
%    QP.lb = [0; 0];
%    QP.csense = 'E';
%    QP.osense = 1;   % 1=min, -1=max
%    out = optarrow.solveQP(QP);

if nargin < 1 || ~isstruct(QPproblem)
    error('QPproblem must be provided as a struct.');
end

opts = struct();
if nargin >= 2 && isstruct(varargin{1})
    opts = varargin{1};
end

payload = struct();
payload.model       = localBuildModelDict(QPproblem);
payload.model_name  = 'optarrow_qp_model';

if isfield(opts, 'modelName') && ~isempty(opts.modelName)
    payload.model_name = opts.modelName;
end
if isfield(opts, 'engine') && ~isempty(opts.engine)
    payload.engine = opts.engine;
end
if isfield(opts, 'solver') && ~isempty(opts.solver)
    payload.solver = opts.solver;
end
if isfield(opts, 'time_limit')
    payload.time_limit = opts.time_limit;
end

computeOpts = struct();
if isfield(opts, 'endpoint'),   computeOpts.endpoint   = opts.endpoint;   end
if isfield(opts, 'timeoutSec'), computeOpts.timeoutSec = opts.timeoutSec; end

if isempty(fieldnames(computeOpts))
    result = optarrow.compute(payload);
else
    result = optarrow.compute(payload, computeOpts);
end
end


function model = localBuildModelDict(QPproblem)
if ~isfield(QPproblem, 'F') || isempty(QPproblem.F)
    error('QPproblem must include field F (quadratic cost matrix).');
end
if ~isfield(QPproblem, 'c')
    error('QPproblem must include field c.');
end

F = QPproblem.F;
if ~issparse(F), F = sparse(F); end
[r, c, v] = find(F);
model.Q = struct('row', r - 1, 'col', c - 1, 'val', v);
model.c = QPproblem.c(:)';

if isfield(QPproblem, 'lb') && ~isempty(QPproblem.lb)
    model.lb = QPproblem.lb(:)';
else
    model.lb = zeros(1, size(F, 2));
end
if isfield(QPproblem, 'ub') && ~isempty(QPproblem.ub)
    model.ub = QPproblem.ub(:)';
end

model.osense = localNormalizeOsense(QPproblem);

if isfield(QPproblem, 'A') && ~isempty(QPproblem.A)
    A = QPproblem.A;
    if ~issparse(A), A = sparse(A); end
    [ra, ca, va] = find(A);
    model.A = struct('row', ra - 1, 'col', ca - 1, 'val', va);
    model.b = QPproblem.b(:)';
    model.csense = localNormalizeCsense(QPproblem, size(A, 1));
end
end

function csense = localNormalizeCsense(QPproblem, nRows)
if isfield(QPproblem, 'csense') && ~isempty(QPproblem.csense)
    raw = QPproblem.csense;
    if ischar(raw),   csense = cellstr(raw(:));
    elseif isstring(raw), csense = cellstr(raw(:));
    elseif iscell(raw),   csense = raw;
    else, error('Unsupported csense format.');
    end
else
    csense = repmat({'E'}, nRows, 1);
end
csense = cellstr(upper(string(csense)));
end

function osense = localNormalizeOsense(QPproblem)
if ~isfield(QPproblem, 'osense') || isempty(QPproblem.osense)
    osense = 'min';
    return;
end
if isnumeric(QPproblem.osense)
    osense = 'max';
    if QPproblem.osense ~= -1, osense = 'min'; end
else
    osense = 'min';
    if strcmpi(string(QPproblem.osense), 'max'), osense = 'max'; end
end
end
