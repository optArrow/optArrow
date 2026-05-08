function setupMATLABArrow(arrowMatlabDir)
% setupMATLABArrow  Add MATLAB Arrow interface to MATLAB search path.
%
% USAGE:
%    setupMATLABArrow()                         % Use default location
%    setupMATLABArrow('/path/to/arrow_matlab/arrow_matlab')
%
% DESCRIPTION:
%    Adds the MATLAB Arrow interface to the MATLAB search path and saves
%    the configuration persistently. This is needed after building Arrow
%    MATLAB from source.
%
% DEFAULT LOCATION:
%    Uses the bundled Linux x86_64 build when available, otherwise falls
%    back to $HOME/arrow_matlab/arrow_matlab.
%
% EXAMPLE:
%    % From OptArrow MATLAB directory:
%    setupMATLABArrow();
%
% Author:
%    - Farid Zare 12/04/2026

if nargin < 1 || isempty(arrowMatlabDir)
    arrowMatlabDir = localDefaultArrowMatlabDir();
end

% Verify directory exists
if ~isdir(arrowMatlabDir)
    error(['setupMATLABArrow: Arrow MATLAB directory not found at:\n  %s\n\n' ...
        'Please specify the correct path or build Arrow from source.\n' ...
        'See: https://github.com/apache/arrow/tree/main/matlab'], ...
        arrowMatlabDir);
end

% Verify Arrow is buildable (check for +arrow package)
if ~isdir(fullfile(arrowMatlabDir, '+arrow'))
    error(['setupMATLABArrow: Invalid Arrow MATLAB installation.\n' ...
        'Expected +arrow package at: %s\n' ...
        'Please rebuild Arrow MATLAB.'], arrowMatlabDir);
end

% Add to search path
fprintf('Adding Arrow MATLAB to search path:\n  %s\n', arrowMatlabDir);
addpath(arrowMatlabDir);

% Verify installation
try
    fprintf('\nVerifying Arrow installation...\n');
    testTable = table(["test"], [1]);
    rb = arrow.recordBatch(testTable);
    fprintf('✓ Arrow MATLAB interface is working!\n');
catch ME
    if contains(ME.message, 'GLIBCXX_')
        error(['setupMATLABArrow: Bundled Linux Arrow build is not compatible ' ...
            'with this MATLAB runtime.\n\n' ...
            'MATLAB loaded a libstdc++.so.6 that is missing a C++ runtime ' ...
            'symbol required by the bundled Arrow MEX file.\n\n' ...
            'Fallback: build Arrow MATLAB locally with:\n' ...
            '  ./scripts/buildMATLABArrow.sh\n\n' ...
            'Then rerun setupMATLABArrow with the installed path, for example:\n' ...
            '  setupMATLABArrow(fullfile(getenv(''HOME''), ''arrow_matlab'', ''arrow_matlab''))\n\n' ...
            'Original error:\n%s'], ME.message);
    end
    error(['setupMATLABArrow: Arrow verification failed.\n' ...
        'Error: %s\n\n' ...
        'This may indicate an incomplete installation.'], ME.message);
end

% Save path persistently only after the Arrow interface is verified.
try
    savepath;
    fprintf('Search path saved successfully.\n');
catch ME
    warning('setupMATLABArrow:SavePath', ...
        ['Could not save search path persistently.\n' ...
        'The path will be lost when MATLAB exits.\n' ...
        'Error: %s\n\n' ...
        'You can manually save with: savepath'], ME.message);
end

end

function arrowMatlabDir = localDefaultArrowMatlabDir()
% Prefer a repo-bundled platform build, then fall back to the source-build
% location used by scripts/buildMATLABArrow.sh.

scriptPath = mfilename('fullpath');
scriptDir = fileparts(scriptPath);
repoRoot = fileparts(scriptDir);

platformDir = '';
if isunix && ~ismac && strcmp(computer('arch'), 'glnxa64')
    platformDir = 'linux-x86_64';
end

if ~isempty(platformDir)
    bundledDir = fullfile(repoRoot, 'src', 'matlab', 'vendor', ...
        'apache-arrow', platformDir, 'arrow_matlab');
    if isdir(bundledDir)
        arrowMatlabDir = bundledDir;
        return;
    end
end

homeDir = char(java.lang.System.getProperty('user.home'));
arrowMatlabDir = fullfile(homeDir, 'arrow_matlab', 'arrow_matlab');
end
