#!/bin/bash
# Requires bash (not sh) for ** globbing used in log cleanup.

# Root check
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

# Hypervisor selection
echo "Select hypervisor:"
echo "  1) VMware vSphere"
echo "  2) Proxmox / QEMU"
read -rp "Enter choice [1/2]: " HV_CHOICE
case "$HV_CHOICE" in
  1) GUEST_AGENT="open-vm-tools" ;;
  2) GUEST_AGENT="qemu-guest-agent" ;;
  *) echo "Invalid choice. Exiting."; exit 1 ;;
esac

# System update & cache cleanup
apt update && apt upgrade -y && apt autoremove -y && apt clean

# Install VMware guest agent
apt install -y "$GUEST_AGENT"

# For Proxmox you want to run this instead

# Clear machine ID (prevents duplicate DHCP leases)
truncate -s0 /etc/machine-id
rm /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id

# Remove SSH host keys (regenerated on first boot)
rm -f /etc/ssh/ssh_host_*

# Reset cloud-init (allows it to run on first clone boot)
if command -v cloud-init &>/dev/null; then
  cloud-init clean
else
  echo "cloud-init not installed, skipping."
fi

# Clear logs
shopt -s globstar
for log in /var/log/**/*.log /var/log/syslog; do
  [ -f "$log" ] && truncate -s0 "$log"
done

# Clear temp files
rm -rf /tmp/* /var/tmp/*

# Clear shell history
history -c
cat /dev/null > ~/.bash_history

# Done — power off (do not reboot, to avoid ID regeneration)
echo "Template preparation complete. Shutting down..."
poweroff
