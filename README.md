# Single-GPU AMD Passthrough with Libvirt Hooks

A clean, working setup for single-GPU passthrough on AMD Radeon cards (tested with Navi 23 / RX 6600) using libvirt hooks. The host releases the GPU when the VM starts and reclaims it cleanly when the VM stops.

## Requirements

- AMD GPU (this method was developed around Navi 23, but should work on similar cards)
- IOMMU enabled in BIOS and kernel (`amd_iommu=on` or equivalent)
- libvirt + QEMU with a VM configured for PCI passthrough
- The GPU devices set to `managed='no'` in the domain XML

## Why `managed='no'`?

With `managed='yes'`, libvirt attempts to handle device binding itself. Combined with AMD’s reset behaviour, this often leaves the card in a bad state after the VM shuts down. Setting `managed='no'` gives the hooks full control.

## Installation

1. Copy the hook dispatcher:

```bash
sudo cp hooks/qemu /etc/libvirt/hooks/qemu
sudo chmod +x /etc/libvirt/hooks/qemu
```

2. Create the directory structure for your VM (replace `your-vm-name`):

```bash
sudo mkdir -p /etc/libvirt/hooks/qemu.d/your-vm-name/prepare/begin
sudo mkdir -p /etc/libvirt/hooks/qemu.d/your-vm-name/release/end
```

3. Copy the scripts:

```bash
sudo cp hooks/qemu.d/example-vm/prepare/begin/start.sh \
  /etc/libvirt/hooks/qemu.d/your-vm-name/prepare/begin/start.sh

sudo cp hooks/qemu.d/example-vm/release/end/stop.sh \
  /etc/libvirt/hooks/qemu.d/your-vm-name/release/end/stop.sh
```

4. Edit the scripts and set your PCI addresses and display manager (see Configuration below).

5. Make them executable:

```bash
sudo chmod +x /etc/libvirt/hooks/qemu.d/your-vm-name/prepare/begin/start.sh
sudo chmod +x /etc/libvirt/hooks/qemu.d/your-vm-name/release/end/stop.sh
```

6. Restart libvirt:

```bash
sudo systemctl restart libvirtd
```

## Configuration

Edit the top of both `start.sh` and `stop.sh` and set:

| Variable          | Example                  | Description                     |
|-------------------|--------------------------|---------------------------------|
| `GPU_VIDEO`       | `pci_0000_08_00_0`       | Video function of the GPU       |
| `GPU_AUDIO`       | `pci_0000_08_00_1`       | HDMI/DP audio function          |
| `DISPLAY_MANAGER` | `gdm`                    | `gdm`, `sddm`, `lightdm`, etc.  |

Find your PCI addresses with:

```bash
lspci -nnk | grep -A3 -E 'VGA|Audio'
```

Convert `08:00.0` → `pci_0000_08_00_0`.

## Domain XML

Ensure both hostdev entries use `managed='no'`:

```xml
<hostdev mode='subsystem' type='pci' managed='no'>
  <source>
    <address domain='0x0000' bus='0x08' slot='0x00' function='0x0'/>
  </source>
</hostdev>
```

## How it works

**On VM start (`start.sh`)**  
- Stops the display manager  
- Unloads `amdgpu` and `snd_hda_intel`  
- Detaches the devices with `virsh nodedev-detach`  
- Loads `vfio-pci`

**On VM stop (`stop.sh`)**  
- Unloads VFIO modules  
- Removes the PCI devices from the bus (forces a reset)  
- Rescans the PCI bus  
- Reloads `amdgpu` and `snd_hda_intel`  
- Starts the display manager

The remove + rescan step is the key that reliably returns Navi cards to the host.

## Troubleshooting

- **VM fails to start with “Unmanaged PCI device must be manually detached”**  
  The hook is not running. Confirm `/etc/libvirt/hooks/qemu` exists and is executable, and that the scripts under `qemu.d/` are executable.

- **Screen does not return after shutdown**  
  Check `journalctl -u libvirtd -b` for hook output. Ensure `managed='no'` is set and that the PCI addresses in the scripts match your hardware.

- **Black screen on host after reboot**  
  Boot with `amdgpu` blacklisted temporarily or use SSH to fix the hooks.

## Notes

- This is a single-GPU setup. The host display is stopped while the VM is running.
- Tested on Fedora with GNOME/GDM. Other distributions should work with minor changes to the display manager name.
- No vendor-reset module is required with the remove + rescan method.

## Licence

MIT