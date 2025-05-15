#!/bin/bash

# Backup Management System in Bash

# Configuration
SOURCE_DIRS=("/path/to/source1" "/path/to/source2")  # Default source directories (modify as needed)
BACKUP_DIR="/path/to/backup"                         # Default backup directory (modify as needed)
METADATA_FILE="backup_metadata.txt"                  # File to store backup metadata
LOG_FILE="backup_management.log"                     # Log file for actions
RETENTION_DAYS=7                                     # Days to keep backups

# Ensure data and log files exist
touch "$METADATA_FILE" "$LOG_FILE"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to display menu
display_menu() {
    echo "================================="
    echo "   Backup Management System"
    echo "================================="
    echo "1. Create Backup"
    echo "2. List Backups"
    echo "3. Restore Backup"
    echo "4. Delete Backup"
    echo "5. Configure Source/Backup Directories"
    echo "6. Exit"
    echo "================================="
    echo "Enter your choice (1-6): "
}

# Function to validate directories
validate_directories() {
    local valid=true
    for dir in "${SOURCE_DIRS[@]}"; do
        if [ ! -d "$dir" ]; then
            echo "Error: Source directory $dir does not exist."
            log_message "ERROR: Source directory $dir does not exist."
            valid=false
        fi
    done
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "Error: Backup directory $BACKUP_DIR does not exist."
        log_message "ERROR: Backup directory $BACKUP_DIR does not exist."
        valid=false
    fi
    $valid
}

# Function to create a backup
create_backup() {
    # Validate directories
    validate_directories || return

    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"

    # Generate backup name with timestamp
    local TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    local BACKUP_NAME="backup_$TIMESTAMP.tar.gz"

    # Create compressed backup for all source directories
    echo "Creating backup..."
    local tar_cmd="tar -czf \"$BACKUP_DIR/$BACKUP_NAME\""
    for dir in "${SOURCE_DIRS[@]}"; do
        tar_cmd+=" -C \"$dir\" ."
    done
    if eval "$tar_cmd" 2>/dev/null; then
        echo "Backup created successfully: $BACKUP_DIR/$BACKUP_NAME"
        log_message "Backup created successfully: $BACKUP_NAME"
        # Store metadata (backup name, sources, timestamp)
        local sources=$(IFS=","; echo "${SOURCE_DIRS[*]}")
        echo "$BACKUP_NAME:$sources:$TIMESTAMP" >> "$METADATA_FILE"
    else
        echo "Error: Backup creation failed."
        log_message "ERROR: Backup creation failed for $BACKUP_NAME."
        return 1
    fi

    # Clean up backups older than RETENTION_DAYS
    find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +"$RETENTION_DAYS" -delete
    if [ $? -eq 0 ]; then
        log_message "Cleaned up backups older than $RETENTION_DAYS days."
    else
        log_message "ERROR: Failed to clean up old backups."
    fi
}

# Function to list all backups
list_backups() {
    if [ ! -s "$METADATA_FILE" ]; then
        echo "No backups found."
        log_message "List backups: No backups found."
        return
    fi
    echo "Backup Name | Source Directories | Timestamp"
    echo "----------------------------------------"
    while IFS=: read -r backup_name sources timestamp; do
        echo "$backup_name | $sources | $timestamp"
    done < "$METADATA_FILE"
    log_message "Listed all backups."
}

# Function to restore a backup
restore_backup() {
    echo "Enter Backup Name (e.g., backup_20250514_151022.tar.gz): "
    read backup_name
    if ! grep -q "^$backup_name:" "$METADATA_FILE"; then
        echo "Error: Backup $backup_name not found."
        log_message "ERROR: Attempt to restore non-existent backup $backup_name."
        return
    fi
    echo "Enter Restore Directory (where to restore): "
    read restore_dir
    if [ ! -d "$restore_dir" ]; then
        echo "Error: Restore directory $restore_dir does not exist."
        log_message "ERROR: Restore directory $restore_dir does not exist."
        return
    fi
    # Restore backup
    if tar -xzf "$BACKUP_DIR/$backup_name" -C "$restore_dir" 2>/dev/null; then
        echo "Backup $backup_name restored to $restore_dir successfully."
        log_message "Backup $backup_name restored to $restore_dir successfully."
    else
        echo "Error: Restore failed."
        log_message "ERROR: Restore failed for $backup_name."
        return 1
    fi
}

# Function to delete a backup
delete_backup() {
    echo "Enter Backup Name (e.g., backup_20250514_151022.tar.gz): "
    read backup_name
    if ! grep -q "^$backup_name:" "$METADATA_FILE"; then
        echo "Error: Backup $backup_name not found."
        log_message "ERROR: Attempt to delete non-existent backup $backup_name."
        return
    fi
    # Delete backup file and metadata
    rm -f "$BACKUP_DIR/$backup_name"
    temp_file=$(mktemp)
    grep -v "^$backup_name:" "$METADATA_FILE" > "$temp_file"
    mv "$temp_file" "$METADATA_FILE"
    echo "Backup $backup_name deleted successfully."
    log_message "Backup $backup_name deleted successfully."
}

# Function to configure source and backup directories
configure_directories() {
    echo "Current Source Directories: ${SOURCE_DIRS[*]}"
    echo "Enter Source Directories (space-separated, leave blank to keep current): "
    read -r new_sources
    if [ -n "$new_sources" ]; then
        # Convert space-separated input to array
        IFS=' ' read -r -a temp_dirs <<< "$new_sources"
        valid=true
        for dir in "${temp_dirs[@]}"; do
            if [ ! -d "$dir" ]; then
                echo "Error: Directory $dir does not exist."
                log_message "ERROR: Invalid source directory $dir."
                valid=false
            fi
        done
        if $valid; then
            SOURCE_DIRS=("${temp_dirs[@]}")
            echo "Source directories updated: ${SOURCE_DIRS[*]}"
            log_message "Source directories updated: ${SOURCE_DIRS[*]}"
        else
            return
        fi
    fi
    echo "Enter Backup Directory (current: $BACKUP_DIR): "
    read new_backup
    if [ -n "$new_backup" ]; then
        if [ -d "$new_backup" ] || mkdir -p "$new_backup"; then
            BACKUP_DIR="$new_backup"
            echo "Backup directory updated to $BACKUP_DIR."
            log_message "Backup directory updated to $BACKUP_DIR."
        else
            echo "Error: Could not create or access $new_backup."
            log_message "ERROR: Invalid backup directory $new_backup."
            return
        fi
    fi
}

# Main loop
while true; do
    display_menu
    read choice
    case $choice in
        1) create_backup ;;
        2) list_backups ;;
        3) restore_backup ;;
        4) delete_backup ;;
        5) configure_directories ;;
        6) echo "Exiting..."; log_message "System exited."; exit 0 ;;
        *) echo "Invalid choice. Please enter a number between 1 and 6." ;;
    esac
    echo "Press Enter to continue..."
    read
done
