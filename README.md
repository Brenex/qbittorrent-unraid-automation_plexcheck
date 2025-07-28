# qbittorrent-unraid-automation_plexcheck
This script provides a robust automation solution for managing qBittorrent activities on an Unraid server, with an intelligent pre-check for active Plex streams. It prevents the execution of your qBittorrent automation command (e.g., a mover script) if Plex is actively streaming content, ensuring an uninterrupted media consumption experience.

## Features

- **Plex Session Detection:** Checks for active video streams on your Plex Media Server before proceeding.
- **Configurable:** All sensitive information and the automation command are managed via a separate `.env` file.
- **Error Handling:** Provides clear error messages for missing configuration, `curl` failures, and other issues.
- **Safe Execution:** Uses `bash -c` to execute the configured automation command, handling complex commands and arguments safely.
- **Unraid Optimized:** Designed with Unraid environments in mind, though adaptable to other Linux systems.

## Prerequisites

- A Linux-based system (e.g., Unraid OS) with `bash`, `curl`, `grep`, and `sed` installed.
- Plex Media Server running and accessible from the script's execution environment.
- A Plex API token for authentication.
- A qBittorrent automation script or command you wish to execute (e.g., a torrent mover script).

## Setup

1. **Download the Script:** Save the `qbittorrent-unraid-automation_plexcheck.sh` script to a desired location on your Unraid server (e.g., `/mnt/user/appdata/scripts/`).
2. **Create the Configuration File (`.env`):** In the *same directory* as the `qbittorrent-unraid-automation_plexcheck.sh` script, create a file named `.env`. This file will store your configuration variables.
	Example `.env` content:
	```
	# Plex Media Server Configuration
	PLEX_IP="192.168.1.100"       # Your Plex Media Server IP address
	PLEX_PORT="32400"            # Your Plex Media Server port (default is 32400)
	PLEX_TOKEN="YOUR_PLEX_TOKEN" # Your Plex X-Plex-Token (see below for how to get this)
	# qBittorrent Automation Command
	# This is the command that will be executed if no active Plex streams are detected.
	# Example: A script to move completed torrents and resume paused ones.
	QBITTORRENT_AUTOMATION_CMD="/path/to/your/qbittorrent_mover_script.sh"
	# QBITTORRENT_AUTOMATION_CMD="echo 'No Plex streams, running my qBittorrent task!'"
	```
	**How to get your Plex X-Plex-Token:**
	- Open your Plex web app in a browser.
	- Navigate to any media item (e.g., a movie).
	- Click on the three dots (`...`) and select "Get Info".
	- Click on "View XML".
	- In the XML URL, you will find `?X-Plex-Token=YOUR_TOKEN_HERE`. Copy the token value.
3. **Set Permissions:** Make both the main script and your automation command executable:
	```
	chmod +x /path/to/your/qbittorrent-unraid-automation_plexcheck.sh
	chmod +x /path/to/your/qbittorrent_mover_script.sh # If applicable
	chmod 600 /path/to/your/.env # Important for security!
	```

## Usage

You can run the script manually or, more typically, schedule it using a cron job.

### Manual Execution

```
/path/to/your/qbittorrent-unraid-automation_plexcheck.sh
```

### Scheduling with Cron (Recommended)

To run the script automatically, for example, every 15 minutes:

1. Open your crontab for editing:
	```
	crontab -e
	```
2. Add the following line to the crontab. This example runs the script every 15 minutes:
	```
	*/15 * * * * /path/to/your/qbittorrent-unraid-automation_plexcheck.sh >> /var/log/qbittorrent_automation.log 2>&1
	```
	- Replace `/path/to/your/qbittorrent-unraid-automation_plexcheck.sh` with the actual path to your script.
	- The `>> /var/log/qbittorrent_automation.log 2>&1` part redirects both standard output and standard error to a log file, which is highly recommended for debugging and monitoring.

## How it Works

1. **Configuration Loading:** The script first locates and sources the `.env` file in its directory to load `PLEX_IP`, `PLEX_PORT`, `PLEX_TOKEN`, and `QBITTORRENT_AUTOMATION_CMD`.
2. **Validation:** It checks if all required environment variables are set. If any are missing, it exits with an error.
3. **Plex API Call:** It constructs a Plex API URL to fetch active sessions (`/status/sessions`) and makes a `curl` request, including the `X-Plex-Token` for authentication.
4. **Error Handling (Curl):** It checks the `curl` exit code. If `curl` fails (e.g., network issue, incorrect IP/port/token), it prints a detailed error message and exits, preventing the automation command from running.
5. **Active Stream Detection:** If `curl` is successful, it parses the XML output from Plex to count the number of active `<Video>` elements, which represent active video streams.
6. **Conditional Execution:**
	- If `ACTIVE_STREAMS` is greater than 0, it means Plex is actively streaming. The script will print a message indicating active streams and exit without running the `QBITTORRENT_AUTOMATION_CMD`.
	- If `ACTIVE_STREAMS` is 0, no active Plex streams are detected. The script will then execute the command specified in `QBITTORRENT_AUTOMATION_CMD` using `bash -c`.
7. **Completion Message:** After executing the automation command (or if no streams were detected), it prints a completion message.

## Troubleshooting

- **`Error: Configuration file '.env' not found!`**: Ensure your `.env` file is in the *same directory* as the `qbittorrent-unraid-automation_plexcheck.sh` script and is named `.env`.
- **`Error: One or more required configuration variables... are not set`**: Double-check your `.env` file for typos or missing values for `PLEX_IP`, `PLEX_PORT`, `PLEX_TOKEN`, or `QBITTORRENT_AUTOMATION_CMD`.
- **`Error: Failed to fetch Plex sessions...`**:
	- Verify `PLEX_IP` and `PLEX_PORT` are correct and Plex is running.
	- Ensure your `PLEX_TOKEN` is correct and has the necessary permissions.
	- Check network connectivity from where the script is running to your Plex server.
	- Temporarily run the `curl` command manually from your terminal to debug:
		```
		curl -s --max-time 5 -H "X-Plex-Token: YOUR_PLEX_TOKEN" "http://YOUR_PLEX_IP:YOUR_PLEX_PORT/status/sessions"
		```
- **Script not running via Cron:**
	- Ensure the script path in your crontab is correct.
	- Check the log file (`/var/log/qbittorrent_automation.log` in the example) for errors.
	- Verify that `cron` is running on your system.
	- Ensure the script has executable permissions (`chmod +x`).
- **Automation command not executing:**
	- Check the log file for any errors from the `QBITTORRENT_AUTOMATION_CMD`.
	- Verify the path to your `QBITTORRENT_AUTOMATION_CMD` is correct and it has executable permissions.
	- Test your `QBITTORRENT_AUTOMATION_CMD` manually to ensure it works as expected.
