# NOTE: The order of these entries matters. We search them
# from start to finish and only match based on whether they appear in a
# system target. This means that entries like "vm" would match all cases
# of "vm-bootloader", "vm-no-gui", and "vmware". To avoid this mismatch,
# entries should be ordered from most-specific to least-specific.
[
  "amazon"
  "azure"
  "cloudstack"
  "docker"
  "do"
  "gce"
  "install-iso-hyperv"
  "hyperv"
  "install-iso"
  "iso"
  "kexec"
  "kexec-bundle"
  "kubevirt"
  "proxmox-lxc"
  "lxc-metadata"
  "lxc"
  "openstack"
  "proxmox"
  "qcow"
  "raw-efi"
  "raw"
  "sd-aarch64-installer"
  "sd-aarch64"
  "vagrant-virtualbox"
  "virtualbox"
  "vm-bootloader"
  "vm-nogui"
  "vmware"
  "vm"
]
