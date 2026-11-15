# VMware ESXi Infrastructure Health & Validation Toolkit

A **read-only ESXi infrastructure audit and diagnostics project** built using PowerShell 7 and VMware PowerCLI. It captures VM inventory, ESXi host utilisation, datastore health, and physical NIC counters; compares network snapshots; validates a lab configuration baseline; and produces consolidated CSV evidence.

**Scope:** Audit, diagnostics, configuration validation and operational reporting. This repository does **not** implement Terraform, automated VM provisioning, or guest configuration management.

## Implemented tools

| Script | Function | Verified evidence |
|---|---|---|
| [01-Get-VMInventory.ps1](powercli/01-Get-VMInventory.ps1) | Export VM power, compute, disk and NIC inventory | CSV produced and re-imported |
| [02-Get-ESXiHostHealth.ps1](powercli/02-Get-ESXiHostHealth.ps1) | Sample host CPU/RAM, datastore and physical NIC counters | Timestamped CSV reports |
| [03-Compare-NICHealth.ps1](powercli/03-Compare-NICHealth.ps1) | Compare NIC snapshots and identify error-counter increases | Detected a receive error increase |
| [04-Test-LabBaseline.ps1](powercli/04-Test-LabBaseline.ps1) | Compare ESXi, networking, storage and VM settings against the lab baseline | 20/20 checks passed |
| [05-Get-LabReport.ps1](powercli/05-Get-LabReport.ps1) | Consolidate latest available health and baseline data | Reported a network warning alongside passing checks |
| [Invoke-ESXiAudit.ps1](powercli/Invoke-ESXiAudit.ps1) | Isolate and orchestrate all five scripts; reuse per-host NIC history | Implemented; awaiting live verification |

The five original scripts have been tested individually. A [single-command audit runner](powercli/Invoke-ESXiAudit.ps1) is implemented on this feature branch and **requires live verification before release**. This is periodic snapshot analysis, **not** live monitoring.

## Architecture

```text
Personal management workstation
   PowerShell 7 + PowerCLI + Git
                |
         Read-only vSphere API
                |
        Standalone VMware ESXi
                |
    +-----------+-----------+
    |           |           |
  Host/VM    VMFS storage  vSwitch/uplink
 inventory    monitoring   NIC counters
    +-----------+-----------+
                |
       Timestamped CSV reports
                |
     Delta / baseline validation
                |
       Consolidated audit report
```

Physical host manufacturer/model, hardware identifiers, exact capacity, management addressing and private naming are intentionally omitted from public documentation. The lab uses a small dedicated x86 host with a hybrid-core CPU and an onboard Ethernet adapter.

## Run the tools

### Prerequisites

- PowerShell 7 and VMware PowerCLI on a management workstation
- A reachable standalone ESXi host and permission for the required read-only API queries
- An output directory writable by the PowerShell user
- Review script prerequisites before running: baseline expected CPU, disk and network settings are currently tailored to one sample VM; supply its name at runtime

### Recommended: run one audit

The newly added runner is read-only and generates a separate directory for each run:

```powershell
$ESXiServer = Read-Host 'Enter the ESXi hostname or IP'
$VMName = Read-Host 'Enter the VM name to validate'
./powercli/Invoke-ESXiAudit.ps1 -ESXiServer $ESXiServer -VMName $VMName
```

For the **first run**, no previous NIC snapshot exists, so the network comparison reports `UNKNOWN` rather than inventing a clean result. Subsequent runs compare with this host's prior completed snapshot when it is less than 48 hours old. Each run creates its own folder under the workspace `output/runs/` directory; its latest NIC snapshot is preserved under `output/history/`. Both directories are outside source control by default. The script does not modify the hypervisor.

The report remains a snapshot-based audit, not a continuously scheduled service. First-run and second-run integration testing passed on the personal lab.

### Report freshness (F3 branch — awaiting verification)

The consolidated reporting script now treats host, storage, and current NIC samples older than 60 minutes (by source timestamp) as `UNKNOWN`. A stale or malformed baseline filename is also marked `UNKNOWN`. Historical NIC comparison timestamps may be older; only the current NIC sample is subject to the report freshness threshold.

```powershell
./powercli/05-Get-LabReport.ps1 -OutputDirectory $TestDir -MaxReportAgeMinutes 60
```

This change has not yet been verified in the user's Windows environment.

### Individual scripts

The host address is provided **at runtime** and is not stored in the source files:

```powershell
$ESXiServer = Read-Host 'Enter the ESXi management hostname or IP'
Connect-VIServer -Server $ESXiServer

./powercli/01-Get-VMInventory.ps1 -ESXiServer $ESXiServer
./powercli/02-Get-ESXiHostHealth.ps1 -ESXiServer $ESXiServer

# Take another NIC snapshot after a measurement interval.
./powercli/02-Get-ESXiHostHealth.ps1 -ESXiServer $ESXiServer
./powercli/03-Compare-NICHealth.ps1

$VMName = Read-Host 'Enter the lab VM name'
./powercli/04-Test-LabBaseline.ps1 -ESXiServer $ESXiServer -VMName $VMName
./powercli/05-Get-LabReport.ps1
```

Scripts write CSVs into the `output/` folder alongside the local repository workspace (not committed). Use measured timestamps when interpreting a report: the consolidated script does not yet enforce snapshot age.

## Real diagnostic investigation: INC-001

The ESXi host experienced intermittent management-transfer failures, received-packet errors and link events. The investigation included physical-path isolation, ESXi NIC counters, kernel logs, a firmware maintenance change and a cross-operating-system comparison using a Linux live environment.

Under Linux, an `iperf3` test measured approximately **749 Mbit/s** over 30 seconds without corresponding NIC errors. ESXi continued to exhibit intermittent receive anomalies. The precise fault mechanism and a durable fix have **not** been established.

In a subsequent comparison, the PowerCLI scripts identified **37 additional receive-length errors** and **37 additional receive-missed errors** while other infrastructure checks passed. The consolidated status was appropriately `WARNING`.

[Read the incident investigation](docs/incidents/INC-001-esxi-network-instability.md).

## Licensing boundary

The lab uses **vSphere 8 Hypervisor (Free)**. Read-only PowerCLI queries have been verified, but a test `Start-VM` operation was rejected with a license/API restriction. **VM creation, power operations and Terraform provisioning through the vSphere API are not claimed in this project.** Virtual machines were originally installed manually using the ESXi Host Client.

[See the architecture decisions](docs/design-decisions.md).

## Repository

```text
.
├── README.md
├── .gitignore
├── powercli/
│   ├── 01-Get-VMInventory.ps1
│   ├── 02-Get-ESXiHostHealth.ps1
│   ├── 03-Compare-NICHealth.ps1
│   ├── 04-Test-LabBaseline.ps1
│   ├── 05-Get-LabReport.ps1
│   └── Invoke-ESXiAudit.ps1
└── docs/
    ├── design-decisions.md
    ├── project-log.md
    ├── troubleshooting.md
    ├── incidents/
    │   └── INC-001-esxi-network-instability.md
    └── stages/
        ├── 01-platform-foundation.md
        └── 02-manual-infrastructure-baseline.md
```

## Engineering records

- [Design decisions](docs/design-decisions.md)
- [Project log](docs/project-log.md)
- [NIC compatibility investigation](docs/incidents/INC-001-esxi-network-instability.md)
- [Platform foundation](docs/stages/01-platform-foundation.md)
- [Manual VM baseline](docs/stages/02-manual-infrastructure-baseline.md)
- [Troubleshooting](docs/troubleshooting.md)

## Finalisation scope

Remaining work: live verification of the audit runner, additional robust handling of missing/stale data, reproducible checks, sanitised sample output and an operating guide. No additional hypervisor, VM deployment framework or commercial licensing is required for the planned read-only deliverable.

## Privacy and security

The published files intentionally avoid private IP addresses, unique host naming, MAC addresses, serial numbers, exact physical hardware models and firmware revisions. Never commit secrets, credentials, exports with internal network details or real recovery keys. This is a personal lab, not employer infrastructure.
