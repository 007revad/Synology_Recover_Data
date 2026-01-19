#!/bin/bash

# Production-grade mdadm 3.4 builder for Synology recovery
# Handles: multiple download mirrors, build failures, architecture detection

set -e

MDADM_VERSION="3.4"
MDADM_BUILD_DIR="${1:-.}"
MDADM_BINARY="${MDADM_BUILD_DIR}/mdadm-3.4"
MDADM_RELEASE_DATE="2023-03-10"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

check_prerequisites() {
    local missing=0
    
    for cmd in make wget tar gcc; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Missing required tool: $cmd"
            missing=$((missing + 1))
        fi
    done
    
    if [ $missing -gt 0 ]; then
        log_error "Install missing tools with: sudo apt-get install build-essential wget"
        return 1
    fi
    
    return 0
}

print_system_info() {
    log_info "System Information:"
    log_info "  Architecture: $(uname -m)"
    log_info "  OS: $(lsb_release -ds 2>/dev/null || echo 'Unknown')"
    log_info "  Kernel: $(uname -r)"
    log_info "  CPU cores: $(nproc)"
}

download_mdadm() {
    local temp_dir="$1"
    
    # Multiple mirror sources for reliability
    local mirrors=(
        "https://www.kernel.org/pub/linux/utils/raid/mdadm/mdadm-3.4.tar.xz"
        "https://mirrors.edge.kernel.org/pub/linux/utils/raid/mdadm/mdadm-3.4.tar.xz"
    )
    
    for mirror in "${mirrors[@]}"; do
        log_info "Trying mirror: $mirror"
        if wget -q -O "$temp_dir/mdadm-3.4.tar.xz" "$mirror" 2>/dev/null; then
            log_success "Downloaded from: $mirror"
            return 0
        fi
    done
    
    log_error "Failed to download mdadm 3.4 from all mirrors"
    return 1
}

compile_mdadm() {
    local source_dir="$1"
    
    cd "$source_dir"
    
    # Try static compilation first (best for portability across systems)
    log_info "Attempting static compilation..."
    if make -j"$(nproc)" EXTRA_CFLAGS="-static -O2" 2>&1 | grep -E "error|Error"; then
        log_warn "Static compilation had errors, trying without -static..."
        make clean 2>&1 > /dev/null || true
    fi
    
    # Try dynamic compilation if static failed
    if [ ! -f ./mdadm ] || [ ! -x ./mdadm ]; then
        log_info "Attempting dynamic compilation..."
        if ! make -j"$(nproc)" EXTRA_CFLAGS="-O2" 2>&1 | tail -5; then
            log_error "Compilation failed"
            return 1
        fi
    fi
    
    if [ -f ./mdadm ] && [ -x ./mdadm ]; then
        log_success "Compilation successful"
        ./mdadm --version
        return 0
    else
        log_error "mdadm binary not found after compilation"
        return 1
    fi
}

verify_binary() {
    local binary="$1"
    
    if [ ! -f "$binary" ] || [ ! -x "$binary" ]; then
        log_error "Binary verification failed: $binary not found or not executable"
        return 1
    fi
    
    local version=$("$binary" --version | head -1)
    log_success "Binary verified: $version"
    
    # Quick functionality test
    if "$binary" --version &>/dev/null; then
        return 0
    else
        log_error "Binary functionality test failed"
        return 1
    fi
}

main() {
    log_info "mdadm ${MDADM_VERSION} Builder (Release: ${MDADM_RELEASE_DATE})"
    
    # Check if already built
    if [ -f "$MDADM_BINARY" ] && [ -x "$MDADM_BINARY" ]; then
        log_success "mdadm ${MDADM_VERSION} already built at: $MDADM_BINARY"
        verify_binary "$MDADM_BINARY" && exit 0
    fi
    
    print_system_info
    
    # Install prerequisites
    apt-get install build-essential wget
    
    # Check prerequisites
    if ! check_prerequisites; then
        exit 1
    fi
    
    # Create temporary build directory
    local temp_dir
    temp_dir=$(mktemp -d) || { log_error "Failed to create temp directory"; exit 1; }
    trap "rm -rf '$temp_dir'" EXIT
    
    log_info "Build directory: $temp_dir"
    
    # Download
    if ! download_mdadm "$temp_dir"; then
        exit 1
    fi
    
    # Extract
    log_info "Extracting source..."
    if ! tar -xf "$temp_dir/mdadm-3.4.tar.xz" -C "$temp_dir"; then
        log_error "Failed to extract mdadm source"
        exit 1
    fi
    
    # Compile
    if ! compile_mdadm "$temp_dir/mdadm-3.4"; then
        exit 1
    fi
    
    # Install binary
    log_info "Installing binary to: $MDADM_BINARY"
    if ! cp "$temp_dir/mdadm-3.4/mdadm" "$MDADM_BINARY"; then
        log_error "Failed to copy binary"
        exit 1
    fi
    chmod +x "$MDADM_BINARY"
    
    # Verify
    if ! verify_binary "$MDADM_BINARY"; then
        exit 1
    fi
    
    log_success "Build complete! Binary ready at: $MDADM_BINARY"
    log_info "File size: $(du -h "$MDADM_BINARY" | cut -f1)"
}

main "$@"
