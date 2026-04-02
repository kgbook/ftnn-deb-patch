# FTNN `.deb` Distro Restriction Patch

[中文 README](./README.md)

## Background

The `preinst` script inside `FTNN_desktop_16.9.15408_amd64.deb` contains an Ubuntu version check.

This document also records a newer sample package:

- Official download URL: `https://softwaredownload.futustatic.com/FTNN_desktop_16.10.15508_amd64.deb`
- Package version: `16.10.15508`
- Local file name: `FTNN_desktop_16.10.15508_amd64.deb`

The vendor states:

`deb (for Ubuntu 18.04+ GNOME / KDE environments)`

The script reads `VERSION_ID` from `/etc/lsb-release` or `/etc/os-release`, compares it directly against `1804`, and rejects installation if the value is lower than `18.04`, with an error like:

`This package requires Ubuntu version 18.04 or later.`

The problem with that logic is:

1. It implicitly treats the current system as Ubuntu.
2. It does not verify the distro first.
3. On Debian 13, `VERSION_ID=13`, so it is incorrectly treated as lower than `18.04` and installation is blocked.

Below is the actual output of `cat /etc/os-release` on this Debian 13 machine:

```sh
PRETTY_NAME="Debian GNU/Linux 13 (trixie)"
NAME="Debian GNU/Linux"
VERSION_ID="13"
VERSION="13 (trixie)"
VERSION_CODENAME=trixie
DEBIAN_VERSION_FULL=13.3
ID=debian
HOME_URL="https://www.debian.org/"
SUPPORT_URL="https://www.debian.org/support"
BUG_REPORT_URL="https://bugs.debian.org/"
```

Because `VERSION_ID="13"` is compared numerically with `1804`, the original script misclassifies Debian 13.

## Approach

Both scripts do the following:

1. Extract the Debian control files and package payload.
2. Modify the `preinst` distro/version check.
3. Keep the `>= 18.04` check only when the detected distro is Ubuntu.
4. Skip that Ubuntu-specific restriction on Debian and other non-Ubuntu systems.
5. Rebuild a patched `.deb`.

## Original Restriction Code

This is the key logic from the original `preinst` script:

```sh
check_os_version() {
    if [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        os_version=$DISTRIB_RELEASE
    elif [ -f /etc/os-release ]; then
        . /etc/os-release
        os_version=$VERSION_ID
    else
        Log "ERROR" "Unable to determine OS version."
        exit 1
    fi

    os_version_major=$(echo $os_version | cut -d. -f1)
    os_version_minor=$(echo $os_version | cut -d. -f2)

    os_version_major=${os_version_major:-0}
    os_version_minor=${os_version_minor:-0}

    os_version_num=$((${os_version_major:-0} * 100 + ${os_version_minor:-0}))

    if [ $os_version_num -lt 1804 ]; then
        Log "ERROR" "This package requires Ubuntu version 18.04 or later. Your current version is $os_version."
        exit 1
    fi

    Log "INFO" "OS version check passed. Current version: $os_version"
}
```

## Patched Code

The scripts rewrite it to the following behavior:

```sh
check_os_version() {
    if [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        os_id=$(echo "${DISTRIB_ID:-unknown}" | tr '[:upper:]' '[:lower:]')
        os_version=$DISTRIB_RELEASE
    elif [ -f /etc/os-release ]; then
        . /etc/os-release
        os_id=$(echo "${ID:-unknown}" | tr '[:upper:]' '[:lower:]')
        os_version=$VERSION_ID
    else
        Log "ERROR" "Unable to determine OS version."
        exit 1
    fi

    os_id=${os_id:-unknown}
    os_version=${os_version:-0}

    os_version_major=$(echo $os_version | cut -d. -f1)
    os_version_minor=$(echo $os_version | cut -d. -f2)

    os_version_major=${os_version_major:-0}
    os_version_minor=${os_version_minor:-0}

    os_version_num=$((${os_version_major:-0} * 100 + ${os_version_minor:-0}))

    if [ "$os_id" = "ubuntu" ] && [ $os_version_num -lt 1804 ]; then
        Log "ERROR" "This package requires Ubuntu version 18.04 or later. Your current version is $os_version."
        exit 1
    fi

    if [ "$os_id" = "ubuntu" ]; then
        Log "INFO" "OS version check passed. Current Ubuntu version: $os_version"
    else
        Log "INFO" "Non-Ubuntu system detected ($os_id $os_version). Skipping Ubuntu 18.04 minimum version check."
    fi
}
```

That means:

- Ubuntu: the original `18.04+` requirement is still enforced
- Debian and other non-Ubuntu distros: the Ubuntu-only gate is skipped

## Scope

- Intended for FTNN desktop `.deb` packages with the same installation-time Ubuntu restriction.
- Focused on removing the incorrect Ubuntu 18.04+ gate during installation.
- The vendor still officially targets `Ubuntu 18.04+ GNOME / KDE`; this project only removes the hard distro block.
- It does not guarantee runtime compatibility for libraries, graphics, sandboxing, or desktop integration.

## Requirements

### Bash Script

- `bash`
- `python3`
- `dpkg-deb`
- `realpath`

### Python Script

- `python3`
- `dpkg-deb`

## Files

- `patch_ftnn_deb.sh`: Bash implementation
- `patch_ftnn_deb.py`: Python implementation

## Known Sample Packages

- `FTNN_desktop_16.9.15408_amd64.deb`
- `FTNN_desktop_16.10.15508_amd64.deb`

The official download URL for `16.10.15508` is:

```text
https://softwaredownload.futustatic.com/FTNN_desktop_16.10.15508_amd64.deb
```

Download command:

```bash
curl -fL --progress-bar -o ~/Downloads/FTNN_desktop.deb \
  https://softwaredownload.futustatic.com/FTNN_desktop_16.10.15508_amd64.deb
```

## Usage

### Bash

```bash
chmod +x ./patch_ftnn_deb.sh
./patch_ftnn_deb.sh FTNN_desktop.deb
```

Specify an explicit output file:

```bash
./patch_ftnn_deb.sh FTNN_desktop.deb FTNN_desktop_patched.deb
```

### Python

```bash
chmod +x ./patch_ftnn_deb.py
./patch_ftnn_deb.py FTNN_desktop.deb
```

Specify an explicit output file:

```bash
./patch_ftnn_deb.py FTNN_desktop.deb FTNN_desktop_patched.deb
```

## Output Naming

If no output path is provided, the scripts generate:

```text
original_filename_patched.deb
```

For example:

```text
FTNN_desktop_16.9.15408_amd64.deb
-> FTNN_desktop_16.9.15408_amd64_patched.deb
```

## Installation Example

After generating the patched package:

```bash
sudo apt install ./FTNN_desktop_16.9.15408_amd64_patched.deb
```

## Limitations

1. This is not a full Debian port. It only removes the incorrect Ubuntu distro gate.
2. If future `preinst` scripts change significantly, the text replacement logic may need adjustment.
3. The vendor still officially supports `Ubuntu 18.04+ GNOME / KDE`, so Debian 13 may still have unsupported runtime issues.

## Verification

After patching, inspect the control script and check for this log line:

```text
Non-Ubuntu system detected (...)
```

That indicates the installation logic now behaves as follows:

- Ubuntu: still requires `18.04+`
- Debian and other non-Ubuntu systems: skip the Ubuntu-only restriction
