# Operator Guide — ESXi Infrastructure Health & Validation Toolkit

This guide describes the **read-only** standalone ESXi audit as tested in a personal lab. It does not create, modify, start, or stop virtual machines.

## Requirements

- PowerShell 7 on the management workstation
- VMware PowerCLI commands accessible through `VCF.PowerCLI` or `VMware.VimAutomation.Core`
- Network connectivity to a standalone ESXi host and a permitted read-only management session
- A VM already present on the host, configured to match the baseline defined in `04-Test-LabBaseline.ps1`

The baseline currently expects ESXi 8.0.3, `datastore1` (VMFS), `vSwitch0`, management and VM port groups on VLAN 0, and a 2-vCPU / 2-GB / 25-GB thin-provisioned VM with VMXNET3. These are **lab-specific requirements**, not universally correct ESXi standards. Supplying a different VM name alone does not change these expected values.

## Execute an audit

From the repository root:

```powershell
$ESXiServer = Read-Host 'ESXi management hostname or IP'
$VMName = Read-Host 'VM name to validate'

./powercli/Invoke-ESXiAudit.ps1 -ESXiServer $ESXiServer -VMName $VMName
```

Avoid putting real addresses, passwords or configuration exports into Git-tracked files. The ESXi host address is passed at runtime. Authentication may prompt interactively; do not publish credentials or console captures containing them.

### Report locations

By default the workspace output is kept **outside the Git repository**, as a sibling folder:

```text
<workspace>/output/
├── history/<host-key>/latest-NIC.csv
└── runs/<host-key>/audit-<timestamp>-<id>/
    ├── VM-Inventory.csv
    ├── ESXi-HostHealth-*.csv
    ├── ESXi-DatastoreHealth-*.csv
    ├── ESXi-NICHealth-*.csv
    ├── ESXi-Baseline-*.csv
    ├── ESXi-NICComparison-*.csv       # present only with valid prior data
    └── ESXi-LabReport-*.csv
```

The host key is a truncated hash used to separate NIC history; it is not a security boundary or encryption. Use a private directory for output. Raw inventory/report files can contain hostnames, IP addresses, VM names and operational details.

## Interpret status values

| Status | Meaning | Operator action |
|---|---|---|
| `PASS` | All available evaluated checks passed | Retain report as evidence for this measurement interval |
| `WARNING` | Resource threshold reached, NIC error count increased, or NIC counter reset detected | Inspect affected metric and repeat measurement as necessary |
| `FAIL` | Explicit configuration mismatch or disconnected host | Inspect affected check and configuration before claiming a healthy baseline |
| `UNKNOWN` | Missing, malformed, out-of-date or otherwise inconclusive evidence | Obtain valid fresh data; do **not** interpret as healthy |

The consolidated status prioritises **FAIL → UNKNOWN → WARNING → PASS**. Thus a warning may be present while the overall result is `UNKNOWN` when other critical evidence is missing.

A first audit has no previous NIC snapshot. It reports `UNKNOWN` for NIC comparison by design. A later audit compares NIC cumulative counters if the previous snapshot is more recent than 48 hours (configurable by `-MaxNICSnapshotAgeHours`). A negative delta is treated as `RESET_OR_WRAP`, not as zero errors.

The consolidator's `-MaxReportAgeMinutes` defaults to **60 minutes**. Expired/invalid host, storage, current NIC, and baseline timestamps are marked `UNKNOWN`. Source timestamps reflect observations, not continuous telemetry. Comparisons alone do not establish a cause of link flaps.

## Test coverage and examples

The sanitized example CSV files under [`examples/`](../examples/) illustrate:

- [PASS](../examples/audit-PASS.csv): completed live run with no new NIC errors
- [WARNING](../examples/audit-WARNING.csv): live NIC counter increase
- [FAIL](../examples/audit-FAIL.csv): *synthetic* vCPU mismatch
- [UNKNOWN](../examples/audit-UNKNOWN.csv): missing or stale inputs (the stale host date is illustrative)

The PASS and WARNING values were transcribed and anonymised from actual lab reports. They do not include the real management address or host inventory. FAIL and UNKNOWN are derived from controlled local fixtures, **not actual guest drift or live host failure**. These files are **illustrations of consolidated output**, not replayable collector fixtures.

## Troubleshooting

**PowerCLI unavailable:** Runner checks required VMware commands before beginning. Verify `Get-Command Connect-VIServer`, `Get-Module -ListAvailable VCF.PowerCLI,VMware.VimAutomation.Core`, and load/install the required module under an approved PowerShell execution policy.

**Unsigned script blocked:** Check `Get-ExecutionPolicy -List`. Local policy may require signed scripts. If permitted, use `Set-ExecutionPolicy -Scope Process RemoteSigned` and inspect the script before running it. Do not circumvent organisation-enforced policy.

**First run is UNKNOWN:** Run again after a measurement interval. No NIC error-free claim is supported without a previous comparable sample.

**NIC WARNING:** Review CRC/length/missed/dropped deltas, logs and the incident record [INC-001](incidents/INC-001-esxi-network-instability.md). A `NO_NEW_ERRORS` interval does not prove permanent NIC stability.

**Baseline FAIL:** Compare expected values in `04-Test-LabBaseline.ps1` to the target lab before assuming a defect. It is a specific lab baseline rather than a generic VMware compliance policy.

**Output missing or expired:** Rerun the audit and examine source timestamps. The report may produce `UNKNOWN` when required CSVs are not available or fresh.

## Limitations

- Free ESXi licensing permits the exercised read-only operations but blocked the tested `Start-VM` write API call.
- Baseline values are hardcoded for this lab. This is not a general multi-environment policy engine.
- The toolkit uses snapshots, not scheduled monitoring, event collection, alerts or dashboards.
- NIC history is limited to the last completed collection per host. Comparison requires counters from the same host and NIC labels; no automated physical-link diagnosis is provided.
- Operational reliability is limited by host connectivity, data quality and permissions. No production readiness claim is made.

## Public evidence hygiene

Review every raw CSV, screenshot, recording and console capture for management IPs, VM and host names, MAC/serial identifiers, site/network details, credentials and recovery keys **before publishing**. Public sanitisation of current files does not erase historical Git commits. Historical privacy review must be completed separately before asserting that repository history is anonymous.
