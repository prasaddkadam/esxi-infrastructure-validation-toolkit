# Stage 2 — Manual Infrastructure Baseline

## Objective

Deploy and verify the first virtual machine manually on the existing standalone ESXi host. Record the infrastructure and guest configuration as a baseline for supported read-only PowerCLI inventory, configuration validation and diagnostics.

**Milestone date:** 9 November 2026  
**VM:** `LINUX01`  
**Milestone:** First Linux VM installed and verified; physical ESXi NIC stability remains under observation (see [INC-001](../incidents/INC-001-esxi-network-instability.md)).

## 1. ESXi VM configuration

| Component | Configured value |
|---|---|
| Hypervisor | VMware ESXi 8.0.3, build 24677879 |
| VM name | `LINUX01` |
| Virtual hardware compatibility | ESXi 8.0 U2 virtual machine |
| Guest OS selection | Ubuntu Linux (64-bit) |
| Installed OS | Ubuntu Server 24.04.5 LTS |
| vCPU | 2 |
| Memory | 2048 MB |
| Datastore | `datastore1` (VMFS-6) |
| Disk | 25 GB VMDK |
| Provisioning | Thin |
| Disk mode | Dependent |
| SCSI controller | VMware Paravirtual (PVSCSI) |
| Virtual NIC | VMXNET3 |
| Port group | `VM Network` |
| Virtual firmware | EFI |
| VM UEFI Secure Boot | Disabled for initial lab build |
| Installation source | `[datastore1] ISOs/ubuntu-24.04.5-live-server-amd64.iso` |
| CD/DVD after installation | Installation ISO disconnected |

The management interface `vmk0` and VM port group share `vSwitch0` and physical uplink `vmnic0`. Each VM has its own virtual NIC/MAC address, even though the ESXi host uses one physical Ethernet port.

## 2. Guest installation decisions

- Standard Ubuntu Server installation, not minimised.
- Guest network configured via DHCP; no HTTP proxy.
- Default Ubuntu archive mirror; repository connectivity test passed.
- Guided storage using the full virtual disk with LVM; LUKS encryption not enabled.
- Hostname: `linux01`; administration account: `labadmin` (sudo).
- OpenSSH Server installed; password login initially enabled for lab onboarding.
- No featured server snaps selected.
- The installation ISO was disconnected before the first successful boot from VMDK.

**Security:** Passwords, SSH secrets and recovery keys are not stored in this repository. SSH is for the trusted lab LAN; no public router port-forwarding is required. Key-based SSH authentication is a later improvement.

## 3. Virtual disk and Linux storage layout

The 25 GB VMDK is exposed to Ubuntu as `/dev/sda`.

| Guest device / mount | Approximate size | Purpose |
|---|---:|---|
| `/dev/sda1` → `/boot/efi` | 1 GB | EFI System Partition |
| `/dev/sda2` → `/boot` | 2 GB | Boot filesystem |
| `/dev/sda3` | 21.9 GB | LVM physical volume |
| `ubuntu-vg/ubuntu-lv` → `/` | 11 GB | ext4 root filesystem |
| Unallocated volume-group capacity | ~10.9 GB | Future LVM expansion exercise |

At initial validation, `df -h` showed approximately 4.7 GB used and 5.5 GB available on `/` (46% utilised). Free space within the LVM volume group is different from free space within the mounted root filesystem.

## 4. Guest network and administration

The guest virtual NIC was recognised as `ens34`, configured via DHCP. At verification it held `[guest IP redacted]`; this is a **temporary observed lease**, not a guaranteed static address.

The management workstation successfully connected using:

```powershell
ssh labadmin@<LINUX01-IP>
```

Ubuntu 24.04 OpenSSH is configured with systemd socket activation: `ssh.socket` can listen and start `ssh.service` when a connection arrives. `ssh.service` was observed active after a successful remote login. Its `disabled` unit state alone was not a failure.

## 5. VMware guest integration

Ubuntu's `open-vm-tools` package was updated through APT and verified:

```bash
vmware-toolbox-cmd -v
systemctl status open-vm-tools --no-pager
systemctl list-units --type=service | grep -i vm
```

Observed version: **13.0.10.0 (build-25056151)**. `open-vm-tools.service` and `vgauth.service` were active. VMware Tools is guest-managed through Ubuntu packages; an ESXi Host Client message such as *VMware Tools is not managed by vSphere* does not mean the guest service is absent.

## 6. Verification evidence

| Test | Observed result |
|---|---|
| VM boots from virtual disk | Passed |
| Ubuntu login with `labadmin` | Passed |
| `whoami` | `labadmin` |
| `hostnamectl` | `linux01`; Ubuntu 24.04.5 LTS |
| `ip -br addr` | `ens34` up, DHCP IPv4 address |
| SSH from Windows management laptop | Passed |
| `sudo apt update` | Passed; repository metadata fetched |
| Ubuntu package update | Completed; no reboot required |
| `open-vm-tools.service` | Active (running) |
| `vmware-toolbox-cmd -v` | 13.0.10.0 |
| `lsblk` / `df -h` | Expected 25 GB disk, EFI/boot/LVM layout |

The initial installation attempt failed while configuring APT (`apt-get update`, exit status 100), alongside recurring host connectivity interruptions. The VM was removed and rebuilt; the subsequent installation and verification succeeded. The causal relationship between the guest APT failure and the ESXi NIC issue was **not conclusively proven**.

## 7. Host networking caveat — INC-001

After updating the physical host BIOS from an earlier to a newer revision, a 100 MB SCP transfer and full Ubuntu ISO upload succeeded. However, later guest installation activity coincided with renewed ESXi management interruptions, physical `vmnic0` link events, and increased error counters (including 415 cumulative CRC errors on one earlier sample).

The host BIOS setting **PCI Express Power Management** was subsequently disabled as a controlled experiment. The rebuilt Ubuntu VM installed successfully; in a later ESXi sample, CRC errors were zero, while receive length/missed errors were 38 each. This **does not yet establish a durable fix**. Continue monitoring and do not mark the NIC issue permanently resolved based only on the successful VM build.

See [INC-001 — ESXi Management Network Instability](../incidents/INC-001-esxi-network-instability.md).

## 8. Read-only audit and configuration candidates

The manual installation established objects that could be inspected by PowerCLI:

| Infrastructure component | Implemented read-only check |
|---|---|
| VM resources | Inventory of VM name, vCPU, RAM and power state |
| Virtual disk | Validate configured size and thin provisioning |
| Virtual networking | Inspect virtual NIC type and port group |
| Datastore | Inspect type, capacity and free space |
| ESXi host | Capture CPU/memory and physical NIC counters |
| Expected VM configuration | Compare current values with a documented baseline |
| Repeated health samples | Calculate NIC error-counter changes |

These capabilities were implemented and tested in the five PowerCLI scripts under [`powercli/`](../../powercli/). They do **not** create, power on or modify virtual machines via the restricted vSphere API.

## 9. Stage outcome

**Manual Linux VM deployment: completed and verified.** A subsequent licensing check identified that the assigned free ESXi license blocks PowerCLI API write operations. The deliverable was therefore narrowed to read-only infrastructure auditing, monitoring snapshots and configuration validation.

The earlier deployment details in this stage are retained as the historical lab baseline. The physical NIC fault remains in monitoring: [INC-001](../incidents/INC-001-esxi-network-instability.md). See [DD-006 and DD-007](../design-decisions.md) for the later project scope decision.
