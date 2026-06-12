#!/bin/sh
# Standalone runtime tests for Alpine udhcpd container
# Tests basic container functionality without external dependencies

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

IMAGE_NAME="${1:-alpine-udhcpd:main}"
CONTAINER_NAME="udhcpd-test-standalone-$$"

cleanup() {
    cleanup_container "$CONTAINER_NAME"
}

trap cleanup EXIT

log_info "========================================="
log_info "Standalone Tests for $IMAGE_NAME"
log_info "========================================="
echo ""

# Start container with test configuration
log_info "Starting udhcpd container in standalone mode..."
if docker run -d --name "$CONTAINER_NAME" \
    -v "$SCRIPT_DIR/configs/udhcpd-test.conf:/etc/udhcpd.conf:ro" \
    "$IMAGE_NAME"; then
    log_success "Container started successfully"
else
    log_error "Container failed to start"
    exit 1
fi

# Test 1: Container stays running
log_info "Test 1: Container stability check"
if wait_container_stable "$CONTAINER_NAME" 5; then
    log_success "Container is stable and running"
else
    log_error "Container is not stable"
    docker logs "$CONTAINER_NAME" 2>&1 | tail -20
fi

# Test 2: udhcpd process is running
log_info "Test 2: udhcpd process is running"
if docker exec "$CONTAINER_NAME" ps aux 2>/dev/null | grep -v grep | grep -q udhcpd; then
    log_success "udhcpd process is running"
else
    log_error "udhcpd process is not running"
    docker exec "$CONTAINER_NAME" ps aux 2>/dev/null || true
fi

# Test 3: Startup log shows 'started'
log_info "Test 3: udhcpd startup log shows success"
sleep 2
if docker logs "$CONTAINER_NAME" 2>&1 | grep -qi "started"; then
    log_success "udhcpd startup confirmed in logs"
else
    log_warn "Could not confirm udhcpd startup from logs"
    docker logs "$CONTAINER_NAME" 2>&1 | head -10
fi

# Test 4: No fatal errors in logs
log_info "Test 4: No fatal errors in logs"
if docker logs "$CONTAINER_NAME" 2>&1 | grep -qiE "error:|fatal|failed to|cannot"; then
    ERRORS=$(docker logs "$CONTAINER_NAME" 2>&1 | grep -iE "error:|fatal|failed to|cannot" | head -5)
    log_warn "Potential errors found in logs: $ERRORS"
else
    log_success "No errors in logs"
fi

# Test 5: DHCP UDP port 67 is bound
log_info "Test 5: DHCP UDP port 67 is bound"
if docker exec "$CONTAINER_NAME" sh -c \
    "netstat -uln 2>/dev/null | grep -q ':67' || ss -uln 2>/dev/null | grep -q ':67'"; then
    log_success "DHCP UDP port 67 is bound"
else
    log_warn "Could not confirm port 67 is bound (may require elevated privileges)"
fi

# Test 6: Container still running after all tests
log_info "Test 6: Container still running after all tests"
if is_container_running "$CONTAINER_NAME"; then
    log_success "Container still running"
else
    log_error "Container stopped during tests"
    docker logs "$CONTAINER_NAME" 2>&1 | tail -30
fi

# Print summary and exit
print_summary "Standalone Tests"
exit $TEST_FAILED
