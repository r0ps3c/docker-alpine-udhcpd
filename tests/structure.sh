#!/bin/sh
# Structure tests for Alpine udhcpd Docker image
# Pure POSIX sh - no external dependencies
# Tests: ports, binary existence, packages, base image, image size

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

IMAGE_NAME="${1:-alpine-udhcpd:main}"
CONTAINER_NAME="udhcpd-test-structure-$$"

cleanup() {
    cleanup_container "$CONTAINER_NAME"
}

trap cleanup EXIT

log_info "========================================="
log_info "Structure Tests for $IMAGE_NAME"
log_info "========================================="
echo ""

# Start container for inspection (override entrypoint with sleep)
log_info "Starting container for structure inspection..."
docker run -d --name "$CONTAINER_NAME" --entrypoint sleep "$IMAGE_NAME" 3600 >/dev/null 2>&1

# Test 1: DHCP port 67/udp exposed
log_info "Test 1: Image exposes DHCP port (67/udp)"
EXPOSED_PORTS=$(docker inspect "$IMAGE_NAME" --format='{{json .Config.ExposedPorts}}' 2>/dev/null || echo "")
if echo "$EXPOSED_PORTS" | grep -q "67/udp"; then
    log_success "DHCP port 67/udp is exposed"
else
    log_error "Expected DHCP port 67/udp not exposed: $EXPOSED_PORTS"
fi

# Test 2: udhcpd binary exists
log_info "Test 2: udhcpd binary exists at /usr/sbin/udhcpd"
if docker exec "$CONTAINER_NAME" test -f /usr/sbin/udhcpd; then
    log_success "udhcpd binary exists"
else
    log_error "udhcpd binary not found"
fi

# Test 3: udhcpd binary is executable
log_info "Test 3: udhcpd binary is executable"
if docker exec "$CONTAINER_NAME" test -x /usr/sbin/udhcpd; then
    log_success "udhcpd binary is executable"
else
    log_error "udhcpd binary is not executable"
fi

# Test 4: busybox-extras package is installed
log_info "Test 4: busybox-extras package installed"
if docker exec "$CONTAINER_NAME" apk info busybox-extras 2>/dev/null | grep -q "^busybox-extras-"; then
    log_success "busybox-extras package is installed"
else
    log_error "busybox-extras package is not installed"
fi

# Test 5: Version is extractable and in valid semver format
log_info "Test 5: busybox-extras version extractable and valid semver format"
VERSION=$(docker exec "$CONTAINER_NAME" sh -c \
    "apk info busybox-extras 2>/dev/null | grep '^busybox-extras-[0-9]' | head -1 | sed 's/^busybox-extras-//' | sed 's/ .*//' | sed 's/-r[0-9]*\$//'")
if echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+'; then
    log_success "Version is extractable and valid: $VERSION"
else
    log_error "Version format invalid: $VERSION"
fi

# Test 6: Leases file created in image
log_info "Test 6: Leases file /var/lib/misc/udhcpd.leases exists"
if docker exec "$CONTAINER_NAME" test -f /var/lib/misc/udhcpd.leases; then
    log_success "Leases file exists"
else
    log_error "Leases file /var/lib/misc/udhcpd.leases not found"
fi

# Test 7: No APK cache files left behind
log_info "Test 7: No APK cache files left in /var/cache/apk"
CACHE_COUNT=$(docker exec "$CONTAINER_NAME" sh -c 'ls /var/cache/apk 2>&1 | wc -l' 2>/dev/null || echo "1")
if [ "$CACHE_COUNT" = "0" ]; then
    log_success "No APK cache files"
else
    log_warn "Found $CACHE_COUNT items in /var/cache/apk (may be expected)"
fi

# Test 8: Image size is reasonable (< 15MB)
log_info "Test 8: Image size is reasonable (< 15MB)"
IMAGE_SIZE=$(docker inspect "$IMAGE_NAME" --format='{{.Size}}' 2>/dev/null || echo "0")
IMAGE_SIZE_MB=$((IMAGE_SIZE / 1024 / 1024))
if [ "$IMAGE_SIZE_MB" -lt 15 ]; then
    log_success "Image size is ${IMAGE_SIZE_MB}MB (< 15MB)"
else
    log_warn "Image size is ${IMAGE_SIZE_MB}MB (larger than expected)"
fi

# Test 9: Base image is Alpine Linux
log_info "Test 9: Base image is Alpine Linux"
if docker exec "$CONTAINER_NAME" cat /etc/os-release 2>/dev/null | grep -q "Alpine"; then
    log_success "Base image is Alpine Linux"
else
    log_error "Base image is not Alpine Linux"
fi

# Test 10: No temporary files in /tmp
log_info "Test 10: No temporary files left in /tmp"
TMP_COUNT=$(docker exec "$CONTAINER_NAME" sh -c 'ls /tmp 2>&1 | wc -l' 2>/dev/null || echo "1")
if [ "$TMP_COUNT" = "0" ]; then
    log_success "No temporary files in /tmp"
else
    log_warn "Found $TMP_COUNT items in /tmp"
fi

# Print summary and exit
print_summary "Structure Tests"
exit $TEST_FAILED
