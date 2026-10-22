# Debian PHP package update cheatsheet

This branch contains the PHP package update procedure for Debian 11, 12 and 13, using the repository provided by [packages.sury.org](https://packages.sury.org/php/).

> [!WARNING]
> Do **not** run this procedure unattended or execute it blindly as a shell script. It is intended to be reviewed and used interactively, usually by copying command blocks into a shell. Read the [Debian release notes](https://www.debian.org/releases/stable/releasenotes) before upgrading.

If you are not experienced with maintaining and upgrading Debian-based systems, do not use this cheatsheet without appropriate help.

## Scope

The procedure is maintained in [`update-php-packages.sury.org.sh`](update-php-packages.sury.org.sh). It covers package updates involving PHP packages from Sury and the surrounding package-management steps.

**Branch-specific note:** the commands and findings described here apply only to the `update-php-packages.sury.org` branch. Other branches in this repository document different upgrade paths and may contain substantially different code.

## Usage notes

- Review every command and its expected effect before running it.
- Keep the session interactive so APT and package-maintainer scripts can ask questions when needed.
- The script records an upgrade session for later review; verify the recording behavior on the target Debian system before relying on it.
- The procedure changes APT preferences under `/etc/apt/preferences.d/` to influence PHP package selection. Understand and verify the resulting candidate versions before proceeding.
- Review the package plan and available disk space before confirming an upgrade.
- Keep a current backup and ensure you have a recovery path before changing system packages.

This cheatsheet is not a substitute for the official Debian release notes or for checking the actual package state of the machine being upgraded.

## Other upgrade procedures

The repository's [main README](https://github.com/waja/debian-update-cheatsheets/blob/main/README.md) lists the other release-upgrade branches.
