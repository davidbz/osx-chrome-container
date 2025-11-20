#!/bin/bash
set -euo pipefail

# Color codes
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# Constants
readonly CHROME_CMD="/usr/local/bin/chrome-launch.sh"
readonly BASE_IMAGE="chrome-base"
readonly X11_IMAGE="chrome-x11"
readonly VNC_IMAGE="chrome-vnc"
readonly CONTAINERS=("chrome-x11" "chrome-vnc")
readonly IMAGES=("$VNC_IMAGE" "$X11_IMAGE" "$BASE_IMAGE")
readonly PROFILE_VOLUME="chrome-profile-data"
readonly XQUARTZ_APP="/Applications/Utilities/XQuartz.app"
readonly XQUARTZ_PROCESS="Xquartz"
readonly X11_PORT="6000"
readonly DOCKERFILE_BASE="docker/Dockerfile.base"
readonly DOCKERFILE_VNC="docker/Dockerfile.vnc"
readonly DOCKERFILE_X11="docker/Dockerfile.x11"

# Helper functions
log_info() {
    echo -e "${GREEN}$*${NC}"
}

log_warn() {
    echo -e "${YELLOW}$*${NC}"
}

log_error() {
    echo -e "${RED}$*${NC}"
}

image_exists() {
    docker image inspect "$1" &>/dev/null
}

file_required() {
    if [[ ! -f "$1" ]]; then
        log_error "$1 not found"
        exit 1
    fi
}

prepare_extensions_dir() {
    # Create extensions directory if it doesn't exist
    mkdir -p "$(pwd)/extensions"
}

build_image_if_needed() {
    local dockerfile="$1"
    local image_name="$2"
    
    if ! image_exists "$image_name"; then
        log_warn "Building $image_name Docker image..."
        file_required "$dockerfile"
        docker build -f "$dockerfile" -t "$image_name" .
    fi
}

cleanup_resources() {
    log_warn "=== Cleaning up Docker images ===\n"
    
    # Stop and remove containers
    for container in "${CONTAINERS[@]}"; do
        if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
            log_warn "Removing container: ${container}"
            docker rm -f "${container}" &>/dev/null || true
        fi
    done
    
    # Remove images
    local images_removed=0
    for image in "${IMAGES[@]}"; do
        if image_exists "$image"; then
            log_warn "Removing image: ${image}"
            docker rmi "$image"
            ((images_removed++))
        else
            log_info "Image ${image} not found (already cleaned)"
        fi
    done
    
    if ((images_removed > 0)); then
        log_info "\nCleanup complete! Removed ${images_removed} image(s)."
    else
        log_info "\nNo images to clean up."
    fi
    
    log_warn "Run ./run.sh --vnc or ./run.sh --x11 to rebuild and start."
}

cleanup_profile_data() {
    log_warn "=== Cleaning up Chrome profile data ===\n"
    
    # Stop and remove containers first
    for container in "${CONTAINERS[@]}"; do
        if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
            log_warn "Stopping container: ${container}"
            docker rm -f "${container}" &>/dev/null || true
        fi
    done
    
    # Remove profile volume if it exists
    if docker volume inspect "$PROFILE_VOLUME" &>/dev/null; then
        log_warn "Removing Chrome profile volume: $PROFILE_VOLUME"
        docker volume rm "$PROFILE_VOLUME"
        log_info "\nProfile data cleanup complete!"
        log_warn "All cookies, cache, and browsing data have been removed."
    else
        log_info "Profile volume $PROFILE_VOLUME not found (already cleaned)"
    fi
}

check_xquartz() {
    if [[ ! -d "$XQUARTZ_APP" ]]; then
        log_error "XQuartz not installed"
        log_warn "Install: brew install --cask xquartz"
        exit 1
    fi
}

is_xquartz_listening() {
    netstat -an | grep -q "\.${X11_PORT}.*LISTEN"
}

setup_xquartz() {
    check_xquartz
    
    local nolisten
    nolisten=$(defaults read org.xquartz.X11 nolisten_tcp 2>/dev/null || echo "1")
    local need_restart=false
    
    if [[ "$nolisten" == "1" ]]; then
        log_warn "Enabling XQuartz TCP listening..."
        defaults write org.xquartz.X11 nolisten_tcp 0
        need_restart=true
    fi
    
    if pgrep -x "$XQUARTZ_PROCESS" &>/dev/null; then
        if ! is_xquartz_listening; then
            log_warn "XQuartz is running but not listening on TCP"
            need_restart=true
        fi
    fi
    
    if [[ "$need_restart" == true ]] && pgrep -x "$XQUARTZ_PROCESS" &>/dev/null; then
        log_warn "Restarting XQuartz..."
        pkill "$XQUARTZ_PROCESS"
        sleep 2
    fi
    
    if ! pgrep -x "$XQUARTZ_PROCESS" &>/dev/null; then
        log_info "Starting XQuartz..."
        open -a XQuartz
        sleep 3
        log_info "Waiting for XQuartz to initialize..."
        for _ in {1..10}; do
            if is_xquartz_listening; then
                break
            fi
            sleep 1
        done
    fi
    
    if ! is_xquartz_listening; then
        log_error "XQuartz is not listening on TCP port ${X11_PORT}"
        log_warn "Try manually: pkill ${XQUARTZ_PROCESS} && sleep 2 && open -a XQuartz"
        exit 1
    fi
}

get_host_ip() {
    local ip
    ip=$(ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p' | head -n1)
    if [[ -z "$ip" ]]; then
        log_error "Could not detect host IP address"
        exit 1
    fi
    echo "$ip"
}

poll_and_open_browser() {
    local port="$1"
    local max_attempts=30
    local attempt=0
    
    while ((attempt < max_attempts)); do
        if curl -s -f --connect-timeout 2 --max-time 3 "http://localhost:${port}" >/dev/null 2>&1; then
            open "http://localhost:${port}"
            return 0
        fi
        ((attempt++))
        sleep 1
    done
    
    log_warn "Service not ready after polling, opening browser anyway"
    open "http://localhost:${port}"
    return 1
}

run_x11_mode() {
    log_info "=== Chromium in Docker with X11 Forwarding ===\n"
    
    setup_xquartz
    
    local ip
    ip=$(get_host_ip)
    log_info "Configuring X11 permissions for ${ip}..."
    /opt/X11/bin/xhost + "${ip}" &>/dev/null
    
    build_image_if_needed "$DOCKERFILE_X11" "$X11_IMAGE"
    prepare_extensions_dir
    
    local -a docker_args=(
        --rm
        --init
        --shm-size=2g
        --cpus="4"
        --memory="4g"
        --name "$X11_IMAGE"
        --security-opt "seccomp=unconfined"
        -e "DISPLAY=${ip}:0"
        -v "$(pwd)/extensions:/home/chrome/extensions:ro"
        -v "$PROFILE_VOLUME:/home/chrome/.config/chromium"
        "$X11_IMAGE"
        "$CHROME_CMD"
        "$@"
    )
    
    log_info "Launching Chromium (DISPLAY=${ip}:0)\n"
    docker run -it "${docker_args[@]}"
    log_info "\nChromium stopped"
}

run_vnc_mode() {
    log_info "=== Chromium in Docker with VNC ===\n"
    
    build_image_if_needed "$DOCKERFILE_VNC" "$VNC_IMAGE"
    prepare_extensions_dir
    
    local -r port=6901
    local -r vnc_port=5900
    local -r cpu=8
    local -r memory=6g
    local -r shm=2g
    
    local -a docker_args=(
        --rm
        --init
        --shm-size="$shm"
        --cpus="$cpu"
        --memory="$memory"
        --name "$VNC_IMAGE"
        --security-opt "seccomp=unconfined"
        -p "${port}:6901"
        -p "${vnc_port}:5900"
        -v "$(pwd)/extensions:/home/chrome/extensions:ro"
        -v "$PROFILE_VOLUME:/home/chrome/.config/chromium"
        "$VNC_IMAGE"
        "$@"
    )
    
    log_info "Launching Chromium with VNC (web: http://localhost:${port})\n"
    
    # Poll localhost and open browser when ready
    poll_and_open_browser "${port}" &
    
    docker run -it "${docker_args[@]}"
    log_info "\nChromium VNC stopped"
}

show_usage() {
    log_warn "Usage: $0 --x11 [chrome args] | --vnc [chrome args] | --cleanup | --cleanup-data"
    exit 1
}

# Main script
main() {
    case "${1:-}" in
        --cleanup)
            cleanup_resources
            exit 0
            ;;
        --cleanup-data)
            cleanup_profile_data
            exit 0
            ;;
        --x11)
            shift
            build_image_if_needed "$DOCKERFILE_BASE" "$BASE_IMAGE"
            run_x11_mode "$@"
            ;;
        --vnc)
            shift
            build_image_if_needed "$DOCKERFILE_BASE" "$BASE_IMAGE"
            run_vnc_mode "$@"
            ;;
        *)
            show_usage
            ;;
    esac
}

main "$@"