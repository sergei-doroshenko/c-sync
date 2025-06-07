#!/bin/bash
set -euo pipefail

# Get script directory and load configuration
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CONFIG_FILE="$SCRIPT_DIR/config.env"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration file not found at: $CONFIG_FILE" >&2
    echo "Please ensure config.env exists in the same directory as the script." >&2
    exit 1
fi

# Read configuration
source "$CONFIG_FILE"

# Validate required configuration
if [[ -z "${BACKUP_BUCKET:-}" ]] || [[ -z "${PROFILE:-}" ]] || [[ -z "${PATHTOREMOVE:-}" ]]; then
    echo "Error: Missing required configuration in $CONFIG_FILE" >&2
    echo "Required variables: BACKUP_BUCKET, PROFILE, PATHTOREMOVE" >&2
    exit 1
fi

# Make configuration readonly after loading
readonly BACKUP_BUCKET
readonly PROFILE
readonly PATHTOREMOVE

# Show error message
show_error() {
    echo "Error: $1" >&2
}

# Validation functions
validate_aws_config() {
    if ! aws configure get aws_access_key_id --profile "$PROFILE" >/dev/null 2>&1; then
        show_error "AWS profile '$PROFILE' not configured"
        return 1
    fi
}

validate_path() {
    local path="$1"
    if [[ -n "$path" && ! -e "$path" ]]; then
        show_error "Path does not exist: $path"
        return 1
    fi
    return 0
}

show_progress() {
    local action="$1"
    local path="$2"
    local s3_path="$3"
    
    echo "Starting $action of: $path"
    echo "Current directory: $(pwd)"
    echo "S3 destination: $s3_path"
}

# Display help information
show_help() {
    cat << EOF
Usage: c-sync <command> [path]

AWS S3 backup and sync utility

Commands:
  bu [path]     Backup a file or directory to S3
  sync [path]   Sync cloud files with local copy
  ls [path]     List cloud directories
  rs [path]     Restore from cloud
  h             Show this help message

Examples:
  c-sync bu                # Backup current directory
  c-sync bu file.txt       # Backup a specific file
  c-sync bu directory/     # Backup a specific directory
  c-sync sync              # Sync current directory
  c-sync ls                # List contents of current directory in S3

Note:
  - Paths can be specified as:
    * Relative path (from current directory)
    * Absolute path (starting with /)
    * Home directory path (starting with ~)
  - If no path is provided, current directory is used

EOF
}

# Generate S3 path for a given local path
get_s3_path() {
    local item_path="$1"
    local full_path
    
    if [[ -z "$item_path" ]]; then
        full_path=$(pwd)
    elif [[ "$item_path" == "~"* ]]; then
        # For paths with ~, expand to full path
        full_path="${item_path/#\~/$HOME}"
    elif [[ "$item_path" == /* ]]; then
        # For absolute paths, use as is
        full_path="$item_path"
    else
        # For relative paths, prepend pwd
        full_path="$(pwd)/$item_path"
    fi
    
    # Remove PATHTOREMOVE from the full path
    local clean_path=$(echo "$full_path" | sed s/"$PATHTOREMOVE"//)
    echo "s3://$BACKUP_BUCKET/$clean_path"
}

# Backup a file or directory to S3
backup_item() {
    local item_path="$1"
    
    if [[ -z "$item_path" ]]; then
        # Use current directory if no path provided
        item_path=$(pwd)
    fi

    validate_path "$item_path" || return 1
    
    local s3_path
    s3_path=$(get_s3_path "$item_path")
    show_progress "backup" "$item_path" "$s3_path"

    if [[ -d "$item_path" ]]; then
        echo "$item_path is a directory"
        aws s3 cp "$item_path" "$s3_path" --recursive --profile "$PROFILE"
    elif [[ -f "$item_path" ]]; then
        echo "$item_path is a file"
        aws s3 cp "$item_path" "$s3_path" --profile "$PROFILE"
    else
        show_error "$item_path is not valid"
        return 1
    fi
}

# Sync local files with cloud
sync_items() {
    local item_path="$1"
    
    if [[ -z "$item_path" ]]; then
        # Use current directory if no path provided
        item_path=$(pwd)
    fi

    validate_path "$item_path" || return 1
    
    local s3_path
    s3_path=$(get_s3_path "$item_path")
    show_progress "sync" "$item_path" "$s3_path"

    if [[ -d "$item_path" ]]; then
        echo "$item_path is a directory"
        aws s3 sync "$item_path" "$s3_path" --profile "$PROFILE"
    elif [[ -f "$item_path" ]]; then
        echo "$item_path is a file"
        # For single files, we use cp as sync is only for directories
        aws s3 cp "$item_path" "$s3_path" --profile "$PROFILE"
    else
        show_error "$item_path is not valid"
        return 1
    fi
}

# List objects and directories in S3
list_items() {
    local path="$1"
    local s3_path
    
    if [[ -z "$path" ]]; then
        # Use current directory if no path provided
        path=$(pwd)
    fi
    s3_path=$(get_s3_path "$path")

    echo "Listing contents of: $s3_path"
    echo "-------------------------------------------"
    
    # List objects with sizes and last modified dates
    aws s3 ls "$s3_path/" --profile "$PROFILE" --human-readable

    if [[ $? -ne 0 ]]; then
        show_error "Failed to list S3 contents. Please check if the path exists."
        return 1
    fi
}

# Main function to handle command processing
main() {
    # Validate AWS configuration
    validate_aws_config || exit 1
    
    # Handle no arguments case
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi

    local command="$1"
    shift
    local path="${1:-}"  # Use empty string if no path provided

    case "$command" in
        "h")
            show_help
            ;;
        "bu")
            backup_item "$path"
            ;;
        "sync")
            sync_items "$path"
            ;;
        "ls")
            list_items "$path"
            ;;
        *)
            show_error "Unknown command. Supported commands: bu - backup, ls - list cloud directories, rs - restore from cloud, sync - sync cloud with local"
            show_help
            exit 1
            ;;
    esac
}

# Execute main function with all script arguments
main "$@"
