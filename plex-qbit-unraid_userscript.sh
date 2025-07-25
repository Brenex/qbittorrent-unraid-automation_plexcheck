#!/bin/bash

# Configuration File
# This script sources environment variables from a separate configuration file
# for sensitive information like API tokens.

# Determine the directory where the script is located
# BASH_SOURCE[0] is the path to the script itself
# dirname extracts the directory part of a path
# pwd -P gets the canonical path, resolving symlinks
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd -P )"
CONFIG_FILE="${SCRIPT_DIR}/config.env" # Path relative to the script's directory

# Check if the configuration file exists
if [ ! -f "${CONFIG_FILE}" ]; then
    echo "Error: Configuration file '${CONFIG_FILE}' not found!" >&2
    echo "Please ensure 'config.env' is in the same directory as the script." >&2
    echo "Set appropriate permissions (e.g., chmod 600 ${CONFIG_FILE})." >&2
    exit 1
fi

# Source the configuration file to load environment variables
# This makes variables like PLEX_IP, PLEX_PORT, PLEX_TOKEN available in the script's environment.
set -a
. "${CONFIG_FILE}"
set +a

# Verify essential variables are set (optional, but good practice)
if [ -z "${PLEX_IP}" ] || [ -z "${PLEX_PORT}" ] || [ -z "${PLEX_TOKEN}" ]; then
    echo "Error: One or more required Plex configuration variables (PLEX_IP, PLEX_PORT, PLEX_TOKEN) are not set in ${CONFIG_FILE}." >&2
    exit 1
fi

# Derived Configuration (based on sourced variables)
PLEX_API_URL="http://${PLEX_IP}:${PLEX_PORT}/status/sessions"

# --- Main Logic ---

# Make a single curl call to fetch Plex sessions
# -s: Silent mode (suppresses progress meter and error messages)
# -v: Verbose output (will show connection details, headers, etc. - useful for debugging, can be removed for production)
# --max-time: Timeout for the request
# -H: Add header for X-Plex-Token
# Accept: application/xml for response format
# 2>&1: Redirect stderr (where verbose output goes) to stdout, so it's captured by the variable
CURL_FULL_OUTPUT=$(curl -s --max-time 5 -H "X-Plex-Token: ${PLEX_TOKEN}" -H "Accept: application/xml" "${PLEX_API_URL}" 2>&1)
CURL_EXIT_CODE=$?

# Extract only the XML portion from the full curl output
# This assumes the XML starts with "<?xml" and ends with "</MediaContainer>"
# We use sed to grab only the lines between these markers.
PLEX_XML_OUTPUT=$(echo "${CURL_FULL_OUTPUT}" | sed -n '/<?xml/,/<\/MediaContainer>/p')

# Check curl's exit code *first*
if [ ${CURL_EXIT_CODE} -ne 0 ]; then
    echo "Error: Failed to fetch Plex sessions. curl exit code: ${CURL_EXIT_CODE}. Check Plex IP/Port/Token and connectivity." >&2
    echo "--- Full cURL Debug Output ---" >&2
    echo "${CURL_FULL_OUTPUT}" >&2 # Show all output for true curl errors
    echo "--- End cURL Debug Output ---" >&2
    exit 1
fi

# If curl was successful (exit code 0), then proceed to count streams from the XML
# grep -c '^ *<Video': Counts lines starting with <Video> (optionally preceded by spaces)
ACTIVE_STREAMS=$(echo "${PLEX_XML_OUTPUT}" | grep -c '^ *<Video')

# Trim whitespace from the count, ensure it's treated as a number
ACTIVE_STREAMS=$(echo "${ACTIVE_STREAMS}" | tr -d '[:space:]')
ACTIVE_STREAMS=${ACTIVE_STREAMS:-0} # Default to 0 if count is empty or non-numeric

if [ "${ACTIVE_STREAMS}" -gt 0 ]; then
    echo "Active Plex streams detected: ${ACTIVE_STREAMS}. No action taken."
else
    echo "No active Plex streams detected. Running qBittorrent-Unraid automation script."

    echo "Executing script to remove unregistered torrents before moving, pause torrents and run mover."
    /mnt/user/scripts/qbittorrent-unraid-automation/.venv/bin/python3 /mnt/user/scripts/qbittorrent-unraid-automation/qbittorrent-unraid-automation.py --cache-mount "/mnt/cache" --user-share-mount "/mnt/user" --ignore-cache-folders "/mnt/cache/appdata,/mnt/cache/system,/mnt/cache/incomplete"
    echo "qBittorrent-mover completed and resumed all paused torrents."
fi

exit 0
