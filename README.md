# os-automatisierung

OPNsense plugin for centralized management of multiple OPNsense firewall instances.

## Features

- **Status dashboard** — firmware version, Zenarmor version, online/offline status and pending update indicators for all managed instances
- **Firmware updates** — trigger OPNsense firmware updates individually or in bulk; scheduled via cron
- **Zenarmor management** — version monitoring, update triggering, engine watchdog with automatic restart on crash
- **Configuration backup** — periodic backup of `config.xml` from all managed hosts, stored locally under `/conf/automatisierung/backups/`, configurable retention policy, unified diff view between versions
- **Secure credential management** — API key/secret per managed host, stored in OPNsense `config.xml`

## Requirements

- OPNsense 26.1 or later (FreeBSD 14.2+, PHP 8.3, Python 3.11)
- No external dependencies beyond the OPNsense framework and Python stdlib

## Installation

Run the installer on your OPNsense firewall:

```sh
sh install.sh root@<firewall-ip>
```

The installer copies all plugin files, registers the configd actions, compiles locale files and sets up the cron jobs.

### Manual deployment

```sh
# Copy plugin files
scp -r src/ root@<firewall-ip>:/usr/local/opnsense/

# Restart configd to pick up the new actions
ssh root@<firewall-ip> "service configd restart"

# Compile locale files (requires gettext-tools: pkg install gettext-tools)
sh scripts/compile_mo.sh
```

## Configuration

After installation, navigate to **Services → Automation → Configuration** in the OPNsense web UI.

Add each managed firewall instance with:
- **Name** — display label
- **URL** — base URL of the OPNsense instance (e.g. `https://192.168.1.1`)
- **API Key / API Secret** — OPNsense API credentials (System → Access → Users)

Use **Test Connection** to verify credentials before saving.

## Configd actions

The plugin registers two backend actions callable via `configctl`:

```sh
configctl automatisierung backup    # run configuration backup for all hosts
configctl automatisierung watchdog  # check Zenarmor engine health and restart if needed
```

## Cron schedule

The installer writes `/etc/cron.d/automatisierung`:

| Schedule | Action |
|---|---|
| Every 5 minutes | Zenarmor watchdog check |
| Every hour | Configuration backup |

## File structure

```
src/opnsense/
├── mvc/app/
│   ├── controllers/OPNsense/Automatisierung/
│   │   ├── IndexController.php
│   │   └── Api/
│   │       ├── BackupController.php
│   │       ├── ServiceController.php
│   │       └── SettingsController.php
│   ├── models/OPNsense/Automatisierung/
│   │   ├── Automatisierung.php
│   │   ├── Automatisierung.xml
│   │   ├── ACL/ACL.xml
│   │   └── Menu/Menu.xml
│   ├── views/OPNsense/Automatisierung/
│   │   ├── status.volt
│   │   ├── config.volt
│   │   └── backup.volt
│   └── locale/          # en_US (source), de_DE + 12 stub translations
├── scripts/Automatisierung/
│   ├── backup_job.py
│   └── za_watchdog.py
└── service/conf/actions.d/
    └── actions_automatisierung.conf
```

## License

BSD 2-Clause — see individual source files for full license text.

## AI disclosure

This plugin was developed with assistance from **Claude Sonnet 4.6** by Anthropic (Claude Code).
