function result = compute(payload, varargin)
% compute  Submit a COBRA optimization request via native Apache Arrow IPC.
%
% NOTE:
%    'optarrow.compute(...)' is MATLAB package namespace syntax from the
%    '+optarrow' folder, not object-oriented method dispatch.
%
% This function serializes the request as a flat Arrow IPC stream and POSTs
% it directly to the OptArrow Gateway. No Python interpreter is involved.
% Requires MATLAB R2023b or later (for Arrow list-array support).
%
% If cfg.transport is 'json', the request is sent to /computeJSON using
% MATLAB's native JSON support. If cfg.transport is 'auto', Arrow IPC is used
% when the Arrow MATLAB interface is installed; otherwise JSON is used.
%
% USAGE:
%
%    result = optarrow.compute(payload)
%    result = optarrow.compute(payload, opts)
%
% INPUTS:
%    payload:   struct with fields:
%                 problem_type  char/string   'LP' | 'QP'
%                 engine        char/string   'python' | ...
%                 solver_name   char/string   'HiGHS' | 'Gurobi' | ...
%                 model_name    char/string   label for logging
%                 time_limit    numeric       seconds
%                 model         struct        problem data (see below)
%                 solver_params struct        backend solver options
%
%               model struct fields (LP):
%                 A       struct  COO sparse matrix with fields row, col, val, shape
%                 b       double  RHS vector
%                 c       double  objective coefficients
%                 lb      double  lower bounds
%                 ub      double  upper bounds
%                 csense  cell    {'L','E','G'} per constraint
%                 osense  char    'min' | 'max'
%
%               model struct fields (QP, additional):
%                 Q / F   struct  COO Hessian (row, col, val, shape)
%
% OPTIONAL INPUTS:
%    opts:   struct with transport overrides:
%              endpoint    char/string  Gateway URL
%              timeoutSec  numeric      HTTP timeout in seconds
%
% OUTPUT:
%    result:   struct with response fields:
%                success  logical
%                status   char
%                stat     double   1=optimal, 0=infeasible, 2=unbounded, -1=error
%                obj_val  double
%                solution double[]
%                dual     double[]
%                rcost    double[]
%                slack    double[]
%                method   char
%                time     double
%
% .. Author: - Farid Zare 12/04/2026

if nargin < 1 || ~isstruct(payload)
    error('optarrow.compute: payload must be a struct.');
end

cfg = optarrow.getOptArrowConfig();

opts = struct();
if nargin >= 2 && isstruct(varargin{1})
    opts = varargin{1};
end
if isfield(opts, 'endpoint'),   cfg.endpoint   = opts.endpoint;   end
if isfield(opts, 'timeoutSec'), cfg.timeoutSec = opts.timeoutSec; end
if isfield(opts, 'transport'),  cfg.transport  = opts.transport;  end

transport = localResolveTransport(cfg);
if strcmp(transport, 'json')
    result = localComputeJSON(payload, cfg);
    return;
end

% Build Arrow IPC request bytes
requestBytes = localBuildRequest(payload, cfg);

% POST to Gateway
responseBytes = localPost(requestBytes, cfg.endpoint, cfg.timeoutSec);

% Parse Arrow IPC response
result = localParseResponse(responseBytes);
end


% =========================================================================
% Transport selection / JSON fallback
% =========================================================================
function transport = localResolveTransport(cfg)
transport = 'auto';
if isfield(cfg, 'transport') && ~isempty(cfg.transport)
    transport = lower(char(string(cfg.transport)));
end

if strcmp(transport, 'auto')
    if localArrowAvailable()
        transport = 'arrow';
    else
        transport = 'json';
    end
elseif ~ismember(transport, {'arrow', 'json'})
    error('optarrow.compute: transport must be auto, arrow, or json.');
end
end

function tf = localArrowAvailable()
tf = exist('arrow.recordBatch', 'file') == 2;
end

function result = localComputeJSON(payload, cfg)
import matlab.net.http.*
import matlab.net.http.field.*
import matlab.net.http.io.*

jsonPayload = localJsonPayload(payload, cfg);
endpoint = localJsonEndpoint(cfg.endpoint);

try
    request = RequestMessage( ...
        RequestMethod.POST, ...
        ContentTypeField('application/json'), ...
        JSONProvider(jsonPayload));
    opts = matlab.net.http.HTTPOptions( ...
        'ConnectTimeout', double(cfg.timeoutSec), ...
        'ResponseTimeout', double(cfg.timeoutSec));

    response = request.send(matlab.net.URI(endpoint), opts);
    result = response.Body.Data;
    if isempty(result)
        result = struct();
    end

    statusCode = double(response.StatusCode);
    if statusCode < 200 || statusCode >= 300
        msg = sprintf('HTTP %d from %s.', statusCode, endpoint);
        if isstruct(result) && isfield(result, 'error_message')
            msg = sprintf('%s Server error: %s', msg, result.error_message);
        end
        err = struct('identifier', 'optarrow:computeJSONError', 'message', msg);
        error(err);
    end
catch ME
    if strcmp(ME.identifier, 'optarrow:computeJSONError')
        rethrow(ME);
    end
    err = struct( ...
        'identifier', 'optarrow:computeJSONError', ...
        'message', sprintf('JSON request to %s failed: %s', endpoint, ME.message));
    error(err);
end
end

function jsonPayload = localJsonPayload(payload, cfg)
jsonPayload = struct();
jsonPayload.model = localJsonModel(payload.model);

if isfield(payload, 'model_name') && ~isempty(payload.model_name)
    jsonPayload.model_name = payload.model_name;
else
    jsonPayload.model_name = 'matlab_model';
end

if isfield(payload, 'engine') && ~isempty(payload.engine)
    jsonPayload.engine = payload.engine;
elseif isfield(cfg, 'engine') && ~isempty(cfg.engine)
    jsonPayload.engine = cfg.engine;
else
    jsonPayload.engine = 'python';
end

if isfield(payload, 'solver') && isstruct(payload.solver)
    jsonPayload.solver = payload.solver;
else
    solver = struct();
    if isfield(payload, 'solver_name') && ~isempty(payload.solver_name)
        solver.solver_name = payload.solver_name;
    else
        solver.solver_name = cfg.backendSolver;
    end
    if isfield(payload, 'problem_type') && ~isempty(payload.problem_type)
        solver.solver_type = payload.problem_type;
    else
        solver.solver_type = cfg.backendSolverType;
    end
    if isfield(payload, 'solver_params') && isstruct(payload.solver_params)
        solver.solver_params = payload.solver_params;
    else
        solver.solver_params = cfg.backendOptions;
    end
    jsonPayload.solver = solver;
end

if isfield(payload, 'time_limit') && ~isempty(payload.time_limit)
    jsonPayload.time_limit = payload.time_limit;
end
end

function model = localJsonModel(model)
if isfield(model, 'A') && isstruct(model.A)
    model.A = localJsonCOO(model.A);
end
if isfield(model, 'Q') && isstruct(model.Q)
    model.Q = localJsonCOO(model.Q);
end
if isfield(model, 'F') && isstruct(model.F)
    model.F = localJsonCOO(model.F);
end
end

function coo = localJsonCOO(coo)
% /computeJSON reconstructs sparse matrices from row/col/val only.
% The Arrow IPC path uses shape separately, but including it here makes
% pyarrow.RecordBatch.from_pydict see columns of unequal length.
if isfield(coo, 'shape')
    coo = rmfield(coo, 'shape');
end
end

function endpoint = localJsonEndpoint(endpoint)
endpoint = char(string(endpoint));
if endsWith(endpoint, '/computeJSON')
    return;
elseif endsWith(endpoint, '/cobra/compute')
    endpoint = regexprep(endpoint, '/cobra/compute$', '/computeJSON');
elseif endsWith(endpoint, '/compute')
    endpoint = regexprep(endpoint, '/compute$', '/computeJSON');
else
    endpoint = [regexprep(endpoint, '/$', '') '/computeJSON'];
end
end


% =========================================================================
% Build Arrow IPC request
% =========================================================================
function ipcBytes = localBuildRequest(payload, cfg)

problemType = upper(char(string(payload.problem_type)));
engine      = char(string(payload.engine));
solverName  = char(string(payload.solver_name));
modelName   = char(string(payload.model_name));
if isfield(payload, 'time_limit') && ~isempty(payload.time_limit)
    timeLimit = double(payload.time_limit);
else
    timeLimit = 300;
end

model = payload.model;

% --- LP fields ---
[A_row, A_col, A_val, A_nrows, A_ncols] = localExtractCOO(model, 'A', 'A_nrows', 'A_ncols');
b      = localVec(model, 'b');
c      = localVec(model, 'c');
lb     = localVec(model, 'lb');
ub     = localVec(model, 'ub');
csense = localCsense(model, A_nrows);
osense = localOsense(model);

% --- QP fields (Hessian) ---
if isfield(model, 'Q') || isfield(model, 'F')
    hField = 'Q';
    if isfield(model, 'F'), hField = 'F'; end
    [Q_row, Q_col, Q_val, ~, ~] = localExtractCOO(model, hField, '', '');
else
    Q_row = int64([]);
    Q_col = int64([]);
    Q_val = double([]);
end

% --- Solver params → parallel key/val string lists ---
[paramKeys, paramVals] = localPackParams(payload);

% --- Build MATLAB table (one row, list-typed columns) ---
% Each vector field is wrapped in {} to produce an Arrow list column.
T = table();
T.problem_type = string(problemType);
T.engine       = string(engine);
T.solver_name  = string(solverName);
T.model_name   = string(modelName);
T.time_limit   = timeLimit;
T.osense       = string(osense);
T.A_row        = {A_row};
T.A_col        = {A_col};
T.A_val        = {A_val};
T.A_nrows      = int64(A_nrows);
T.A_ncols      = int64(A_ncols);
T.b            = {b};
T.c            = {c};
T.lb           = {lb};
T.ub           = {ub};
T.csense       = {csense};
T.Q_row        = {Q_row};
T.Q_col        = {Q_col};
T.Q_val        = {Q_val};
T.param_keys   = {paramKeys};
T.param_vals   = {paramVals};

% Write Arrow IPC stream to temp file, then read raw bytes
tmpFile = [tempname '.arrow'];
cleanup = onCleanup(@() localDeleteFile(tmpFile)); %#ok<NASGU>

rb     = arrow.recordBatch(T);
writer = arrow.io.ipc.RecordBatchStreamWriter(tmpFile, rb.Schema);
writer.writeRecordBatch(rb);
writer.close();

fid = fopen(tmpFile, 'rb');
if fid == -1
    error('optarrow.compute: could not read temporary Arrow file.');
end
ipcBytes = fread(fid, inf, '*uint8');
fclose(fid);
end


% =========================================================================
% HTTP POST
% =========================================================================
function responseBytes = localPost(ipcBytes, endpoint, timeoutSec)
import matlab.net.http.*
import matlab.net.http.field.*
import matlab.net.http.io.*

contentType = ContentTypeField('application/vnd.apache.arrow.stream');
try
    provider = matlab.net.http.io.ByteArrayProvider(ipcBytes);
    request  = RequestMessage(RequestMethod.POST, contentType, provider);
catch
    % Fallback for older MATLAB versions without ByteArrayProvider.
    tmpFile = [tempname '.arrow'];
    cleanup = onCleanup(@() localDeleteFile(tmpFile)); %#ok<NASGU>

    fid = fopen(tmpFile, 'wb');
    if fid == -1
        error('optarrow.compute: could not write temporary Arrow request file.');
    end
    fwrite(fid, ipcBytes, 'uint8');
    fclose(fid);

    provider = matlab.net.http.io.FileProvider(tmpFile);
    request  = RequestMessage(RequestMethod.POST, contentType, provider);
end

opts = matlab.net.http.HTTPOptions( ...
    'ConnectTimeout', double(timeoutSec), ...
    'ResponseTimeout', double(timeoutSec));

uri      = matlab.net.URI(endpoint);
response = request.send(uri, opts);

if isempty(response.Body) || isempty(response.Body.Data)
    error('optarrow.compute: empty response from Gateway at %s.', endpoint);
end

responseBytes = response.Body.Data;
if ~isa(responseBytes, 'uint8')
    responseBytes = uint8(responseBytes);
end
end


% =========================================================================
% Parse Arrow IPC response
% =========================================================================
function result = localParseResponse(responseBytes)

reader = arrow.io.ipc.RecordBatchStreamReader.fromBytes(responseBytes(:));
rb     = reader.read();

result = struct();
colNames = rb.ColumnNames;
for i = 1:numel(colNames)
    name = colNames{i};
    col  = rb.column(i);
    result.(name) = localArrowToMatlab(col);
end
end


% =========================================================================
% Helpers
% =========================================================================
function [rowIdx, colIdx, vals, nrows, ncols] = localExtractCOO(model, fieldName, nrowsField, ncolsField)
if isfield(model, fieldName) && ~isempty(model.(fieldName))
    M = model.(fieldName);
    if isstruct(M)
        rowIdx = int64(M.row(:));
        colIdx = int64(M.col(:));
        vals   = double(M.val(:));
        if isfield(M, 'shape') && ~isempty(M.shape)
            nrows = int64(M.shape(1));
            ncols = int64(M.shape(2));
        else
            nrows = int64(max(rowIdx) + 1);
            ncols = int64(max(colIdx) + 1);
        end
    else
        % dense matrix — convert
        if ~issparse(M), M = sparse(M); end
        [r, c, v] = find(M);
        rowIdx = int64(r(:) - 1);
        colIdx = int64(c(:) - 1);
        vals   = double(v(:));
        nrows  = int64(size(M,1));
        ncols  = int64(size(M,2));
    end
else
    rowIdx = int64([]);
    colIdx = int64([]);
    vals   = double([]);
    nrows  = int64(0);
    ncols  = int64(0);
end
end

function v = localVec(model, field)
if isfield(model, field) && ~isempty(model.(field))
    v = double(model.(field)(:)');
else
    v = double([]);
end
end

function cs = localCsense(model, nrows)
if isfield(model, 'csense') && ~isempty(model.csense)
    raw = model.csense;
    if ischar(raw)
        cs = string(upper(cellstr(raw(:))))';
    elseif isstring(raw)
        cs = upper(raw(:))';
    elseif iscell(raw)
        cs = upper(string(raw(:)))';
    else
        cs = repmat("E", 1, nrows);
    end
else
    cs = repmat("E", 1, nrows);
end
end

function os = localOsense(model)
if ~isfield(model, 'osense') || isempty(model.osense)
    os = 'min';
    return;
end
v = model.osense;
if isnumeric(v)
    os = 'max'; if v ~= -1, os = 'min'; end
else
    os = 'min'; if strcmpi(string(v), 'max'), os = 'max'; end
end
end

function [keys, vals] = localPackParams(payload)
if isfield(payload, 'solver_params') && isstruct(payload.solver_params) ...
        && ~isempty(fieldnames(payload.solver_params))
    fns  = fieldnames(payload.solver_params);
    keys = string(fns)';
    vals = string(cellfun(@(f) num2str(payload.solver_params.(f)), fns, 'UniformOutput', false))';
else
    keys = string([]);
    vals = string([]);
end
end

function v = localArrowToMatlab(col)
% Convert an Arrow column (chunk array) to a MATLAB value.
if ismethod(col, 'chunk')
    arr = col.chunk(1);
else
    arr = col;
end
switch class(arr)
    case {'arrow.array.BooleanArray'}
        v = logical(arr.toMATLAB());
    case {'arrow.array.ListArray'}
        listVals = arr.toMATLAB();
        if iscell(listVals) && numel(listVals) == 1
            v = double(listVals{1}(:))';
        else
            v = listVals;
        end
    case {'arrow.array.StringArray'}
        v = char(arr.toMATLAB());
    otherwise
        v = double(arr.toMATLAB());
end
end

function localDeleteFile(f)
if exist(f, 'file'), delete(f); end
end
