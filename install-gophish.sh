#!/bin/bash
#
# GoPhish Installer - Linux Edition
# Automated deployment for Debian/Ubuntu-based systems (Pop!_OS, Ubuntu, Debian)
#
# Usage:
#   ./install-gophish.sh           # Install GoPhish
#   ./install-gophish.sh --check   # Check status only
#   ./install-gophish.sh --uninstall  # Remove GoPhish
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

GOPHISH_DIR="$HOME/gophish"
COMPOSE_FILE="$GOPHISH_DIR/docker-compose.yml"

#region Helper Functions
print_header() {
    echo -e "${CYAN}$1${NC}"
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

print_error() {
    echo -e "${RED}$1${NC}"
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root. Docker commands will use root privileges."
    fi
}
#endregion

#region Docker Installation
install_docker_if_needed() {
    print_header "\nChecking for Docker..."

    if command -v docker &> /dev/null; then
        if docker info &> /dev/null; then
            print_success "Docker is installed and running."
            return 0
        else
            print_warning "Docker is installed but not running or user lacks permissions."
            print_warning "Trying to start Docker service..."
            sudo systemctl start docker 2>/dev/null || true

            if ! docker info &> /dev/null; then
                print_warning "You may need to add yourself to the docker group:"
                echo "  sudo usermod -aG docker \$USER"
                echo "  Then log out and back in."

                # Try with sudo for now
                if sudo docker info &> /dev/null; then
                    print_warning "Docker works with sudo. Continuing with sudo..."
                    export DOCKER_CMD="sudo docker"
                    export COMPOSE_CMD="sudo docker compose"
                    return 0
                fi
                return 1
            fi
        fi
        return 0
    fi

    print_warning "Docker not found. Installing..."

    # Detect package manager
    if command -v apt &> /dev/null; then
        print_header "Installing Docker via apt..."
        sudo apt update
        sudo apt install -y docker.io docker-compose-v2
    elif command -v dnf &> /dev/null; then
        print_header "Installing Docker via dnf..."
        sudo dnf install -y docker docker-compose
    elif command -v pacman &> /dev/null; then
        print_header "Installing Docker via pacman..."
        sudo pacman -S --noconfirm docker docker-compose
    else
        print_error "ERROR: Unsupported package manager. Please install Docker manually."
        return 1
    fi

    # Enable and start Docker service
    sudo systemctl enable docker
    sudo systemctl start docker

    # Add current user to docker group
    if [[ $EUID -ne 0 ]]; then
        print_header "Adding $USER to docker group..."
        sudo usermod -aG docker "$USER"
        print_warning "NOTE: You may need to log out and back in for group changes to take effect."
        print_warning "For now, using sudo for docker commands."
        export DOCKER_CMD="sudo docker"
        export COMPOSE_CMD="sudo docker compose"
    fi

    print_success "Docker installed successfully."
    return 0
}
#endregion

#region GoPhish Deployment
create_compose_file() {
    print_header "\nCreating Docker Compose configuration..."

    mkdir -p "$GOPHISH_DIR"

    cat > "$COMPOSE_FILE" << 'EOF'
version: '3.8'
services:
  gophish:
    image: gophish/gophish
    container_name: gophish
    restart: unless-stopped
    ports:
      - "3333:3333"   # Admin UI (HTTPS)
      - "80:80"       # Phishing server (HTTP)
    volumes:
      - gophish-data:/opt/gophish/data
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 128M

volumes:
  gophish-data:
    name: gophish-data
EOF

    print_success "Docker Compose file created at: $COMPOSE_FILE"
}

pull_gophish_image() {
    print_header "\nPulling GoPhish Docker image..."

    ${DOCKER_CMD:-docker} pull gophish/gophish
    print_success "GoPhish image pulled successfully."
}

start_gophish_container() {
    print_header "\nStarting GoPhish container..."

    cd "$GOPHISH_DIR"
    ${COMPOSE_CMD:-docker compose} up -d

    print_header "Waiting for GoPhish to initialize..."
    sleep 10

    if ${DOCKER_CMD:-docker} ps --filter "name=gophish" --format "{{.Status}}" | grep -q "Up"; then
        print_success "GoPhish container is running."
        return 0
    else
        print_error "ERROR: GoPhish container is not running."
        return 1
    fi
}

get_gophish_credentials() {
    print_header "\nRetrieving GoPhish admin credentials..."

    sleep 3
    local password
    password=$(${DOCKER_CMD:-docker} logs gophish 2>&1 | grep -oP "Please login with the username admin and the password \K.*" | head -1)

    if [[ -n "$password" ]]; then
        echo "$password"
    else
        print_warning "Could not extract password from logs."
        print_warning "Run 'docker logs gophish' to find the initial password."
    fi
}

show_access_info() {
    local password="$1"

    echo ""
    print_success "==============================================="
    print_success "        GoPhish Installation Complete!         "
    print_success "==============================================="
    echo ""
    print_header "Admin Interface:"
    echo "  URL:      https://localhost:3333"
    echo "  Username: admin"
    if [[ -n "$password" ]]; then
        echo "  Password: $password"
    fi
    echo ""
    print_header "Phishing Server:"
    echo "  URL:      http://localhost:80"
    echo ""
    print_warning "IMPORTANT:"
    print_warning "  - Change the admin password immediately after first login"
    print_warning "  - Only use for authorized security awareness testing"
    print_warning "  - Campaign data contains sensitive employee info"
    echo ""
    print_header "Quick Commands:"
    echo "  Status:    ./install-gophish.sh --check"
    echo "  Uninstall: ./install-gophish.sh --uninstall"
    echo "  Logs:      docker logs gophish"
    print_success "==============================================="
}
#endregion

#region Status Check
show_status() {
    print_header "\nGoPhish Status"
    print_header "=============="

    # Check Docker
    if ! ${DOCKER_CMD:-docker} info &> /dev/null; then
        print_error "Docker: NOT RUNNING"
        return 1
    fi
    print_success "Docker: Running"

    # Check container
    local status
    status=$(${DOCKER_CMD:-docker} ps --filter "name=gophish" --format "{{.Status}}" 2>/dev/null)
    if [[ "$status" == *"Up"* ]]; then
        print_success "Container: $status"
    elif [[ -n "$status" ]]; then
        print_warning "Container: $status"
    else
        print_error "Container: Not found"
        return 1
    fi

    # Check volume
    if ${DOCKER_CMD:-docker} volume inspect gophish-data &> /dev/null; then
        print_success "Data Volume: gophish-data"
    fi

    # Check ports
    local ports
    ports=$(${DOCKER_CMD:-docker} port gophish 2>/dev/null)
    if [[ -n "$ports" ]]; then
        print_header "Ports:"
        echo "$ports" | while read -r line; do
            echo "  $line"
        done
    fi

    echo ""
    print_header "Admin UI:     https://localhost:3333"
    print_header "Phish Server: http://localhost:80"
}
#endregion

#region Uninstall
uninstall_gophish() {
    print_header "\nUninstalling GoPhish..."

    # Check if container exists
    if ${DOCKER_CMD:-docker} ps -a --filter "name=gophish" --format "{{.Names}}" | grep -q "gophish"; then
        print_warning "Stopping and removing GoPhish container..."
        ${DOCKER_CMD:-docker} stop gophish 2>/dev/null || true
        ${DOCKER_CMD:-docker} rm gophish 2>/dev/null || true
        print_success "Container removed."
    else
        echo "No GoPhish container found."
    fi

    # Ask about volumes
    if ${DOCKER_CMD:-docker} volume ls --filter "name=gophish-data" --format "{{.Name}}" | grep -q "gophish-data"; then
        echo ""
        print_warning "WARNING: The data volume contains campaign data and database."
        read -p "Remove data volume? This will DELETE ALL DATA (y/N): " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            ${DOCKER_CMD:-docker} volume rm gophish-data 2>/dev/null || true
            print_success "Data volume removed."
        else
            print_header "Data volume preserved."
        fi
    fi

    # Remove compose file
    if [[ -f "$COMPOSE_FILE" ]]; then
        rm -f "$COMPOSE_FILE"
        print_success "Compose file removed."
    fi

    # Remove directory if empty
    if [[ -d "$GOPHISH_DIR" ]] && [[ -z "$(ls -A "$GOPHISH_DIR")" ]]; then
        rmdir "$GOPHISH_DIR"
    fi

    print_success "\nGoPhish uninstalled."
}
#endregion

#region Main
main() {
    echo ""
    print_header "GoPhish Installer - Linux Edition"
    print_header "================================="

    check_root

    case "${1:-}" in
        --check|-c)
            show_status
            exit 0
            ;;
        --uninstall|-u)
            uninstall_gophish
            exit 0
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --check, -c      Show GoPhish status"
            echo "  --uninstall, -u  Remove GoPhish"
            echo "  --help, -h       Show this help message"
            echo ""
            echo "Without options, installs GoPhish."
            exit 0
            ;;
    esac

    # Main installation flow
    if ! install_docker_if_needed; then
        print_error "\nERROR: Docker installation failed. Cannot continue."
        exit 1
    fi

    pull_gophish_image

    create_compose_file

    if ! start_gophish_container; then
        print_error "\nERROR: Failed to start GoPhish container."
        exit 1
    fi

    local password
    password=$(get_gophish_credentials)
    show_access_info "$password"
}

main "$@"
#endregion
