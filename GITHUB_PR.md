# Add os-automatisierung: Multi-instance OPNsense automation & backup plugin

Closes #ISSUE_NUMBER

## What this plugin does

`os-automatisierung` lets you manage multiple OPNsense firewall instances from a single OPNsense installation. It provides:

- **Status dashboard** — firmware + Zenarmor version overview for all managed instances, online/offline status, pending update indicators
- **Firmware updates** — one-click or bulk update of OPNsense firmware across instances; scheduled via cron
- **Zenarmor management** — version monitoring, update trigger, engine watchdog (auto-restart on crash)
- **Config backup** — periodic backup of `config.xml` from all managed hosts, stored locally under `/var/db/automatisierung/backups/`, retention policy, unified diff view (server-side `diff -u`)

## Technical details

| Area | Detail |
|---|---|
| Language | PHP 8.3, Python 3, Volt templates |
| Framework | OPNsense MVC (ApiMutableModelControllerBase, ApiControllerBase) |
| Backend | Python scripts callable via configd (`automatisierung backup`, `automatisierung watchdog`) |
| i18n | English msgids, gettext PO/MO; de_DE translations included |
| License | BSD 2-Clause |
| Dependencies | None beyond OPNsense framework + Python stdlib |
| Cron | `/etc/cron.d/automatisierung` via `configctl` calls |

## Files changed

```
net/automatisierung/
├── Makefile
├── pkg-descr
└── src/opnsense/
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
    │   │   ├── config.volt
    │   │   ├── status.volt
    │   │   └── backup.volt
    │   └── locale/
    │       ├── en_US/LC_MESSAGES/OPNsense.Automatisierung.po
    │       ├── de_DE/LC_MESSAGES/OPNsense.Automatisierung.po
    │       └── [12 other locale stubs]
    ├── scripts/Automatisierung/
    │   ├── backup_job.py
    │   └── za_watchdog.py
    └── service/conf/actions.d/
        └── actions_automatisierung.conf
```

## Testing

Tested on OPNsense 26.1 (FreeBSD 14.2, PHP 8.3, Python 3.11):

- [x] Plugin installs without errors
- [x] Status page loads and polls all configured instances
- [x] OPNsense firmware update triggers correctly on remote host
- [x] Zenarmor version detection via `pkg query "%v" os-sensei`
- [x] Zenarmor watchdog detects stopped engine and restarts
- [x] Configuration backup saves to `/var/db/automatisierung/backups/{uuid}/`
- [x] Retention policy deletes backups older than configured days
- [x] Diff view renders server-side unified diff correctly (including XML entities)
- [x] configd actions callable via `configctl automatisierung backup`
- [x] API credentials validated before saving (test connection)

## AI disclosure

Developed with **Claude Sonnet 4.6** by Anthropic (Claude Code).
