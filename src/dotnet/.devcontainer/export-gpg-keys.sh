#!/bin/bash
# Scans host for public GPG keys, prompts the user for key selection, then
# exports selected public keys to a temporary file in the repository. Then
# a script under the "postCreateCommand" command will import said public GPG
# keys into the container for commit signing.

# Bash strict mode
set -euo pipefail

# Require first arg or exit
if [[ -z "${1:-}" ]]; then
    echo "Usage: $0 <repo-dir>" >&2
    exit 1
fi

# Fail early if GPG agent forwarding is unavailable
if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
    echo "Error: Environment variable 'XDG_RUNTIME_DIR' is not set. GPG agent forwarding will not work."
    exit 1
fi

if [[ ! -S "${XDG_RUNTIME_DIR}/gnupg/S.gpg-agent.extra" ]]; then
    echo "Error: GPG extra socket not found at ${XDG_RUNTIME_DIR}/gnupg/S.gpg-agent.extra"
    exit 1
fi

# Script source location
#SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Temporary output files
mkdir -p "${1}/tmp"
OUTPUT_FILE="${1}/tmp/.gpg-export.gpg"
META_FILE="${1}/tmp/.gpg-export.meta"

# Clean up function to remove tmp files
cleanup_outputs() {
    rm -f "$OUTPUT_FILE" "$META_FILE"
}

# Parse keys from host keyring
declare -a FINGERPRINTS=()
declare -a SHORT_IDS=()
declare -a UIDS=()
declare -a KEYS_TO_EXPORT=()

current_fpr=""
current_uid=""
skip_key=0

# Helper function to save key
save_current_key() {
    if [[ -n "$current_fpr" && -n "$current_uid" ]]; then
        FINGERPRINTS+=("$current_fpr")
        SHORT_IDS+=("${current_fpr: -16}")
        UIDS+=("$current_uid")
    fi
}

# Read available public keys
while IFS=: read -r type validity _ _ _ _ _ _ _ fpr_uid _; do
    case "$type" in
        pub)
            # Start of a new key: save the previous key, then reset state
            save_current_key
            current_fpr=""
            current_uid=""

            # Skip expired (e), revoked (r), invalid (i), and disabled (d) keys
            case "$validity" in
                e|r|i|d) skip_key=1 ;;
                *)       skip_key=0 ;;
            esac
            ;;
        fpr)
            # First fingerprint after "pub" is the primary key fingerprint
            if [[ $skip_key -eq 0 && -z "$current_fpr" ]]; then
                current_fpr="$fpr_uid"
            fi
            ;;
        uid)
        if [[ $skip_key -eq 0 && -z "$current_uid" ]]; then
            current_uid="${fpr_uid//\\x3a/:}"
        fi
        ;;
    esac
done < <(gpg --list-keys --with-colons 2>/dev/null)

# Save the last key
save_current_key

# Early exit if no keys
if [[ ${#FINGERPRINTS[@]} -eq 0 ]]; then
    echo "No usable GPG public keys found on host. Skipping public key import."
    cleanup_outputs
    exit 0
fi

# Display key selection header
echo ""
echo "GPG Key Selection for DevContainer"
echo "=================================="

# Display key list
echo ""
echo "Keys available on host:"
echo ""
for i in "${!FINGERPRINTS[@]}"; do
    printf "    %d %s %s\n" $((i + 1)) "${SHORT_IDS[$1]}" "${UIDS[$i]}"
done

# Prompt for key selection
echo ""
echo "    Enter numbers to import (space-separated), 'all', or 'none'"
echo "    default: all"
printf "    > "

# Read with a timeout (defaults to all)
SELECTION=""
if read -r -t 60 SELECTION; then
    SELECTION="${SELECTION:-all}"
else
    echo ""
    echo "    No input received. Defautling to 'all'"
    SELECTION="all"
fi

# Process selection
if [[ "$SELECTION" == "none" ]]; then
    echo ""
    echo "Skipping GPG key import."
    cleanup_outputs
    exit 0
elif [[ "$SELECTION" == "all" ]]; then
    KEYS_TO_EXPORT=("${FINGERPRINTS[@]}")
else
    for token in $SELECTION; do
        if [[ "$token" =~ ^[0-9]+$ ]]; then
            i=$((token -1 ))
            if [[ $i -ge 0 && $i -lt ${#FINGERPRINTS[@]} ]]; then
                KEYS_TO_EXPORT+=("${FINGERPRINTS[$i]}")
            else
                echo "    '$token' is out of range. Skipping."
            fi
        else
            echo "    '$token' is not a valid number. Skipping."
        fi
    done
fi

if [[ ${#KEYS_TO_EXPORT[@]} -eq 0 ]]; then
    echo ""
    echo "No valid keys selected. Nothing will be imported."
    cleanup_outputs
    exit 0
fi

# Export public keys
echo ""
echo "Exporting ${#KEYS_TO_EXPORT[@]} key(s)..."
gpg --export "${KEYS_TO_EXPORT[@]}" > "$OUTPUT_FILE"

# Write metadata for each selected key
: > "$META_FILE"
for fpr in "${KEYS_TO_EXPORT[@]}"; do
    for i in "${!FINGERPRINTS[@]}"; do
        if [[ "${FINGERPRINTS[$i]}" == "$fpr" ]]; then
            printf "%s\t%s\n" "$fpr" "${UIDS[$i]}" >> "$META_FILE"
        fi
    done
done

echo "Exported to $OUTPUT_FILE"
echo "Keys will be imported when the container starts."
echo ""
