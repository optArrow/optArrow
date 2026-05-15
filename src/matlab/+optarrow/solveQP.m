function result = solveQP(QPproblem, opts)
% solveQP  Solve a COBRA-style QP problem via the OptArrow Gateway.
%
% NOTE:
%    'optarrow.solveQP(...)' is MATLAB package namespace syntax from the
%    '+optarrow' folder, not object-oriented method dispatch.
%
% Convenience wrapper around optarrow.compute that accepts a standard COBRA
% QP struct and handles COO serialization automatically.
%
% USAGE:
%
%    result = optarrow.solveQP(QPproblem)
%    result = optarrow.solveQP(QPproblem, opts)
%
% INPUTS:
%    QPproblem   struct with fields:
%                  F / Q   sparse/dense matrix  Hessian (n x n); 'F' takes precedence
%                  c       double               linear objective vector (n x 1)
%                  A       sparse/dense matrix  constraint matrix (m x n)
%                  b       double               RHS vector (m x 1)
%                  lb      double               lower bounds (n x 1)
%                  ub      double               upper bounds (n x 1) (optional, default 1e30)
%                  csense  char/cell/string     sense per row: 'L','E','G'
%                  osense  numeric/char         -1 or 'max' to maximize, 1 or 'min' to minimize
%
%    opts        struct (optional) with fields:
%                  modelName   char     label for logging (default: 'matlab_qp')
%                  engine      char     'python' | 'julia' (default from config)
%                  solver      char     'HiGHS' | 'Gurobi' | ... (default from config)
%                  timeLimit   double   solver time limit in seconds (default: 300)
%                  endpoint    char     Gateway URL override
%                  transport   char     'auto' | 'arrow' | 'json'
%
% OUTPUT:
%    result   struct with fields:
%               success  logical
%               status   char
%               stat     double   1=optimal, 0=infeasible, 2=unbounded, -1=error
%               obj_val  double
%               solution double[]
%               dual     double[]
%               rcost    double[]
%               slack    double[]
%
% EXAMPLE:
%
%    QPproblem.F      = sparse([2 0; 0 2]);
%    QPproblem.c      = [-2; -5];
%    QPproblem.A      = sparse([1 1]);
%    QPproblem.b      = 3;
%    QPproblem.lb     = [0; 0];
%    QPproblem.csense = 'E';
%    QPproblem.osense = 1;
%    result = optarrow.solveQP(QPproblem);
%
% .. Author: - Farid Zare 12/04/2026

if nargin < 1 || ~isstruct(QPproblem)
    error('optarrow.solveQP: QPproblem must be a struct.');
end
if nargin < 2
    opts = struct();
end

cfg = optarrow.getOptArrowConfig();

modelName = localGetOr(opts, 'modelName', 'matlab_qp');
engine    = localGetOr(opts, 'engine',    localGetOr(cfg, 'engine',         'python'));
solver    = localGetOr(opts, 'solver',    localGetOr(cfg, 'backendSolver',  'HiGHS'));
timeLimit = localGetOr(opts, 'timeLimit', 300);

% Build COO sparse A
A = QPproblem.A;
if ~issparse(A), A = sparse(A); end
[r, c, v] = find(A);
model.A = struct( ...
    'row',   int64(r(:)' - 1), ...
    'col',   int64(c(:)' - 1), ...
    'val',   double(v(:)'), ...
    'shape', int64([size(A,1), size(A,2)]));

model.b  = double(QPproblem.b(:)');
model.c  = double(QPproblem.c(:)');
model.lb = double(QPproblem.lb(:)');

if isfield(QPproblem, 'ub') && ~isempty(QPproblem.ub)
    model.ub = double(QPproblem.ub(:)');
else
    model.ub = repmat(1e30, 1, size(A,2));
end

if isfield(QPproblem, 'csense') && ~isempty(QPproblem.csense)
    model.csense = QPproblem.csense;
else
    model.csense = repmat('E', size(A,1), 1);
end

if isfield(QPproblem, 'osense')
    model.osense = QPproblem.osense;
else
    model.osense = 'min';
end

% Build COO sparse Hessian (F takes precedence over Q)
hField = '';
if isfield(QPproblem, 'F') && ~isempty(QPproblem.F)
    hField = 'F';
elseif isfield(QPproblem, 'Q') && ~isempty(QPproblem.Q)
    hField = 'Q';
end

if ~isempty(hField)
    H = QPproblem.(hField);
    if ~issparse(H), H = sparse(H); end
    [hr, hc, hv] = find(H);
    model.F = struct( ...
        'row',   int64(hr(:)' - 1), ...
        'col',   int64(hc(:)' - 1), ...
        'val',   double(hv(:)'), ...
        'shape', int64([size(H,1), size(H,2)]));
end

payload               = struct();
payload.problem_type  = 'QP';
payload.engine        = engine;
payload.solver_name   = solver;
payload.model_name    = modelName;
payload.time_limit    = timeLimit;
payload.solver_params = struct();
payload.model         = model;

computeOpts = struct();
if isfield(opts, 'endpoint'),  computeOpts.endpoint  = opts.endpoint;  end
if isfield(opts, 'transport'), computeOpts.transport = opts.transport; end

result = optarrow.compute(payload, computeOpts);
end


% -------------------------------------------------------------------------
function val = localGetOr(s, field, default)
if isstruct(s) && isfield(s, field) && ~isempty(s.(field))
    val = s.(field);
else
    val = default;
end
end
