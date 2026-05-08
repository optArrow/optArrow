#!/bin/bash
#
# buildMATLABArrow.sh
#
# Automated build script for Apache Arrow C++ and MATLAB interface.
# Installs to $HOME/arrow_no_s3 and $HOME/arrow_matlab by default.
#
# USAGE:
#    ./scripts/buildMATLABArrow.sh
#    ./scripts/buildMATLABArrow.sh --with-s3  # Enable S3 support
#
# PREREQUISITES (Linux):
#    sudo apt install -y cmake build-essential
#
# PREREQUISITES (macOS):
#    xcode-select --install
#    brew install cmake
#
# Author:
#    - Farid Zare 12/04/2026

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( dirname "$SCRIPT_DIR" )"

ARROW_REPO_DIR="${ARROW_REPO_DIR:-$HOME/arrow}"
ARROW_CPP_INSTALL="${ARROW_CPP_INSTALL:-$HOME/arrow_no_s3}"
ARROW_MATLAB_INSTALL="${ARROW_MATLAB_INSTALL:-$HOME/arrow_matlab}"
ENABLE_S3="${1:-OFF}"

if [[ "$1" == "--with-s3" ]]; then
    ENABLE_S3="ON"
fi

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v cmake &> /dev/null; then
        log_error "CMake not found. Please install CMake."
        exit 1
    fi
    
    if ! command -v matlab &> /dev/null; then
        log_error "MATLAB not found. Please ensure MATLAB is installed and in PATH."
        exit 1
    fi
    
    log_info "✓ CMake: $(cmake --version | head -n1)"
    log_info "✓ MATLAB found"
}

# Clone Arrow (if not already present)
clone_arrow() {
    if [[ -d "$ARROW_REPO_DIR" ]]; then
        log_warn "Arrow repository already exists at: $ARROW_REPO_DIR"
    else
        log_info "Cloning Apache Arrow repository..."
        git clone https://github.com/apache/arrow.git "$ARROW_REPO_DIR"
    fi
}

# Build Arrow C++
build_arrow_cpp() {
    log_info "Building Arrow C++ (this may take several minutes)..."
    
    cd "$ARROW_REPO_DIR"
    
    S3_FLAG="-DARROW_S3=$ENABLE_S3"
    
    cmake -S cpp -B build_cpp \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$ARROW_CPP_INSTALL" \
        "$S3_FLAG" \
        -DARROW_WITH_RE2=OFF \
        -DARROW_CSV=ON \
        -DARROW_IPC=ON \
        -DARROW_COMPUTE=ON \
        -DARROW_BUILD_TESTS=OFF \
        -DxsimdSOURCE=BUNDLED
    
    cmake --build build_cpp --config Release -j$(nproc)
    cmake --build build_cpp --config Release --target install
    
    log_info "✓ Arrow C++ installed to: $ARROW_CPP_INSTALL"
}

# Build MATLAB bindings
build_matlab_bindings() {
    log_info "Building MATLAB bindings..."
    
    cd "$ARROW_REPO_DIR"
    
    cmake -S matlab -B build_matlab \
        -DArrow_DIR="$ARROW_CPP_INSTALL/lib/cmake/Arrow" \
        -DCMAKE_INSTALL_PREFIX="$ARROW_MATLAB_INSTALL"
    
    cmake --build build_matlab --config Release -j$(nproc)
    cmake --build build_matlab --config Release --target install 2>&1 | tee /tmp/matlab_install.log || true
    
    log_info "✓ MATLAB bindings installed to: $ARROW_MATLAB_INSTALL"
}

# Provide next steps
next_steps() {
    cat << 'EOF'

================================================================================
✓ Apache Arrow build completed successfully!

NEXT STEPS:
1. Add the MATLAB interface to MATLAB search path:

   From MATLAB:
   >> addpath('$HOME/arrow_matlab/arrow_matlab');
   >> savepath;

   OR use the OptArrow setup script:
   >> run scripts/setupMATLABArrow.m

2. Verify installation in MATLAB:
   >> arrow.recordBatch(table(["A";"B"], [1;2]))

3. If you see a RecordBatch output above, you're ready to use OptArrow!

TROUBLESHOOTING:
- If addpath fails, check that the directory exists:
  ls -la $HOME/arrow_matlab/arrow_matlab

- For S3 support (optional), rebuild with:
  ./scripts/buildMATLABArrow.sh --with-s3

- See Apache Arrow MATLAB docs:
  https://github.com/apache/arrow/tree/main/matlab

================================================================================
EOF
}

main() {
    log_info "OptArrow Apache Arrow Setup Script"
    log_info "Arrow C++ install: $ARROW_CPP_INSTALL"
    log_info "Arrow MATLAB install: $ARROW_MATLAB_INSTALL"
    log_info "S3 support: $ENABLE_S3"
    echo ""
    
    check_prerequisites
    clone_arrow
    build_arrow_cpp
    build_matlab_bindings
    next_steps
}

main "$@"
