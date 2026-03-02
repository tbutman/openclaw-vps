#!/usr/bin/env bash
# ============================================
# OpenClaw Tools CLI
# ============================================
# Convenient wrapper for common OpenClaw operations
# Install to: /usr/local/bin/tools
# Usage: tools [command] [args...]
# ============================================

set -euo pipefail

COMPOSE_FILE="$HOME/openclaw-vps/docker/docker-compose.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_error() {
    echo -e "${RED}Error: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_info() {
    echo -e "${BLUE}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

# Help text
show_help() {
    cat <<EOF
OpenClaw Tools CLI - Convenient wrapper for common operations

Usage:
  tools <command> [args...]

Commands:
  OpenClaw Management:
    openclaw <cmd>          Run openclaw CLI commands
                            → docker compose -f ~/openclaw-vps/docker/docker-compose.yml exec openclaw openclaw <cmd>
                            Examples: status, pairing list, security audit

    openclaw logs           View openclaw logs (follow mode)
                            → docker compose -f ~/openclaw-vps/docker/docker-compose.yml logs -f openclaw

    openclaw logs-all       View all container logs
                            → docker compose -f ~/openclaw-vps/docker/docker-compose.yml logs -f

    openclaw restart        Restart openclaw container
                            → docker compose -f ~/openclaw-vps/docker/docker-compose.yml restart openclaw

    openclaw shell          Open bash shell in openclaw container
                            → docker compose -f ~/openclaw-vps/docker/docker-compose.yml exec openclaw bash

  Docker Management:
    docker ps               List running containers
                            → docker compose -f ~/openclaw-vps/docker/docker-compose.yml ps

    docker logs <service>   View logs for specific service (openclaw/chromium)
                            → docker compose -f ~/openclaw-vps/docker/docker-compose.yml logs -f <service>

    docker restart          Restart all containers
                            → docker compose -f ~/openclaw-vps/docker/docker-compose.yml restart

    docker restart <svc>    Restart specific service
                            → docker compose -f ~/openclaw-vps/docker/docker-compose.yml restart <svc>

    docker stop             Stop all containers
                            → docker compose -f ~/openclaw-vps/docker/docker-compose.yml down

    docker start            Start all containers
                            → docker compose -f ~/openclaw-vps/docker/docker-compose.yml up -d

    docker rebuild          Rebuild and restart containers
                            → docker compose build --no-cache && docker compose up -d

    docker status           Show detailed container status
                            → docker compose -f ~/openclaw-vps/docker/docker-compose.yml ps

  Tailscale:
    tailscale status        Show Tailscale connection status
                            → docker compose -f ~/openclaw-vps/docker/docker-compose.yml exec openclaw tailscale status

    tailscale url           Show Tailscale Control UI URL
                            → Extracts hostname from tailscale status --json

  Slack:
    slack list users        List approved Slack users
                            → Shows paired Slack user IDs from credentials

    slack list channels     List configured Slack channels
                            → Extracts channels from config

    slack list pairings     List pending pairing requests
                            → docker compose exec openclaw openclaw pairing list

    slack add user <id>     Add Slack user ID to allowFrom
                            → Manually approve a Slack user by ID

    slack add channel <id>  Add a Slack channel to allowFrom
                            → Adds channel ID to config and restarts

    slack remove user <id>  Remove Slack user ID from allowFrom
                            → Revoke access for a Slack user

    slack remove channel <id>
                            Remove a Slack channel from allowFrom
                            → Removes channel ID from config and restarts

    slack approve <code>    Approve a Slack pairing request
                            → docker compose exec openclaw openclaw pairing approve slack <code>

  Tailscale:
    tailscale status        Show Tailscale connection status
                            → docker compose exec openclaw tailscale status

    tailscale url           Show Tailscale Control UI URL
                            → Extracts hostname from tailscale status --json

    tailscale list users    List allowed users for Tailscale auth
                            → Extracts gateway.auth.trustedProxy.allowUsers

    tailscale add user <email>
                            Add user email to allowUsers list
                            → Adds email to config and restarts

    tailscale remove user <email>
                            Remove user email from allowUsers list
                            → Removes email from config and restarts

  Maintenance:
    backup                  Create encrypted backup
                            → bash ~/openclaw-vps/scripts/backup.sh

    restore <file>          Restore from encrypted backup
                            → bash ~/openclaw-vps/scripts/restore.sh <file>

    update                  Pull latest code and rebuild
                            → git pull && docker compose build --no-cache && docker compose up -d

    security                Run security audit
                            → docker compose exec openclaw openclaw security audit

    fix-permissions         Fix state directory permissions
                            → chmod 700 ~/.openclaw && chown -R openclaw:openclaw ~/.openclaw

  Configuration:
    config view             Show current OpenClaw config
                            → cat ~/.openclaw/openclaw.json

    config edit             Edit config in nano
                            → nano ~/.openclaw/openclaw.json

    config sync             Sync config from latest template (backs up current config)
                            → Merges template with current config using jq

  System Info:
    status                  Show overall system status (containers, Tailscale, disk, memory)
    health                  Check health of all services

  Help:
    help, --help, -h        Show this help message

Examples:
  tools openclaw status
  tools openclaw pairing approve slack ABC123
  tools docker logs openclaw
  tools tailscale status
  tools backup
  tools status

Note: All commands use the compose file at ~/openclaw-vps/docker/docker-compose.yml

EOF
}

# Main command router
main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    case "$1" in
        # OpenClaw commands
        openclaw)
            shift
            if [ $# -eq 0 ]; then
                print_error "Missing openclaw command"
                echo "Usage: tools openclaw <command>"
                exit 1
            fi

            case "$1" in
                logs)
                    print_info "Viewing OpenClaw logs (Ctrl+C to exit)..."
                    docker compose -f "$COMPOSE_FILE" logs -f openclaw
                    ;;
                logs-all)
                    print_info "Viewing all container logs (Ctrl+C to exit)..."
                    docker compose -f "$COMPOSE_FILE" logs -f
                    ;;
                restart)
                    print_info "Restarting OpenClaw container..."
                    docker compose -f "$COMPOSE_FILE" restart openclaw
                    print_success "OpenClaw restarted"
                    ;;
                shell)
                    print_info "Opening shell in OpenClaw container..."
                    docker compose -f "$COMPOSE_FILE" exec openclaw bash
                    ;;
                *)
                    # Pass through to openclaw CLI
                    docker compose -f "$COMPOSE_FILE" exec openclaw openclaw "$@"
                    ;;
            esac
            ;;

        # Docker commands
        docker)
            shift
            if [ $# -eq 0 ]; then
                print_error "Missing docker command"
                echo "Usage: tools docker <command>"
                exit 1
            fi

            case "$1" in
                ps)
                    docker compose -f "$COMPOSE_FILE" ps
                    ;;
                logs)
                    shift
                    if [ $# -eq 0 ]; then
                        docker compose -f "$COMPOSE_FILE" logs -f
                    else
                        docker compose -f "$COMPOSE_FILE" logs -f "$1"
                    fi
                    ;;
                restart)
                    shift
                    if [ $# -eq 0 ]; then
                        print_info "Restarting all containers..."
                        docker compose -f "$COMPOSE_FILE" restart
                        print_success "All containers restarted"
                    else
                        print_info "Restarting $1..."
                        docker compose -f "$COMPOSE_FILE" restart "$1"
                        print_success "$1 restarted"
                    fi
                    ;;
                stop)
                    print_info "Stopping all containers..."
                    docker compose -f "$COMPOSE_FILE" down
                    print_success "All containers stopped"
                    ;;
                start)
                    print_info "Starting all containers..."
                    docker compose -f "$COMPOSE_FILE" up -d
                    print_success "All containers started"
                    ;;
                rebuild)
                    print_info "Rebuilding and restarting containers..."
                    cd "$HOME/openclaw-vps/docker"
                    docker compose build --no-cache
                    docker compose up -d
                    print_success "Containers rebuilt and started"
                    ;;
                status)
                    print_info "Container Status:"
                    docker compose -f "$COMPOSE_FILE" ps
                    ;;
                *)
                    print_error "Unknown docker command: $1"
                    echo "Run 'tools help' for usage"
                    exit 1
                    ;;
            esac
            ;;

        # Tailscale commands
        tailscale)
            shift
            if [ $# -eq 0 ]; then
                print_error "Missing tailscale command"
                echo "Usage: tools tailscale <status|url|list|add|remove>"
                exit 1
            fi

            case "$1" in
                status)
                    docker compose -f "$COMPOSE_FILE" exec openclaw tailscale status
                    ;;
                url)
                    HOSTNAME=$(docker compose -f "$COMPOSE_FILE" exec -T openclaw tailscale status --json 2>/dev/null | grep -o '"HostName":"[^"]*"' | cut -d'"' -f4)
                    TAILNET=$(docker compose -f "$COMPOSE_FILE" exec -T openclaw tailscale status --json 2>/dev/null | grep -o '"MagicDNSSuffix":"[^"]*"' | cut -d'"' -f4)
                    print_success "Control UI URL: https://${HOSTNAME}.${TAILNET}"
                    ;;
                list)
                    shift
                    if [ $# -eq 0 ] || [ "$1" != "users" ]; then
                        print_error "Usage: tools tailscale list users"
                        exit 1
                    fi
                    print_info "Allowed users for Tailscale authentication:"
                    if command -v jq &> /dev/null; then
                        USERS=$(jq -r '.gateway.auth.trustedProxy.allowUsers[]? // empty' "$HOME/.openclaw/openclaw.json")
                        if [ -z "$USERS" ]; then
                            print_warning "No users configured (all authenticated Tailscale users allowed)"
                        else
                            echo "$USERS" | while read user; do
                                echo "  - $user"
                            done
                        fi
                    else
                        grep -A 5 '"allowUsers"' "$HOME/.openclaw/openclaw.json" || print_warning "allowUsers not configured"
                    fi
                    ;;
                add)
                    shift
                    if [ $# -eq 0 ] || [ "$1" != "user" ]; then
                        print_error "Usage: tools tailscale add user <email>"
                        exit 1
                    fi
                    shift
                    if [ $# -eq 0 ]; then
                        print_error "Missing user email"
                        echo "Example: tools tailscale add user nick@example.com"
                        exit 1
                    fi

                    USER_EMAIL="$1"

                    if ! command -v jq &> /dev/null; then
                        print_error "jq is required but not installed"
                        echo "Install with: sudo apt install jq"
                        exit 1
                    fi

                    print_info "Adding user $USER_EMAIL to allowUsers list..."
                    cp "$HOME/.openclaw/openclaw.json" "$HOME/.openclaw/openclaw.json.backup"

                    jq --arg user "$USER_EMAIL" \
                        'if .gateway.auth.trustedProxy.allowUsers == null then
                           .gateway.auth.trustedProxy.allowUsers = []
                         else . end |
                         if (.gateway.auth.trustedProxy.allowUsers | index($user)) then .
                         else .gateway.auth.trustedProxy.allowUsers += [$user] end' \
                        "$HOME/.openclaw/openclaw.json" > "$HOME/.openclaw/openclaw.json.tmp"
                    mv "$HOME/.openclaw/openclaw.json.tmp" "$HOME/.openclaw/openclaw.json"

                    docker compose -f "$COMPOSE_FILE" restart openclaw

                    print_success "User $USER_EMAIL added successfully!"
                    print_warning "Note: User must authenticate via Tailscale with this email"
                    ;;
                remove)
                    shift
                    if [ $# -eq 0 ] || [ "$1" != "user" ]; then
                        print_error "Usage: tools tailscale remove user <email>"
                        exit 1
                    fi
                    shift
                    if [ $# -eq 0 ]; then
                        print_error "Missing user email"
                        exit 1
                    fi

                    USER_EMAIL="$1"

                    if ! command -v jq &> /dev/null; then
                        print_error "jq is required but not installed"
                        exit 1
                    fi

                    print_info "Removing user $USER_EMAIL from allowUsers list..."
                    cp "$HOME/.openclaw/openclaw.json" "$HOME/.openclaw/openclaw.json.backup"

                    jq --arg user "$USER_EMAIL" \
                        '.gateway.auth.trustedProxy.allowUsers = (.gateway.auth.trustedProxy.allowUsers // [] | map(select(. != $user)))' \
                        "$HOME/.openclaw/openclaw.json" > "$HOME/.openclaw/openclaw.json.tmp"
                    mv "$HOME/.openclaw/openclaw.json.tmp" "$HOME/.openclaw/openclaw.json"

                    docker compose -f "$COMPOSE_FILE" restart openclaw

                    print_success "User $USER_EMAIL removed successfully!"
                    print_warning "Note: If allowUsers is now empty, all authenticated Tailscale users will be allowed"
                    ;;
                *)
                    print_error "Unknown tailscale command: $1"
                    echo "Available: status, url, list users, add user <email>, remove user <email>"
                    exit 1
                    ;;
            esac
            ;;

        # Slack commands
        slack)
            shift
            if [ $# -eq 0 ]; then
                print_error "Missing slack command"
                echo "Usage: tools slack <pairing|channel|user>"
                exit 1
            fi

            case "$1" in
                pairing)
                    shift
                    if [ $# -eq 0 ]; then
                        print_error "Missing pairing command"
                        echo "Usage: tools slack pairing <list|approve>"
                        exit 1
                    fi

                    case "$1" in
                        list)
                            docker compose -f "$COMPOSE_FILE" exec openclaw openclaw pairing list
                            ;;
                        approve)
                            shift
                            if [ $# -eq 0 ]; then
                                print_error "Missing pairing code"
                                echo "Usage: tools slack pairing approve <code>"
                                exit 1
                            fi
                            docker compose -f "$COMPOSE_FILE" exec openclaw openclaw pairing approve slack "$1"
                            ;;
                        *)
                            print_error "Unknown pairing command: $1"
                            echo "Available: list, approve <code>"
                            exit 1
                            ;;
                    esac
                    ;;

                channel)
                    shift
                    if [ $# -eq 0 ]; then
                        print_error "Missing channel command"
                        echo "Usage: tools slack channel <list|add|remove>"
                        exit 1
                    fi

                    case "$1" in
                        list)
                            print_info "Configured Slack channels:"
                            if command -v jq &> /dev/null; then
                                jq -r '.channels.slack.allowFrom[]? // empty' "$HOME/.openclaw/openclaw.json" | while read channel; do
                                    echo "  - $channel"
                                done
                                echo ""
                                print_info "Channel details:"
                                jq '.channels.slack.channels // {}' "$HOME/.openclaw/openclaw.json"
                            else
                                grep -A 5 '"allowFrom"' "$HOME/.openclaw/openclaw.json"
                            fi
                            ;;

                        add)
                            shift
                            if [ $# -eq 0 ]; then
                                print_error "Missing channel ID"
                                echo "Usage: tools slack channel add <channel-id>"
                                echo "Example: tools slack channel add C12345678"
                                exit 1
                            fi

                            CHANNEL_ID="$1"

                            # Check if jq is installed
                            if ! command -v jq &> /dev/null; then
                                print_error "jq is required but not installed"
                                echo "Install with: sudo apt install jq"
                                exit 1
                            fi

                            print_info "Adding channel $CHANNEL_ID to allowFrom list..."

                            # Backup config
                            cp "$HOME/.openclaw/openclaw.json" "$HOME/.openclaw/openclaw.json.backup"

                            # Add channel to allowFrom array if not already present
                            jq --arg channel "$CHANNEL_ID" \
                                'if (.channels.slack.allowFrom | index($channel)) then .
                                 else .channels.slack.allowFrom += [$channel] end' \
                                "$HOME/.openclaw/openclaw.json" > "$HOME/.openclaw/openclaw.json.tmp"
                            mv "$HOME/.openclaw/openclaw.json.tmp" "$HOME/.openclaw/openclaw.json"

                            print_info "Restarting OpenClaw..."
                            docker compose -f "$COMPOSE_FILE" restart openclaw

                            print_success "Channel $CHANNEL_ID added successfully!"
                            print_info "Backup saved to: ~/.openclaw/openclaw.json.backup"
                            ;;

                        remove)
                            shift
                            if [ $# -eq 0 ]; then
                                print_error "Missing channel ID"
                                echo "Usage: tools slack channel remove <channel-id>"
                                exit 1
                            fi

                            CHANNEL_ID="$1"

                            if ! command -v jq &> /dev/null; then
                                print_error "jq is required but not installed"
                                echo "Install with: sudo apt install jq"
                                exit 1
                            fi

                            print_info "Removing channel $CHANNEL_ID from allowFrom list..."

                            # Backup config
                            cp "$HOME/.openclaw/openclaw.json" "$HOME/.openclaw/openclaw.json.backup"

                            # Remove channel from allowFrom array
                            jq --arg channel "$CHANNEL_ID" \
                                '.channels.slack.allowFrom = (.channels.slack.allowFrom // [] | map(select(. != $channel)))' \
                                "$HOME/.openclaw/openclaw.json" > "$HOME/.openclaw/openclaw.json.tmp"
                            mv "$HOME/.openclaw/openclaw.json.tmp" "$HOME/.openclaw/openclaw.json"

                            print_info "Restarting OpenClaw..."
                            docker compose -f "$COMPOSE_FILE" restart openclaw

                            print_success "Channel $CHANNEL_ID removed successfully!"
                            print_info "Backup saved to: ~/.openclaw/openclaw.json.backup"
                            ;;

                        *)
                            print_error "Unknown channel command: $1"
                            echo "Available: list, add <channel-id>, remove <channel-id>"
                            exit 1
                            ;;
                    esac
                    ;;

                user)
                    shift
                    if [ $# -eq 0 ]; then
                        print_error "Missing user command"
                        echo "Usage: tools slack user <list|add|remove>"
                        exit 1
                    fi

                    case "$1" in
                        list)
                            print_info "Approved Slack users:"
                            if [ -f "$HOME/.openclaw/credentials/slack-pairing.json" ]; then
                                if command -v jq &> /dev/null; then
                                    jq -r '.allowFrom[]? // empty' "$HOME/.openclaw/credentials/slack-pairing.json" | while read user; do
                                        echo "  - $user"
                                    done
                                else
                                    cat "$HOME/.openclaw/credentials/slack-pairing.json"
                                fi
                            else
                                print_warning "No paired users found"
                            fi
                            ;;

                        add)
                            shift
                            if [ $# -eq 0 ]; then
                                print_error "Missing Slack user ID"
                                echo "Usage: tools slack user add <user-id>"
                                echo "Example: tools slack user add U12345678"
                                exit 1
                            fi

                            USER_ID="$1"

                            # Check if jq is installed
                            if ! command -v jq &> /dev/null; then
                                print_error "jq is required but not installed"
                                echo "Install with: sudo apt install jq"
                                exit 1
                            fi

                            print_info "Adding Slack user $USER_ID..."

                            # Ensure credentials directory exists
                            mkdir -p "$HOME/.openclaw/credentials"

                            # Create or update slack-pairing.json
                            if [ -f "$HOME/.openclaw/credentials/slack-pairing.json" ]; then
                                jq --arg user "$USER_ID" \
                                    'if (.allowFrom | index($user)) then .
                                     else .allowFrom += [$user] end' \
                                    "$HOME/.openclaw/credentials/slack-pairing.json" > "$HOME/.openclaw/credentials/slack-pairing.json.tmp"
                                mv "$HOME/.openclaw/credentials/slack-pairing.json.tmp" "$HOME/.openclaw/credentials/slack-pairing.json"
                            else
                                echo "{\"allowFrom\": [\"$USER_ID\"]}" | jq . > "$HOME/.openclaw/credentials/slack-pairing.json"
                            fi

                            chmod 600 "$HOME/.openclaw/credentials/slack-pairing.json"

                            print_info "Restarting OpenClaw..."
                            docker compose -f "$COMPOSE_FILE" restart openclaw

                            print_success "Slack user $USER_ID added successfully!"
                            ;;

                        remove)
                            shift
                            if [ $# -eq 0 ]; then
                                print_error "Missing Slack user ID"
                                echo "Usage: tools slack user remove <user-id>"
                                exit 1
                            fi

                            USER_ID="$1"

                            if ! command -v jq &> /dev/null; then
                                print_error "jq is required but not installed"
                                echo "Install with: sudo apt install jq"
                                exit 1
                            fi

                            if [ ! -f "$HOME/.openclaw/credentials/slack-pairing.json" ]; then
                                print_error "No slack-pairing.json file found"
                                exit 1
                            fi

                            print_info "Removing Slack user $USER_ID..."

                            jq --arg user "$USER_ID" \
                                '.allowFrom = (.allowFrom // [] | map(select(. != $user)))' \
                                "$HOME/.openclaw/credentials/slack-pairing.json" > "$HOME/.openclaw/credentials/slack-pairing.json.tmp"
                            mv "$HOME/.openclaw/credentials/slack-pairing.json.tmp" "$HOME/.openclaw/credentials/slack-pairing.json"

                            print_info "Restarting OpenClaw..."
                            docker compose -f "$COMPOSE_FILE" restart openclaw

                            print_success "Slack user $USER_ID removed successfully!"
                            ;;

                        *)
                            print_error "Unknown user command: $1"
                            echo "Available: list, add <user-id>, remove <user-id>"
                            exit 1
                            ;;
                    esac
                    ;;

                *)
                    print_error "Unknown slack command: $1"
                    echo "Available: pairing, add-channel, list-channels, user"
                    exit 1
                    ;;
            esac
            ;;

        # User commands
        user)
            shift
            if [ $# -eq 0 ]; then
                print_error "Missing user command"
                echo "Usage: tools user <list|add>"
                exit 1
            fi

            case "$1" in
                list)
                    print_info "Allowed users for Tailscale authentication:"
                    if command -v jq &> /dev/null; then
                        USERS=$(jq -r '.gateway.auth.trustedProxy.allowUsers[]? // empty' "$HOME/.openclaw/openclaw.json")
                        if [ -z "$USERS" ]; then
                            print_warning "No users configured (all authenticated Tailscale users allowed)"
                        else
                            echo "$USERS" | while read user; do
                                echo "  - $user"
                            done
                        fi
                    else
                        grep -A 5 '"allowUsers"' "$HOME/.openclaw/openclaw.json" || print_warning "allowUsers not configured"
                    fi
                    ;;

                add)
                    shift
                    if [ $# -eq 0 ]; then
                        print_error "Missing user email"
                        echo "Usage: tools user add <email>"
                        echo "Example: tools user add nick@example.com"
                        exit 1
                    fi

                    USER_EMAIL="$1"

                    # Check if jq is installed
                    if ! command -v jq &> /dev/null; then
                        print_error "jq is required but not installed"
                        echo "Install with: sudo apt install jq"
                        exit 1
                    fi

                    print_info "Adding user $USER_EMAIL to allowUsers list..."

                    # Backup config
                    cp "$HOME/.openclaw/openclaw.json" "$HOME/.openclaw/openclaw.json.backup"

                    # Ensure allowUsers array exists, then add user if not already present
                    jq --arg user "$USER_EMAIL" \
                        'if .gateway.auth.trustedProxy.allowUsers == null then
                           .gateway.auth.trustedProxy.allowUsers = []
                         else . end |
                         if (.gateway.auth.trustedProxy.allowUsers | index($user)) then .
                         else .gateway.auth.trustedProxy.allowUsers += [$user] end' \
                        "$HOME/.openclaw/openclaw.json" > "$HOME/.openclaw/openclaw.json.tmp"
                    mv "$HOME/.openclaw/openclaw.json.tmp" "$HOME/.openclaw/openclaw.json"

                    print_info "Restarting OpenClaw..."
                    docker compose -f "$COMPOSE_FILE" restart openclaw

                    print_success "User $USER_EMAIL added successfully!"
                    print_info "Backup saved to: ~/.openclaw/openclaw.json.backup"
                    print_warning "Note: User must authenticate via Tailscale with this email"
                    ;;

                remove)
                    shift
                    if [ $# -eq 0 ]; then
                        print_error "Missing user email"
                        echo "Usage: tools user remove <email>"
                        echo "Example: tools user remove nick@example.com"
                        exit 1
                    fi

                    USER_EMAIL="$1"

                    # Check if jq is installed
                    if ! command -v jq &> /dev/null; then
                        print_error "jq is required but not installed"
                        echo "Install with: sudo apt install jq"
                        exit 1
                    fi

                    print_info "Removing user $USER_EMAIL from allowUsers list..."

                    # Backup config
                    cp "$HOME/.openclaw/openclaw.json" "$HOME/.openclaw/openclaw.json.backup"

                    # Remove user from allowUsers array
                    jq --arg user "$USER_EMAIL" \
                        '.gateway.auth.trustedProxy.allowUsers = (.gateway.auth.trustedProxy.allowUsers // [] | map(select(. != $user)))' \
                        "$HOME/.openclaw/openclaw.json" > "$HOME/.openclaw/openclaw.json.tmp"
                    mv "$HOME/.openclaw/openclaw.json.tmp" "$HOME/.openclaw/openclaw.json"

                    print_info "Restarting OpenClaw..."
                    docker compose -f "$COMPOSE_FILE" restart openclaw

                    print_success "User $USER_EMAIL removed successfully!"
                    print_info "Backup saved to: ~/.openclaw/openclaw.json.backup"
                    print_warning "Note: If allowUsers is now empty, all authenticated Tailscale users will be allowed"
                    ;;

                *)
                    print_error "Unknown user command: $1"
                    echo "Available: list, add <email>, remove <email>"
                    exit 1
                    ;;
            esac
            ;;

        # Maintenance commands
        backup)
            bash "$HOME/openclaw-vps/scripts/backup.sh"
            ;;

        restore)
            shift
            if [ $# -eq 0 ]; then
                print_error "Missing backup file path"
                echo "Usage: tools restore <backup-file>"
                exit 1
            fi
            bash "$HOME/openclaw-vps/scripts/restore.sh" "$1"
            ;;

        update)
            print_info "Pulling latest code..."
            cd "$HOME/openclaw-vps"
            git pull
            print_info "Rebuilding containers..."
            cd docker
            docker compose build --no-cache
            docker compose up -d
            print_success "Update complete"
            ;;

        security)
            docker compose -f "$COMPOSE_FILE" exec openclaw openclaw security audit
            ;;

        fix-permissions)
            print_info "Fixing state directory permissions..."
            chmod 700 "$HOME/.openclaw"
            sudo chown -R openclaw:openclaw "$HOME/.openclaw"
            print_success "Permissions fixed"
            ;;

        # Configuration commands
        config)
            shift
            if [ $# -eq 0 ]; then
                print_error "Missing config command"
                echo "Usage: tools config <view|edit|sync>"
                exit 1
            fi

            case "$1" in
                view)
                    cat "$HOME/.openclaw/openclaw.json"
                    ;;
                edit)
                    print_info "Opening config in nano..."
                    print_warning "Remember to restart the openclaw container after making changes: tools openclaw restart"
                    nano "$HOME/.openclaw/openclaw.json"
                    ;;
                sync)
                    # Check if jq is installed
                    if ! command -v jq &> /dev/null; then
                        print_error "jq is required for config sync but not installed"
                        echo "Install with: sudo apt install jq"
                        exit 1
                    fi

                    print_info "This will merge the latest template with your current config."
                    print_info "Your customizations (tokens, channels, etc.) will be preserved."
                    print_warning "New fields from template will be added, removed fields will be deleted."
                    read -p "Continue? (y/N): " -n 1 -r
                    echo
                    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                        print_info "Config sync cancelled"
                        exit 0
                    fi

                    BACKUP_FILE="$HOME/.openclaw/openclaw.json.backup.$(date +%Y%m%d_%H%M%S)"
                    print_info "Backing up current config..."
                    cp "$HOME/.openclaw/openclaw.json" "$BACKUP_FILE"

                    print_info "Merging template with current config..."
                    # Deep merge: template as base, current config values override
                    jq -s '.[0] * .[1]' \
                        "$HOME/openclaw-vps/config/openclaw.template.json" \
                        "$HOME/.openclaw/openclaw.json" \
                        > "$HOME/.openclaw/openclaw.json.merged"

                    # Replace current config with merged version
                    mv "$HOME/.openclaw/openclaw.json.merged" "$HOME/.openclaw/openclaw.json"

                    print_info "Restarting OpenClaw to apply changes..."
                    docker compose -f "$COMPOSE_FILE" restart openclaw

                    print_success "Config synced successfully!"
                    print_info "Backup saved to: $BACKUP_FILE"
                    print_info "Review changes with: diff $BACKUP_FILE ~/.openclaw/openclaw.json"
                    ;;
                *)
                    print_error "Unknown config command: $1"
                    echo "Available: view, edit, sync"
                    exit 1
                    ;;
            esac
            ;;

        # Status commands
        status)
            print_info "=== OpenClaw VPS Status ==="
            echo ""
            print_info "Docker Containers:"
            docker compose -f "$COMPOSE_FILE" ps
            echo ""
            print_info "Tailscale Status:"
            docker compose -f "$COMPOSE_FILE" exec -T openclaw tailscale status || true
            echo ""
            print_info "Disk Usage:"
            df -h "$HOME"
            echo ""
            print_info "Memory Usage:"
            free -h
            ;;

        health)
            print_info "Checking service health..."

            # Check Docker containers
            if docker compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
                print_success "✓ Docker containers running"
            else
                print_error "✗ Docker containers not running"
            fi

            # Check OpenClaw health endpoint
            if curl -sf http://localhost:18789/health >/dev/null 2>&1; then
                print_success "✓ OpenClaw health check passed"
            else
                print_warning "⚠ OpenClaw health check failed"
            fi

            # Check Tailscale
            if docker compose -f "$COMPOSE_FILE" exec -T openclaw tailscale status >/dev/null 2>&1; then
                print_success "✓ Tailscale connected"
            else
                print_warning "⚠ Tailscale not connected"
            fi
            ;;

        # Help
        help|--help|-h)
            show_help
            ;;

        *)
            print_error "Unknown command: $1"
            echo "Run 'tools help' for usage"
            exit 1
            ;;
    esac
}

main "$@"
