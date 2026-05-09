# OptArrow MATLAB Interface

This folder contains a general MATLAB client for OptArrow focused on:

- Arrow IPC transport (`/compute`) only
- Scalable sparse model transfer (COO)

## Files

- `+optarrow/setOptArrowConfig.m`: Set global OptArrow runtime config.
- `+optarrow/getOptArrowConfig.m`: Read global OptArrow runtime config.
- `+optarrow/compute.m`: Generic compute call through Arrow IPC.
- `+optarrow/solveLP.m`: LP convenience wrapper (`LPproblem` struct -> OptArrow payload).
- `py/optarrow_matlab_bridge.py`: Python bridge for Arrow IPC request/response.

## MATLAB prerequisites

1. MATLAB with Python integration enabled (`pyenv`).
2. Python packages in selected environment:
   - `pyarrow`
   - `requests`

## Quick usage

```matlab
addpath(genpath(fullfile(pwd, 'src', 'matlab')));

cfg = struct( ...
    'name', 'optarrow', ...
    'engine', 'python', ...
    'backendSolver', 'HiGHS', ...
    'backendSolverType', 'LP', ...
    'backendOptions', struct(), ...
    'endpoint', 'http://127.0.0.1:8000/compute', ...
    'timeoutSec', 120);

optarrow.setOptArrowConfig(cfg);

LPproblem = struct();
LPproblem.A = sparse([20 10; 10 20; 10 30]);
LPproblem.b = [200; 120; 150];
LPproblem.c = [5; 12];
LPproblem.lb = [0; 0];
LPproblem.ub = [1000; 1000];
LPproblem.csense = ['L'; 'L'; 'L'];
LPproblem.osense = -1;

result = optarrow.solveLP(LPproblem, struct('modelName', 'matlab_lp'));
disp(result)
```

## Notes

- This is intentionally Arrow-only to avoid duplicate JSON code paths.
- This repository intentionally contains no toolbox-specific adaptor code.
- Adaptor logic (e.g., COBRA Toolbox integration) should live in the downstream project.