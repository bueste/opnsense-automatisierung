# [Plugin Proposal] os-automatisierung — Multi-instance OPNsense automation, backup & Zenarmor management

## Summary

I would like to propose a new plugin called **os-automatisierung** that allows managing multiple OPNsense firewall instances centrally from a single OPNsense installation.

## Problem / Use case

Organisations or individuals who run multiple OPNsense firewalls (e.g. branch offices, customer environments, home + work) currently have no built-in way to:

- Get a unified status view of all instances (firmware version, Zenarmor version, update availability)
- Apply firmware updates across all instances from one place (bulk or individually)
- Automatically back up configurations of all instances and compare diffs between versions
- Monitor Zenarmor (os-sensei) health and auto-restart the engine if it crashes

Currently this requires logging into each firewall individually, maintaining separate cron jobs, and manually downloading/comparing config.xml files.

## Proposed solution

A plugin that provides:

1. **Status dashboard** — Overview of all managed OPNsense instances: firmware version, Zenarmor version, online/offline status, pending updates
2. **One-click & scheduled firmware updates** — Trigger updates individually or in bulk; scheduled via cron
3. **Zenarmor management** — Version monitoring, update management, engine watchdog with auto-restart
4. **Configuration backup** — Periodic backup of config.xml from all managed instances, stored locally with retention policy, unified diff view between versions
5. **Secure credential management** — API key/secret per managed host, stored in OPNsense config.xml (encrypted at rest by OPNsense)

## Implementation

- **MVC/API structure** — follows OPNsense plugin conventions (ApiMutableModelControllerBase, Phalcon Volt templates)
- **Language** — English UI strings with gettext i18n; de_DE translations included; PO files for 12 additional locales (stubs)
- **License** — BSD 2-Clause
- **Backend** — Python 3 scripts registered as configd actions (`automatisierung backup`, `automatisierung watchdog`)
- **Cron** — via `/etc/cron.d/automatisierung` using `configctl` calls
- **No external dependencies** — only Python stdlib + OPNsense framework classes
- **Packaging** — Makefile + pkg-descr present for `make package`

## Repository

https://github.com/bueste/opnsense-automatisierung

## Questions / concerns I'd like to discuss

1. Is a "central manager for multiple OPNsense instances" within scope for the official plugins repository, or is this better kept as a standalone/community plugin?
2. The plugin stores API secrets of remote firewalls in config.xml (the same location OPNsense uses for all credentials). Are there additional security measures expected?
3. Is there a preferred way to ship default cron schedules (e.g. configd template approach) rather than writing to `/etc/cron.d/`?

## AI disclosure

This plugin was developed with assistance from **Claude Sonnet 4.6** by Anthropic (Claude Code).

---

*I am happy to address any review feedback and adapt the plugin to meet OPNsense contribution standards before opening a PR.*
