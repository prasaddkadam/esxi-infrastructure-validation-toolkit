# Architecture and Design Decisions

This log records the decisions taken during the VMware lab, including constraints discovered during implementation. The original design has been retained as engineering history; the current deliverable is a **read-only ESXi health and configuration-validation toolkit**, not an Infrastructure-as-Code provisioning system.

## DD-001 — Bare-metal ESXi

**Decision:** Install ESXi directly on a dedicated x86 lab host instead of relying on nested virtualisation.

**Reason:** Provides direct access to VMkernel networking, VMFS storage, physical NIC diagnostics and hypervisor operations. Hardware brand and identifiers are omitted from the public repository.

## DD-002 — Separate administration workstation

**Decision:** Run PowerShell, VMware PowerCLI, Git and development tools on a separate personal workstation.

**Reason:** Keeps host resources available for guest workloads and separates the collection/reporting plane from the infrastructure being inspected.

## DD-003 — Standalone ESXi without vCenter

**Original decision:** Use standalone ESXi to minimise resource requirements.

**Revised assessment:** This remains appropriate for the completed read-only audit functionality. Adding vCenter would not remove the limitations of the currently assigned free ESXi host license. vCenter is not required for the revised project scope.

## DD-004 — Reserved management addressing

**Decision:** Use router-side address reservation for the ESXi management interface.

**Reason:** Offers predictable host access while leaving LAN address management on the router. The actual address, hostname, DNS domain and MAC address are not documented publicly.

## DD-005 — Resource-conscious guest design

**Decision:** Use a small guest footprint and thin-provisioned virtual disks.

**Reason:** The available VMFS datastore is limited. Guest capacity and storage usage were verified without publishing the underlying device serial/model.

## DD-006 — Free ESXi API write-access limitation (10 November 2026)

**Observation:** The assigned license was shown as **vSphere 8 Hypervisor (Free)**. PowerCLI successfully retrieved host, VM, datastore, virtual-switch and physical-NIC information. A confirmed attempt to execute `Start-VM` failed with:

```text
Current license or ESXi version prohibits execution of the requested operation.
```

**Impact:** Read-only PowerCLI collection is usable in this lab; VM power changes and normal vSphere API-based provisioning are not available with the installed entitlement. The proposed Terraform/vSphere provisioning workflow therefore did not meet a core prerequisite. Installing vCenter alone would not solve the license restriction.

**Decision:** Do not purchase a commercial vSphere license for this limited personal lab, and do not claim API-based provisioning as implemented.

**Evidence:** PowerCLI discovery/health scripts, the Host Client license screen (not published), and the rejected `Start-VM` operation.

**Lesson:** Validate the license entitlement **and perform a permitted write-operation proof-of-capability** before designing a provisioning automation project.

## DD-007 — Narrow scope to supported operations (15 November 2026)

**Decision:** Publish the working project as **VMware ESXi Infrastructure Health & Validation Toolkit**.

**In scope:** VM inventory, CPU/memory and datastore reporting, NIC snapshot comparison, configuration baseline checks and consolidated audit output using read-only API operations.

**Out of scope:** VM lifecycle provisioning, Terraform, Packer, Ansible, containerised deployment automation, vCenter, always-on monitoring and real-time alerting.

**Completion target:** One-command audit workflow, predictable error/stale-data handling, sanitised reproducible evidence and an operator guide. No unsupported VM write-API operations.

**Rationale:** Preserve verified implementation and incident evidence, finish a coherent operational deliverable, and avoid further investment in capabilities the installed license does not permit.

## DD-008 — Public repository data minimisation (15 November 2026)

**Decision:** Exclude private addresses, unique hostnames, serials, hardware models, firmware revisions and credentials from current public files. Accept runtime values for management endpoints.

**Boundary:** Redacting files in the latest commit **does not purge older Git history**. Historical commits must be separately reviewed and, if necessary, cleaned before making a privacy guarantee about the repository as a whole. Output CSVs may contain host identifiers; keep them untracked, and anonymise any published samples.
