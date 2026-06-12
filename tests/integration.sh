#!/bin/sh
# Integration tests for Alpine udhcpd container
# Tests container in a Docker network environment

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

IMAGE_NAME="${1:-alpine-udhcpd:main}"

TEST_ID=$$
UDHCPD_CONTAINER="udhcpd-test-integration-$TEST_ID"
NETWORK_NAME="udhcpd-test-$TEST_ID"

cleanup() {
    log_info "Cleaning up integration test environment..."
    docker rm -f "$UDHCPD_CONTAINER" 2>/dev/null || true
    docker network rm "$NETWORK_NAME" 2>/dev/null || true
}

trap cleanup EXIT

log_info "========================================="
log_info "Integration Tests for $IMAGE_NAME"
log_info "========================================="
echo ""

# Create isolated test network
log_info "Creating test network..."
docker network create "$NETWORK_NAME"

# Start udhcpd with test configuration
log_info "Starting udhcpd container..."
docker run -d \
    --name "$UDHCPD_CONTAINER" \
    --network "$NETWORK_NAME" \
    --network-alias udhcpd \
    -v "$SCRIPT_DIR/configs/udhcpd-test.conf:/etc/udhcpd.conf:ro" \
    "$IMAGE_NAME"

# Test 1: Container is running
log_info "Test 1: udhcpd container is running"
sleep 5
if is_container_running "$UDHCPD_CONTAINER"; then
    log_success "udhcpd container is running"
else
    log_error "udhcpd container is not running"
    docker logs "$UDHCPD_CONTAINER" 2>&1 | tail -20
fi

# Test 2: Container stability
log_info "Test 2: udhcpd container stability check"
if wait_container_stable "$UDHCPD_CONTAINER" 10; then
    log_success "udhcpd container is stable"
else
    log_error "udhcpd container is not stable (restarting?)"
fi

# Test 3: udhcpd process running inside container
log_info "Test 3: udhcpd process running"
if docker exec "$UDHCPD_CONTAINER" ps aux 2>/dev/null | grep -v grep | grep -q udhcpd; then
    log_success "udhcpd process is running"
else
    log_error "udhcpd process not found"
fi

# Test 4: Startup log shows 'started'
log_info "Test 4: udhcpd startup log shows success"
if docker logs "$UDHCPD_CONTAINER" 2>&1 | grep -qi "started"; then
    log_success "udhcpd startup confirmed in logs"
else
    log_warn "Could not confirm startup from logs"
    docker logs "$UDHCPD_CONTAINER" 2>&1 | head -10
fi

# Test 5: No critical errors in logs
log_info "Test 5: No critical errors in udhcpd logs"
if docker logs "$UDHCPD_CONTAINER" 2>&1 | grep -qiE "fatal|segfault|panic"; then
    log_error "Critical errors found in logs"
    docker logs "$UDHCPD_CONTAINER" 2>&1 | grep -iE "fatal|segfault|panic" | head -10
else
    log_success "No critical errors in logs"
fi

# Test 6: Container still running after all checks
log_info "Test 6: Container still running after integration tests"
if is_container_running "$UDHCPD_CONTAINER"; then
    log_success "udhcpd container still running"
else
    log_error "udhcpd container stopped unexpectedly"
    docker logs "$UDHCPD_CONTAINER" 2>&1 | tail -20
fi

# Print summary and exit
print_summary "Integration Tests"
exit $TEST_FAILED
