#!/bin/bash

set -e

# Set project-relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

TEMPLATE_DIR="$PROJECT_ROOT/Codebase/Templates"
DOMAINS_FILE="$PROJECT_ROOT/Config/domains.txt"
OUTPUT_DIR="$PROJECT_ROOT/sites-enabled"

PHASE="$1"
MODE="$2"

if [[ "$PHASE" != "--phase" ]]; then
    echo "Usage: $0 --phase [init|full]"
    exit 1
fi

if [[ "$MODE" != "init" && "$MODE" != "full" ]]; then
    echo "Error: phase must be 'init' or 'full'"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Select the template based on phase
if [[ "$MODE" == "init" ]]; then
    TEMPLATE_PATH="$TEMPLATE_DIR/example.com.http.template"
else
    TEMPLATE_PATH="$TEMPLATE_DIR/example.com.template"
fi

if [ ! -f "$TEMPLATE_PATH" ]; then
    echo "Template not found at $TEMPLATE_PATH"
    exit 1
fi

echo ""
echo "Generating Nginx configs for phase: $MODE"
echo "Using template: $TEMPLATE_PATH"
echo ""

FIRST_LINE=true
SEEN=()

while IFS=, read -r domain ip; do
    domain=$(echo "$domain" | xargs)
    ip=$(echo "$ip" | xargs)

    # Skip header row
    if $FIRST_LINE; then
        FIRST_LINE=false
        if [[ "$domain" == "domain" && "$ip" == "ip" ]]; then
            echo "Skipping header: domain,ip"
            continue
        fi
    fi

    # Skip empty or commented lines
    if [[ -z "$domain" || -z "$ip" || "$domain" == \#* ]]; then
        continue
    fi

    # Avoid generating config twice for same domain
    if [[ " ${SEEN[*]} " =~ " $domain " ]]; then
        continue
    fi

    # In full mode, skip if SSL cert doesn't exist
    if [[ "$MODE" == "full" && ! -f "/etc/letsencrypt/live/$domain/fullchain.pem" ]]; then
        echo "Skipping $domain — no cert found"
        continue
    fi

    SEEN+=("$domain")

    # Build config for main domain
    output_file="$OUTPUT_DIR/$domain"
    echo "→ $domain ($ip)"
    sed "s/{{DOMAIN}}/$domain/g; s/{{IP}}/$ip/g" "$TEMPLATE_PATH" > "$output_file"

    # If domain does not start with www., add www variant too
    if [[ "$domain" != www.* ]]; then
        www_domain="www.$domain"

        if [[ ! " ${SEEN[*]} " =~ " $www_domain " ]]; then
            if [[ "$MODE" == "full" && ! -f "/etc/letsencrypt/live/$www_domain/fullchain.pem" ]]; then
                echo "Skipping $www_domain — no cert found"
                continue
            fi

            www_output_file="$OUTPUT_DIR/$www_domain"
            echo "→ $www_domain ($ip)"
            sed "s/{{DOMAIN}}/$www_domain/g; s/{{IP}}/$ip/g" "$TEMPLATE_PATH" > "$www_output_file"
            SEEN+=("$www_domain")
        fi
    fi
done < "$DOMAINS_FILE"

echo ""
echo "Config generation complete. Files are in $OUTPUT_DIR"
