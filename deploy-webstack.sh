#!/bin/bash

# Web Stack Deployment Script
# Compatible with your existing ans-hard project structure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY_FILE="${SCRIPT_DIR}/inventory.ini"
VAULT_FILE="${SCRIPT_DIR}/group_vars/all/vault.yml"
PLAYBOOK_FILE="${SCRIPT_DIR}/web-stack.yml"

# Functions
print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE} Web Stack Deployment for ans-hard Project${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo
}

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    print_status "Checking dependencies..."
    
    if ! command -v ansible-playbook &> /dev/null; then
        print_error "Ansible is not installed. Please install ansible first."
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        print_warning "Docker not found locally. It will be installed on target servers."
    fi
    
    if [[ ! -f "$INVENTORY_FILE" ]]; then
        print_error "Inventory file not found: $INVENTORY_FILE"
        exit 1
    fi
    
    if [[ ! -f "$VAULT_FILE" ]]; then
        print_error "Vault file not found: $VAULT_FILE"
        print_status "Please run: ansible-vault create $VAULT_FILE"
        exit 1
    fi
    
    print_status "Dependencies check passed."
}

show_menu() {
    echo
    echo "Deployment Options:"
    echo "1. Deploy full web stack (Docker + Traefik + Nginx)"
    echo "2. Deploy Docker only"
    echo "3. Deploy Traefik + Nginx (requires Docker)"
    echo "4. Update existing deployment"
    echo "5. Check deployment status"
    echo "6. Configure header mode"
    echo "7. Show deployment info"
    echo "8. Remove web stack"
    echo "9. Exit"
    echo
}

deploy_full_stack() {
    print_status "Deploying full web stack..."
    ansible-playbook -i "$INVENTORY_FILE" "$PLAYBOOK_FILE" \
        --ask-vault-pass \
        --extra-vars "install_docker=true install_docker_compose=true install_traefik=true install_nginx=true" \
        "$@"
}

deploy_docker_only() {
    print_status "Deploying Docker only..."
    ansible-playbook -i "$INVENTORY_FILE" "$PLAYBOOK_FILE" \
        --ask-vault-pass \
        --extra-vars "install_docker=true install_docker_compose=true install_traefik=false install_nginx=false" \
        --tags "docker" \
        "$@"
}

deploy_web_services() {
    print_status "Deploying Traefik + Nginx..."
    ansible-playbook -i "$INVENTORY_FILE" "$PLAYBOOK_FILE" \
        --ask-vault-pass \
        --extra-vars "install_docker=false install_docker_compose=false install_traefik=true install_nginx=true" \
        --tags "traefik,nginx,compose" \
        "$@"
}

update_deployment() {
    print_status "Updating existing deployment..."
    ansible-playbook -i "$INVENTORY_FILE" "$PLAYBOOK_FILE" \
        --ask-vault-pass \
        --tags "config,compose" \
        "$@"
}

check_status() {
    print_status "Checking deployment status..."
    ansible webservers -i "$INVENTORY_FILE" \
        --ask-vault-pass \
        -m shell \
        -a "docker-compose -f /opt/web-stack/docker-compose.yml ps && systemctl status web-stack"
}

configure_headers() {
    echo
    echo "Header Configuration Modes:"
    echo "1. Traefik headers (security-focused, reveals Traefik)"
    echo "2. Nginx headers (reveals Nginx server)"
    echo "3. Custom headers (stealth mode - mimic other servers)"
    echo
    read -p "Select header mode (1-3): " header_choice
    
    case $header_choice in
        1)
            HEADER_MODE="traefik"
            print_status "Configuring Traefik security headers..."
            ;;
        2)
            HEADER_MODE="nginx"
            print_status "Configuring Nginx passthrough headers..."
            ;;
        3)
            HEADER_MODE="custom"
            print_status "Configuring custom stealth headers..."
            echo
            read -p "Enter custom Server header (default: Apache/2.4.41): " custom_server
            read -p "Enter custom X-Powered-By (default: PHP/8.1.0): " custom_powered
            read -p "Enter custom framework (default: Laravel/9.0): " custom_framework
            
            EXTRA_VARS="custom_server_header=${custom_server:-Apache/2.4.41}"
            EXTRA_VARS="$EXTRA_VARS custom_powered_by=${custom_powered:-PHP/8.1.0}"
            EXTRA_VARS="$EXTRA_VARS custom_framework=${custom_framework:-Laravel/9.0}"
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
    
    print_status "Applying header configuration..."
    ansible-playbook -i "$INVENTORY_FILE" "$PLAYBOOK_FILE" \
        --ask-vault-pass \
        --extra-vars "header_mode=$HEADER_MODE $EXTRA_VARS" \
        --tags "config,compose"
}

show_deployment_info() {
    print_status "Deployment Information:"
    echo
    ansible webservers -i "$INVENTORY_FILE" \
        --ask-vault-pass \
        -m shell \
        -a "echo 'Host: $(hostname)' && echo 'Services:' && docker-compose -f /opt/web-stack/docker-compose.yml ps --format table && echo && echo 'Ports:' && ss -tlnp | grep -E ':(80|443|8080)'"
}

remove_web_stack() {
    print_warning "This will remove the entire web stack deployment!"
    read -p "Are you sure? (y/N): " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        print_status "Removing web stack..."
        ansible webservers -i "$INVENTORY_FILE" \
            --ask-vault-pass \
            -m shell \
            -a "cd /opt/web-stack && docker-compose down -v && sudo systemctl stop web-stack && sudo systemctl disable web-stack"
        
        ansible webservers -i "$INVENTORY_FILE" \
            --ask-vault-pass \
            -m file \
            -a "path=/opt/web-stack state=absent" \
            --become
        
        print_status "Web stack removed successfully."
    else
        print_status "Removal cancelled."
    fi
}

# Main script
main() {
    print_header
    check_dependencies
    
    if [[ $# -gt 0 ]]; then
        # Handle command line arguments
        case "$1" in
            "full"|"deploy")
                deploy_full_stack "${@:2}"
                ;;
            "docker")
                deploy_docker_only "${@:2}"
                ;;
            "web")
                deploy_web_services "${@:2}"
                ;;
            "update")
                update_deployment "${@:2}"
                ;;
            "status")
                check_status
                ;;
            "headers")
                configure_headers
                ;;
            "info")
                show_deployment_info
                ;;
            "remove")
                remove_web_stack
                ;;
            *)
                echo "Usage: $0 {full|docker|web|update|status|headers|info|remove}"
                echo "   or run without arguments for interactive mode"
                exit 1
                ;;
        esac
        exit 0
    fi
    
    # Interactive mode
    while true; do
        show_menu
        read -p "Enter your choice (1-9): " choice
        
        case $choice in
            1)
                deploy_full_stack
                ;;
            2)
                deploy_docker_only
                ;;
            3)
                deploy_web_services
                ;;
            4)
                update_deployment
                ;;
            5)
                check_status
                ;;
            6)
                configure_headers
                ;;
            7)
                show_deployment_info
                ;;
            8)
                remove_web_stack
                ;;
            9)
                print_status "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid choice. Please enter 1-9."
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Run main function
main "$@"
