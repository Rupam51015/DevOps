#!/bin/bash

# ==============================================================================
# CONFIGURATION
# ==============================================================================
# Target directory where application logs are stored
LOG_DIR="/var/log/myapp"

# Script's internal execution log to track history and errors
SCRIPT_LOG="$LOG_DIR/log_management.log"

# Thresholds (in days)
COMPRESS_AGE=7  # Compress active logs older than 7 days
RETENTION_AGE=30 # Permanently delete archives older than 30 days

# ==============================================================================
# EXECUTION
# ==============================================================================

# Ensure the log directory exists before proceeding
if [ ! -d "$LOG_DIR" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] Log directory '$LOG_DIR' does not exist." >> "$SCRIPT_LOG"
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Starting log rotation and cleanup process..." >> "$SCRIPT_LOG"

# Step 1: Compress uncompressed log files older than X days
# -mtime +$COMPRESS_AGE ensures we only touch older files
# -not -name "*.gz" guarantees we don't try to double-compress
find "$LOG_DIR" -type f -name "*.log" -mtime +$COMPRESS_AGE -not -name "*.gz" -exec gzip {} \; 2>> "$SCRIPT_LOG"

if [ $? -eq 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Successfully compressed logs older than $COMPRESS_AGE days." >> "$SCRIPT_LOG"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] Issues encountered during log compression." >> "$SCRIPT_LOG"
fi

# Step 2: Delete compressed archive logs older than Y days
# -name "*.gz" filters strictly for archives to prevent accidental active log removal
find "$LOG_DIR" -type f -name "*.gz" -mtime +$RETENTION_AGE -exec rm -f {} \; 2>> "$SCRIPT_LOG"

if [ $? -eq 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Successfully purged archives older than $RETENTION_AGE days." >> "$SCRIPT_LOG"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] Issues encountered during log purging." >> "$SCRIPT_LOG"
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Process completed." >> "$SCRIPT_LOG"
echo "--------------------------------------------------------" >> "$SCRIPT_LOG"
