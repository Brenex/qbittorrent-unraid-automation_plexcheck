#!/bin/bash

# Configuration File
# This script sources environment variables from a separate configuration file
# for sensitive information like API tokens and external command paths.

# Determine the directory where the script is located
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
set -a
. "${CONFIG_FILE}"
set +a

# Verify essential variables are set
if [ -z "${PLEX_IP}" ] || [ -z "${PLEX_PORT}" ] || [ -z "${PLEX_TOKEN}" ] || [ -z "${QBITTORRENT_AUTOMATION_CMD}" ]; then
    echo "Error: One or more required configuration variables (PLEX_IP, PLEX_PORT, PLEX_TOKEN, QBITTORRENT_AUTOMATION_CMD) are not set in ${CONFIG_FILE}." >&2
    exit 1
fi

# Derived Configuration (based on sourced variables)
PLEX_API_URL="http://${PLEX_IP}:${PLEX_PORT}/status/sessions"

# --- Main Logic ---

# Make a single curl call to fetch Plex sessions
CURL_FULL_OUTPUT=$(curl -s --max-time 5 -H "X-Plex-Token: ${PLEX_TOKEN}" -H "Accept: application/xml" "${PLEX_API_URL}" 2>&1)
CURL_EXIT_CODE=$?

# Extract only the XML portion from the full curl output
PLEX_XML_OUTPUT=$(echo "${CURL_FULL_OUTPUT}" | sed -n '/<?xml/,/<\/MediaContainer>/p')

# Check curl's exit code *first*
if [ ${CURL_EXIT_CODE} -ne 0 ]; then
    echo "Error: Failed to fetch Plex sessions. curl exit code: ${CURL_EXIT_CODE}. Check Plex IP/Port/Token and connectivity." >&2
    echo "--- Full cURL Debug Output ---" >&2
    echo "${CURL_FULL_OUTPUT}" >&2
    echo "--- End cURL Debug Output ---" >&2
    exit 1
fi

# If curl was successful (exit code 0), then proceed to count streams from the XML
ACTIVE_STREAMS=$(echo "${PLEX_XML_OUTPUT}" | grep -c '^ *<Video')

# Trim whitespace from the count, ensure it's treated as a number
ACTIVE_STREAMS=$(echo "${ACTIVE_STREAMS}" | tr -d '[:space:]')
ACTIVE_STREAMS=${ACTIVE_STREAMS:-0} # Default to 0 if count is empty or non-numeric

if [ "${ACTIVE_STREAMS}" -gt 0 ]; then
    echo "Active Plex streams detected: ${ACTIVE_STREAMS}. No action taken."
else
    echo "No active Plex streams detected. Running qBittorrent-Unraid automation script."

    echo "Executing configured qBittorrent-Unraid automation command."
    # Use 'eval' or 'bash -c' to execute the command stored in a variable with arguments
    # 'eval' is simple but can be risky with untrusted input (not an issue here as you control config.env)
    # 'bash -c' is generally safer for complex commands with quoted arguments
    bash -c "${QBITTORRENT_AUTOMATION_CMD}"
    # Alternative with eval (less preferred for general use due to security implications if source is untrusted):
    # eval "${QBITTORRENT_AUTOMATION_CMD}"

    echo "qBittorrent-mover completed and resumed all paused torrents."
fi

exit 0
