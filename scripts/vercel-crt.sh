#!/bin/bash

CHUNK_SIZE=10000
MAX_RETRIES=10
LOG_FILE="vercel_fetch.log"
PROGRESS_FILE="vercel_progress.txt"
BACKUP_DIR="vercel_backup"

log() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo "$message" | tee -a "$LOG_FILE"
}

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Load progress if exists
if [ -f "$PROGRESS_FILE" ]; then
    offset=$(cat "$PROGRESS_FILE")
    log "Resuming from offset $offset"
else
    offset=0
    echo $offset > "$PROGRESS_FILE"
fi

# Calculate chunk number from offset
get_chunk_num() {
    echo $((${1:-0} / CHUNK_SIZE))
}

has_data=true

fetch_chunk() {
    local current_chunk=$(get_chunk_num $offset)
    local retry_count=0
    local wait_time=5

    while [ $retry_count -lt $MAX_RETRIES ]; do
        log "Attempt $((retry_count + 1)) for chunk $current_chunk (offset: $offset)"
        
        psql -h crt.sh -U guest -d certwatch -p 5432 -c "\copy (
            WITH ci AS (
                SELECT min(sub.CERTIFICATE_ID) ID,
                       min(sub.ISSUER_CA_ID) ISSUER_CA_ID,
                       array_agg(DISTINCT sub.NAME_VALUE) NAME_VALUES,
                       x509_commonName(sub.CERTIFICATE) COMMON_NAME,
                       x509_notBefore(sub.CERTIFICATE) NOT_BEFORE,
                       x509_notAfter(sub.CERTIFICATE) NOT_AFTER,
                       encode(x509_serialNumber(sub.CERTIFICATE), 'hex') SERIAL_NUMBER,
                       count(sub.CERTIFICATE_ID)::bigint RESULT_COUNT
                    FROM (SELECT cai.*
                          FROM certificate_and_identities cai
                          WHERE plainto_tsquery('certwatch', '%.vercel.app') @@ identities(cai.CERTIFICATE)
                              AND cai.NAME_VALUE ILIKE ('%' || '%.vercel.app' || '%')
                          LIMIT $CHUNK_SIZE OFFSET $offset
                     ) sub
                GROUP BY sub.CERTIFICATE
            )
            SELECT ci.ISSUER_CA_ID,
                   ca.NAME ISSUER_NAME,
                   ci.COMMON_NAME,
                   array_to_string(ci.NAME_VALUES, chr(10)) NAME_VALUE,
                   ci.ID ID,
                   le.ENTRY_TIMESTAMP,
                   ci.NOT_BEFORE,
                   ci.NOT_AFTER,
                   ci.SERIAL_NUMBER,
                   ci.RESULT_COUNT
            FROM ci
                    LEFT JOIN LATERAL (
                        SELECT min(ctle.ENTRY_TIMESTAMP) ENTRY_TIMESTAMP
                            FROM ct_log_entry ctle
                            WHERE ctle.CERTIFICATE_ID = ci.ID
                    ) le ON TRUE,
                 ca
            WHERE ci.ISSUER_CA_ID = ca.ID
            ORDER BY le.ENTRY_TIMESTAMP DESC NULLS LAST
        ) TO STDOUT WITH CSV HEADER" > "vercel-chunk-$current_chunk.csv" 2>> "$LOG_FILE"

        # Retry configuration: https://www.backoff.dev/?base=5000&factor=2&retries=10&strategy=none

        if [ $? -eq 0 ]; then
            # Backup successful chunks immediately
            cp "vercel-chunk-$current_chunk.csv" "$BACKUP_DIR/"
            return 0
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $MAX_RETRIES ]; then
                log "Query failed. Retrying in $wait_time seconds..."
                sleep $wait_time
                wait_time=$((wait_time * 2))
            else
                log "Failed after $MAX_RETRIES attempts"
                return 1
            fi
        fi
    done
}

log "Starting pagination process..."

while $has_data; do
    current_chunk=$(get_chunk_num $offset)
    log "Fetching chunk $current_chunk (offset: $offset)..."
    
    if ! fetch_chunk; then
        log "Error fetching chunk. Saving progress and exiting."
        echo $offset > "$PROGRESS_FILE"
        exit 1
    fi
    
    # Check if we got any data (excluding header)
    if [ ! -f "vercel-chunk-$current_chunk.csv" ]; then
        log "Query failed to create output file"
        has_data=false
    else
        lines=$(wc -l < "vercel-chunk-$current_chunk.csv")
        if [ $lines -le 1 ]; then
            has_data=false
            log "No more data found."
        else
            log "Retrieved $(($lines - 1)) records."
            offset=$((offset + CHUNK_SIZE))
            echo $offset > "$PROGRESS_FILE"
            
            # Periodically combine chunks (every 10 chunks)
            if [ $((current_chunk % 10)) -eq 9 ]; then
                log "Periodic combination of chunks..."
                chunk_group_start=$((current_chunk - 9))
                if [ -f "vercel-chunk-$chunk_group_start.csv" ]; then
                    combined_file="vercel-combined-${chunk_group_start}-${current_chunk}.csv"
                    head -n1 "vercel-chunk-$chunk_group_start.csv" > "$combined_file"
                    for i in $(seq $chunk_group_start $current_chunk); do
                        if [ -f "vercel-chunk-$i.csv" ]; then
                            tail -n+2 "vercel-chunk-$i.csv" >> "$combined_file"
                        fi
                    done
                    # Backup combined file
                    cp "$combined_file" "$BACKUP_DIR/"
                    log "Periodic backup created for chunks $chunk_group_start to $current_chunk"
                fi
            fi
            
            # Add a delay between chunks
            sleep 5
        fi
    fi
done

log "Final combination of chunks..."
final_chunk=$(get_chunk_num $((offset - CHUNK_SIZE)))
if [ -f "vercel-chunk-0.csv" ]; then
    head -n1 "vercel-chunk-0.csv" > vercel-combined-final.csv
    for i in $(seq 0 $final_chunk); do
        if [ -f "vercel-chunk-$i.csv" ]; then
            tail -n+2 "vercel-chunk-$i.csv" >> vercel-combined-final.csv
        fi
    done
    cp vercel-combined-final.csv "$BACKUP_DIR/vercel-combined-final.csv"
    log "Combined data saved in vercel-combined-final.csv and backed up"
else
    log "No data chunks found to combine"
fi

# Don't cleanup until we confirm files are saved
if [ -f "$BACKUP_DIR/vercel-combined-final.csv" ]; then
    log "Verified backup exists, cleaning up..."
    rm -f vercel-chunk-*.csv vercel-combined-*.csv
    rm -f "$PROGRESS_FILE"
else
    log "Warning: Backup file not found, preserving chunk files"
fi

log "Process completed!"
