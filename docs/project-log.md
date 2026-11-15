# Project Log

## 2026-11-01 — VMware Platform Foundation

### Objective

Establish the physical VMware host and create a stable baseline before deploying virtual machines or introducing automation.

### Platform

- hybrid-core x86 processor
- Lab RAM (capacity withheld)
- NVMe (capacity withheld) SSD
- onboard Gigabit Ethernet NIC 1 GbE
- VMware ESXi 8

### Implemented

- Enabled Intel VT-x and VT-d
- Installed VMware ESXi directly on the physical host
- Configured the ESXi hostname and FQDN
- Configured management networking
- Created a DHCP reservation for the management interface
- Verified gateway and external network connectivity
- Configured DNS
- Configured and verified NTP synchronisation
- Validated the VMFS datastore
- Examined the ESXi virtual networking architecture
- Enabled SSH for administrative testing

### Troubleshooting

The ESXi installer initially encountered two boot-related problems:

1. UEFI Secure Boot prevented the installation media from starting.
2. ESXi generated a CPU uniformity PSOD because of the Intel hybrid P-core/E-core architecture.

The CPU compatibility issue was resolved using:

`cpuUniformityHardCheckPanic=FALSE`

The setting was subsequently configured persistently.

### Verification

Validated:

- ESXi Host Client access
- SSH access
- Physical NIC status
- 1 GbE network link
- VMkernel management interface
- Default route
- Internet connectivity
- DNS resolution
- NTP synchronisation
- VMFS datastore availability

### Next Milestone

Deploy the first virtual machine manually and record the configuration decisions that will later become automation candidates.

---

## 2026-11-08 — ESXi Network Remediation

### Objective

Restore reliable ESXi management connectivity to enable
deployment of the first Linux virtual machine.

### Investigation

- Diagnosed failed SCP and datastore ISO uploads.
- Identified receive CRC errors and physical NIC link drops.
- Isolated cables, switch, router ports and workstation interfaces.
- Compared ESXi `ne1000` against Ubuntu Live `e1000e`.
- Validated approximately 749 Mbit/s throughput under Ubuntu.

### Remediation

Updated the lab host firmware from an earlier revision to a newer revision; identifying version details withheld.

Saved ESXi TPM encryption recovery material and generated
a host configuration backup before performing firmware maintenance.

### Verification

- ESXi booted successfully.
- 100 MB SCP transfer completed.
- Ubuntu Server ISO uploaded successfully.

### Outcome

The firmware change initially restored transfers needed for the Stage 2 VM deployment. Subsequent ESXi NIC errors recurred; the incident remains open for monitoring.

### Incident Report

[INC-001 — ESXi Network Instability](incidents/INC-001-esxi-network-instability.md)

### Next Milestone

Deploy and configure LINUX01.

---

## 2026-11-09 — First Linux VM Manual Deployment

### Objective

Create, configure and validate the first virtual machine as a repeatable manual baseline for subsequent infrastructure automation.

### Implemented

- Built `LINUX01` on standalone ESXi 8.0.3 using 2 vCPU, 2 GB RAM and a 25 GB thin-provisioned VMDK.
- Attached Ubuntu Server 24.04.5 LTS ISO and configured EFI, PVSCSI, VMXNET3 and the `VM Network` port group.
- Installed Ubuntu Server with DHCP, LVM, an administrative account and OpenSSH.
- Completed package updates and verified `open-vm-tools` 13.0.10.0.

### Verification

- Guest boots, logs in and reports hostname `linux01`.
- SSH works from the Windows management workstation.
- `open-vm-tools.service` is active.
- `lsblk` confirms the 25 GB virtual disk and EFI/boot/LVM partitions.
- No Ubuntu reboot was required following updates.

### Issues and Follow-up

An earlier installation attempt failed during `apt-get update` while the ESXi management uplink was unstable. The first VM was removed and rebuilt, and the second installation completed. Physical NIC stability is still under observation: [INC-001](incidents/INC-001-esxi-network-instability.md).

### Documentation

[Stage 2 — Manual Infrastructure Baseline](stages/02-manual-infrastructure-baseline.md).

### Next Milestone (historical)

Develop repeatable host/VM discovery and validation using PowerCLI, while continuing to monitor ESXi physical networking.

---

## 2026-11-09 to 2026-11-10 — PowerCLI inventory and health reporting

### Objective

Implement repeatable, read-only discovery and diagnostic checks for the ESXi platform.

### Implemented

- `01-Get-VMInventory.ps1`: VM configuration inventory exported to CSV and re-imported for verification.
- `02-Get-ESXiHostHealth.ps1`: host CPU/memory, datastore and physical NIC counters with timestamped CSV reports.
- `03-Compare-NICHealth.ps1`: compare two NIC snapshots, calculate receive-error deltas and flag possible counter resets.
- `04-Test-LabBaseline.ps1`: 20 checks for ESXi, datastore, port groups and the sample virtual machine.
- `05-Get-LabReport.ps1`: consolidated CSV status for host, storage, network and configuration.

### Verification

- All 20 baseline checks passed in the healthy configuration sample.
- An actual NIC comparison identified +37 receive-length errors and +37 missed errors, with no new CRC or packet-drop errors in that interval.
- The consolidated report produced overall `WARNING` because of the network finding, while the remaining checks passed.

### Limitations

The scripts initially used lab-specific identifiers and require further hardening; the public source now requires runtime values for host addressing. The current report consumes periodic snapshots rather than continuous telemetry, and does not yet enforce input freshness.

## 2026-11-10 — VMware API write-access constraint identified

### Finding

PowerCLI `Start-VM` was rejected with: `Current license or ESXi version prohibits execution of the requested operation.` Host Client licensing identified the assigned edition as vSphere 8 Hypervisor (Free).

### Decision

Stop VM lifecycle/terraform provisioning work through the restricted ESXi API. Retain the supported read-only collection and baseline-validation functionality and record the entitlement prerequisite in [DD-006](design-decisions.md).

## 2026-11-15 — Public toolkit scope and data sanitisation

### Objective

Finish the existing working engineering deliverables as a focused **VMware ESXi Infrastructure Health & Validation Toolkit**.

### Changes

- Replaced the old multi-tool IaC delivery promises in the README.
- Removed embedded private management addressing from active PowerCLI source and selected runtime parameters.
- Generalised identifying host hardware and firmware details in public documents.
- Recorded licensing and privacy architecture decisions in [Design Decisions](design-decisions.md).

### Remaining work

Finalise a one-command read-only audit runner, input/staleness checks, a small test/evidence package and operating instructions. This project does not claim VM provisioning or real-time monitoring. Older Git commits can still contain prior metadata; current-file redaction is not a rewrite of historical commits.
