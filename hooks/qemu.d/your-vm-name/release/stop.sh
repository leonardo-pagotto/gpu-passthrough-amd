#!/bin/bash
set -x

# Descarrega vfio
modprobe -r vfio-pci
modprobe -r vfio_iommu_type1
modprobe -r vfio

# Remove os devices do bus PCI (força reset)
echo 1 > /sys/bus/pci/devices/0000:08:00.0/remove
echo 1 > /sys/bus/pci/devices/0000:08:00.1/remove

# Redescobre
sleep 1
echo 1 > /sys/bus/pci/rescan

# Recarrega drivers
modprobe amdgpu
modprobe snd_hda_intel

# Sobe o GDM
systemctl start gdm