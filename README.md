# Docker Container State Monitor

A small Bash automation project for monitoring Docker container state changes and sending Telegram alerts when a monitored workload changes state.

This is an older operational script from my automation work. I am keeping the implementation close to its original form because it reflects how I approached repetitive operational checks with simple Linux tooling.

## What Problem It Solves

Without monitoring, a stopped or restarting container can remain unnoticed until somebody manually checks the host.

This script periodically inspects Docker state and records the last observed state locally. When the state changes, it sends a Telegram notification instead of repeatedly sending the same alert on every run.

The core idea is simple:

```text
Discover workloads
      ↓
Persist monitored names
      ↓
Check current Docker state
      ↓
Compare with local state marker
      ↓
State changed?
   ├─ No  → only write log
   └─ Yes → replace state marker + send Telegram alert
```

## What the Script Actually Does

The current implementation:

- reads Docker containers using `docker ps -a`
- derives a monitored identifier from the container image name
- stores discovered identifiers in `container.properties`
- checks for the states `running`, `restarting`, `removing`, `paused`, `exited`, and `dead`
- treats a monitored identifier that no longer appears in `docker ps -a` as `down`
- writes timestamped status entries under a local `logs/` directory
- keeps one state-marker file per monitored workload under `state/`
- sends a Telegram message only when the marker for that workload changes
- includes hostname and the host's externally resolved IP address in the notification

The notification mechanism uses the Telegram Bot API through `curl`.

## Requirements

- Linux host
- Bash
- Docker CLI
- `curl`
- standard Unix utilities such as `awk`, `grep`, `cut`, `find`, and `sort`
- Telegram bot token and destination chat/channel ID

## Expected Directory Layout

The original script expects this layout:

```text
/root/script/monitoring/
├── container.properties
├── logs/
└── state/
```

Create the directories first:

```bash
mkdir -p /root/script/monitoring/logs
mkdir -p /root/script/monitoring/state
```

## Configuration

Edit these values inside `monitoring-docker-images.sh`:

```bash
path=/root/script/monitoring
chat_id="{{YOUR CHAT_ID CHANNEL}}"
token="{{YOUR TOKEN BOT}}"
```

Do not commit a real Telegram token to Git.

## Running It

Make the script executable:

```bash
chmod +x monitoring-docker-images.sh
```

Then run it with Bash:

```bash
bash monitoring-docker-images.sh
```

For continuous monitoring, the original design is intended to be invoked periodically by an external scheduler such as cron.

Example:

```cron
* * * * * /bin/bash /root/script/monitoring/monitoring-docker-images.sh
```

Choose the interval according to the environment you are monitoring.

## State-Change Suppression

The useful part of the script is not just checking Docker status.

It keeps local marker files such as:

```text
<workload>-running
<workload>-exited
<workload>-dead
```

When the observed state stays the same, the script continues logging it but does not send the same Telegram notification again.

When the state changes, the old marker is removed, a new marker is created, and one notification is sent.

That avoids turning a simple polling loop into an alert storm.

## Known Limitations

This repository is a small operational script, not a production monitoring platform. The current implementation has several assumptions worth making explicit:

- it tracks workloads primarily by **Docker image name**, not a stable container ID or container name
- matching relies heavily on `grep`, so similarly named images can produce ambiguous matches
- the working directory is hard-coded to `/root/script/monitoring`
- Telegram credentials are configured directly in the script instead of environment variables or a secret store
- external IP discovery depends on `curl ifconfig.me`
- the script assumes the required `logs/` and `state/` directories already exist
- several command substitutions and path usages are not hardened for unusual whitespace or special characters
- there is no locking, so overlapping scheduler executions could race
- there is no retry/backoff strategy for Telegram delivery
- the file currently starts with `# !bin/bash`, so invoking it explicitly with `bash monitoring-docker-images.sh` is safer unless the shebang is corrected to `#!/bin/bash`

These limitations are intentionally documented rather than hidden. If I rebuilt the tool today, I would separate configuration from code, identify containers more deterministically, add locking and error handling, and test state transitions explicitly.

## Why This Project Is Still in My Portfolio

The code is small, but the engineering instinct behind it still represents how I work:

> notice a repetitive operational check, make the state explicit, suppress duplicate work, and automate the notification path.

The implementation predates the larger AI-assisted applications I build today, so I keep it as a simple example of the automation mindset that has been part of my work for years.
