# Ubuntu Server VM Template Preparation

A shell script to prepare an Ubuntu Server machine for use as a VM template on either VMware vSphere or Proxmox/QEMU.

## Usage

```bash
chmod +x prepare_vm_template.sh
sudo ./prepare_vm_template.sh
```

The script must be run as root. On startup it will prompt for the target hypervisor, then run fully unattended through to poweroff — do not reboot manually, as this would regenerate identifiers that were intentionally cleared.

## What it does

### Hypervisor selection
The script prompts for the target hypervisor at runtime and installs the appropriate guest agent:
- **VMware vSphere** → `open-vm-tools`: enables graceful shutdown, IP address reporting in the vCenter summary view, and guest OS customization.
- **Proxmox / QEMU** → `qemu-guest-agent`: enables graceful shutdown, IP address reporting in the Proxmox summary view, and live migration support.

### System update & cache cleanup
Updates all packages and removes the local apt package cache (`apt clean`), so downloaded `.deb` files are not baked into the template disk and inherited by every clone.

### Machine ID
`/etc/machine-id` is cleared rather than deleted. This is intentional: `systemd-networkd` uses the machine ID, not the MAC address, to generate the [DHCP Unique Identifier (DUID)](https://manpages.ubuntu.com/manpages/focal/man5/networkd.conf.5.html). The default `ClientIdentifier` is [`duid`](https://manpages.ubuntu.com/manpages/focal/man5/systemd.network.5.html), meaning all clones with the same `machine-id` will receive the same DHCP lease regardless of having different MAC addresses. A new ID is generated automatically on first boot. See also: [real-world account of the problem on Ubuntu 20.04](https://techblog.jeppson.org/2020/05/ubuntu-20-04-cloned-vm-same-dhcp-ip-fix/).

### SSH host keys
Removed so that each clone generates its own unique host keys on first boot. Clones sharing host keys would cause SSH client warnings and pose a security risk.

### cloud-init reset
If cloud-init is installed, `cloud-init clean` resets its state so it runs again on first boot of each clone. Without this, cloud-init considers itself already done and skips first-boot configuration entirely. If cloud-init is not installed the step is skipped gracefully. See: [cloud-init docs](https://cloudinit.readthedocs.io/en/latest/reference/cli.html#clean).

### Log & temp cleanup
Truncates (rather than deletes) log files, which preserves file descriptors held by running services. Temp directories are cleared to reduce template disk size.

## Requirements

- **bash** (not sh) — the script uses `globstar` (`**`) for recursive log file matching, which is a bash-only feature.
- Ubuntu Server 20.04 LTS or later.

## After the script

Once the machine has powered off, convert it to a template in your hypervisor:
- **vSphere**: right-click the VM → **Template** → **Convert to Template**
- **Proxmox**: right-click the VM → **Convert to Template**
