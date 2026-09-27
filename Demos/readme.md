# Infrastructure as Documentation — Demo Code

Aurora's haunted forest, and the way out. Companion code for *Infrastructure as
Documentation*, DevOpsCon New York, September 29, 2026.

```
Demos/
├─ readme.md            ← you are here
├─ aurora-before/
│  └─ networking.tf     ← 1,100 lines. One file. Storage account on line 847.
└─ aurora-after/
   ├─ main.tf           ← root composition, four boundaries wired by contract
   ├─ variables.tf
   ├─ outputs.tf
   └─ modules/
      ├─ network/       ← private-app-network: VNet, subnets, NSGs. Full stop.
      ├─ compute/       ← app-tier-compute: instances, no public IPs
      ├─ security/      ← app-tier-secrets: Key Vault, TLS 1.2 floor
      └─ observability/ ← network-flow-logs: the storage account, given a home
```

Everything here is fictitious. Aurora is not a real company, the CIDRs are
RFC 1918, and no real credential appears in either tree.

---

## The before file

`aurora-before/networking.tf` is exactly **1,100 lines**, and
`azurerm_storage_account "logs"` begins on **line 847** — the number you say
out loud on slide 11. Open it at the top and scroll: the 24 near-identical NSG
rules between lines 202 and 537 are what makes the scroll feel as long on stage
as it felt to Priya.

Useful on stage:

```bash
wc -l aurora-before/networking.tf                       # 1100
sed -n '847,856p' aurora-before/networking.tf           # the reveal
grep -c 'azurerm_network_security_rule' aurora-before/networking.tf
grep -n 'resource "azurerm_' aurora-before/networking.tf | wc -l
```

### Crime map

| Line | What's there | Slide | The crime |
|-----:|---|---|---|
| 1–6 | Three stacked `TODO: split this up` comments, 2022 → 2024 | 2 | Intent leaking one commit at a time |
| 26 | `variable "env"`, default `"prod"`, no description, no validation | 10 | Crime #1 — is `staging` the same as `stg`? |
| 31 | `variable "region"`, `default = "eastus"`, no rationale | 25 | The region assumption nobody decided |
| 71 | `variable "admin_password"`, default `"ChangeMe123!"` | 33 | The one the audience gasps at |
| 96 | `variable "allowed_source"`, default `"*"` — never referenced | 33 | Dead variable, live confusion |
| 100 | `variable "legacy_mode"`, default `true` | 3 | Governance living in a flag |
| 130 | `resource "azurerm_virtual_network" "main_vnet"` | 10, 20 | Crime #2 — the name is a lie |
| 138–158 | `subnet1`, `subnet2`, `subnet3` | 29 | App tier, data tier, management — in creation order, and that order is the contract |
| 160 | `subnet_new`, comment: *added for the thing in Q3* | 27 | The comment that raises more questions than it answers |
| 169–186 | `sg1`, `sg2`, `sg3` | 33 | Naming crimes |
| 202–537 | 24 copy-pasted `azurerm_network_security_rule` blocks | 2 | "Priya scrolls. And scrolls." |
| 538 | `rt_default` | 33 | Naming crimes |
| 562 | `r3`, comment: *do not remove, breaks the old DR path* | 3 | Tribal knowledge as a comment |
| 581–608 | `pip_001`, `pip_002`, `pip_003`, `pip_lb` | 33 | Naming crimes |
| 643–740 | NICs, 3 Linux VMs, a Windows jumpbox, managed disks | 27 | Boundary crime — compute in a networking module |
| 657 | VM with `disable_password_authentication = false` | 25 | The assumption that public IPs and passwords were fine |
| 685 | Jumpbox NIC with a public IP | 25 | "The infrastructure team sent a memo. The IaC didn't get the memo." |
| 744–782 | `azurerm_key_vault` + access policies + the VM password as a secret | 27 | Boundary crime — identity in a networking module |
| 801–845 | A commented-out application gateway, *left this here in case we need to roll back — MP, 2023-09-28* | 3 | Code as a graveyard |
| **847** | **`azurerm_storage_account "logs"`** — no tags, no comment, `min_tls_version = "TLS1_0"`, nested items public | **11, 27** | **"Wait… it creates a storage account?"** |
| 889 | Diagnostic setting pointing at it — the only thing that does | 27 | Why nobody noticed |
| 925 | `temp_nat`, *remove after the migration (ticket AUR-2291)* | 3 | Temporary, in production, indefinitely |
| 943–1026 | Six more copy-pasted NSG rules, `rule_025`–`rule_030`, stranded past the storage account | 27 | Nobody reads this far. That's how line 847 survived. |
| 1027 | A commented-out `azurerm_network_watcher_flow_log`, *disabled 2021-06-03 — compliance moved to the central workspace (DK)* | 34 | **The payoff.** This is what "after a fair amount of investigation" found. The flow log requirement went away. The storage account stayed. |
| 1044 | `output "resource_ids"` — flat list of nine unrelated IDs | 33 | Output crime — implementation exposed wholesale |
| 1058 | `output "all_subnet_ids"` — `[app, data, management]` | 29, 30 | Add a DMZ subnet, shift every index, break three modules at 11 PM on a Friday |
| 1094 | `output "admin_password"` | 33 | Left as a closing gift for the room |

**Stage tip for line 1027.** If you want the investigation beat to land, don't
scroll there. Run this and let the whole story arrive as one screen of output:

```bash
grep -n 'flow_log\|storage_account' aurora-before/networking.tf
```

Two variables nobody uses at lines 75 and 80. A live storage account at 847.
A dead, commented-out flow log at 1028 with a 2021 date on it. The requirement
went away five years ago; the storage account is still in production.

---

## The after tree

`aurora-after/` is the six-step teardown from slides 34–35, finished.

| Step | Where to look |
|---|---|
| 1. Identify the intent | `modules/network/main.tf`, lines 1–15 — the purpose and scope header, written before the first resource block |
| 2. Extract boundaries | `modules/compute/`, `modules/security/`, `modules/observability/` — the VMs, the vault, and the storage account, each in the boundary that owns it |
| 3. Rename for intent | `private_app_network`, `app_tier_allow_https`, `data_tier_deny_public`, `management_corp_only` |
| 4. Surface assumptions | `modules/network/variables.tf` — `deployment_environment` with no default and a validation block, `region` constrained to the three approved regions, every description explaining *why* |
| 5. Outputs as contracts | `modules/network/outputs.tf` — `app_tier_subnet_id`, `data_tier_subnet_id`, `management_subnet_id`, each with a description naming its consumer and its invariants. No `resource_ids`. No list to index into. |
| 6. Show the diff | see below |

The comment-deletion test from slide 23 passes on this tree: strip every
comment and the names still carry the intent. Try it live if you have the time
for it —

```bash
grep -v '^\s*#' aurora-after/modules/network/main.tf | grep 'resource "'
```

### Side-by-side on stage

```bash
# the shape of the thing
wc -l aurora-before/networking.tf
find aurora-after -name '*.tf' | xargs wc -l | tail -1

# the same boundary, before and after
grep -n 'main_vnet\|"sg1"\|"sg2"' aurora-before/networking.tf
grep -n 'private_app_network"\|app_tier_allow_https\|data_tier_deny_public' aurora-after/modules/network/main.tf

# outputs: a dump versus a contract
sed -n '1044,1065p' aurora-before/networking.tf
sed -n '1,40p'      aurora-after/modules/network/outputs.tf
```

### One deliberate difference from slide 35

Slide 35 shows `minimum_tls_version` inside the `private-app-network` module.
In this tree it lives in `modules/security/variables.tf` and
`modules/observability/variables.tf` — the two boundaries that actually own a
resource with a TLS setting. Both carry the description and the SP-2023-04
reference exactly as the slide has it. If you'd rather the code match the slide
literally, move the variable; if someone in the room notices the difference,
it's a free thirty seconds on Pattern 3, since a network module owning a TLS
floor for a resource it doesn't create is the same boundary mistake in
miniature.

---

## Neither tree is meant to run

Both are `terraform validate`-shaped but deliberately not deployable: no
backend, no subscription, no real key material. `aurora-before/networking.tf`
would fail a `terraform plan` for the same reasons it fails a human — and if
you want that failure on stage, it's an honest one.
