function result = solveLP(LPproblem, opts)
% solveLP  Solve a COBRA-style LP problem via the OptArrow Gateway.
%
% NOTE:
%    'optarrow.solveLP(...)' is MATLAB package namespace syntax from the
%    '+optarrow' folder, not object-oriented method dispatch.
%
% Convenience wrapper around optarrow.compute that accepts a standard COBRA
% LP struct and handles COO serialization automatically.
%
% USAGE:
%
%    result = optarrow.solveLP(LPproblem)
%    result = optarrow.solveLP(LPproblem, opts)
%
% INPUTS:
%    LPproblem   struct with fields:
%                  A       sparse/dense matrix  constraint matrix (m x n)
%                  b       double               RHS vector (m x 1)
%                  c       double               objective vector (n x 1)
%                  lb      double               lower bounds (n x 1)
%                  ub      double               upper bounds (n x 1) (optional, default 1e30)
%                  csense  char/cell/string     sense per row: 'L','E','G'
%                  osense  numeric/char         -1 or 'max' to maximize, 1 or 'min' to minimize
%
%    opts        struct (optional) with fields:
%                  modelName   char     label for logging (default: 'matlab_lp')
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
%    LPproblem.A      = sparse([20 10; 10 20; 10 30]);
%    LPproblem.b      = [200; 120; 150];
%    LPproblem.c      = [5; 12];
%    LPproblem.lb     = [0; 0];
%    LPproblem.ub     = [1000; 1000];
%    LPproblem.csense = ['L'; 'L'; 'L'];
%    LPproblem.osense = -1;
%    result = optarrow.solveLP(LPproblem);
%
% .. Author: - Farid Zare 12/04/2026

if nargin < 1 || ~isstruct(LPproblem)
    error('optarrow.solveLP: LPproblem must be a struct.');
end
if nargin < 2
    opts = struct();
end

cfg = optarrow.getOptArrowConfig();

modelName = localGetOr(opts, 'modelName', 'matlab_lp');
engine    = localGetOr(opts, 'engine',    localGetOr(cfg, 'engine',         'python'));
solver    = localGetOr(opts, 'solver',    localGetOr(cfg, 'backendSolver',  'HiGHS'));
timeLimit = localGetOr(opts, 'timeLimit', 300);

% Build COO sparse A
A = LPproblem.A;
if ~issparse(A), A = sparse(A); end
[r, c, v] = find(A);
model.A = struct( ...
    'row',   int64(r(:)' - 1), ...
    'col',   int64(c(:)' - 1), ...
    'val',   double(v(:)'), ...
    'shape', int64([size(A,1), size(A,2)]));

model.b  = double(LPproblem.b(:)');
model.c  = double(LPproblem.c(:)');
model.lb = double(LPproblem.lb(:)');

if isfield(LPproblem, 'ub') && ~isempty(LPproblem.ub)
    model.ub = double(LPproblem.ub(:)');
else
    model.ub = repmat(1e30, 1, size(A,2));
end

if isfield(LPproblem, 'csense') && ~isempty(LPproblem.csense)
    model.csense = LPproblem.csense;
else
    model.csense = repmat('E', size(A,1), 1);
end

if isfield(LPproblem, 'osense')
    model.osense = LPproblem.osense;
else
    model.osense = 'min';
end

payload               = struct();
payload.problem_type  = 'LP';
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
