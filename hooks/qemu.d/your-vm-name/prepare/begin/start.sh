#!/bin/bash
set -x

# Para o GDM
systemctl stop gdm

# Descarrega drivers do host
modprobe -r amdgpu
modprobe -r snd_hda_intel

# Desvincula os devices
virsh nodedev-detach pci_0000_08_00_0
virsh nodedev-detach pci_0000_08_00_1

# Carrega vfio
modprobe vfio-pci