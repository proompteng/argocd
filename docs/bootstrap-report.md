# Output Repository Bootstrap Report

Snapshot: `2026-08-31T00:18:21Z`

Repository: <https://github.com/proompteng/argocd>

Bootstrap pull request: <https://github.com/proompteng/argocd/pull/1>

## Repository controls

- Ruleset `21887743` protects `main` with pull requests, the required `validate` check, linear history, and deletion and force-push prevention.
- Ruleset `21887744` protects `kargo/*` from creation, ordinary updates, deletion, and force-pushes. It has no human bypass.
- The dedicated `proompteng-kargo-delivery` GitHub App is not registered. GitHub does not expose initial App registration through `gh` or its REST/GraphQL APIs; its manifest registration flow is web-initiated and automatically generates a private key, which this phase explicitly forbids. Consequently, generated branches remain deliberately locked until that later credential phase registers the App and adds its Integration ID as the sole ruleset bypass.

## Generated branches

| Stage | Applications | Seed commit |
| --- | --- | --- |
| `agents` | `agents` | `ae3691f16fd4cc3e19e12a5514d306a2a430a271` |
| `analysis` | `analysis` | `1ce2ccaee0fe171d69e1c5f58a569819ebc5982a` |
| `app` | `app` | `b9d0273feedb10ac130fe12fc71febcab351a8c3` |
| `arc-runner` | `arc` | `1a5d90bfea80aaf32b0fecb092c0b815d840677e` |
| `attic` | `attic` | `456538c9fd7a5ad93887c13c1e6f103fb609d23c` |
| `bumba` | `bumba` | `62dbd5ae4489cc22814641f31bd971b33d1a7bb8` |
| `buzz` | `buzz` | `b1d7ec0ec919f2cacbeaf0b3700055d43e46f567` |
| `docs` | `docs` | `c48db71880925243a62570d6ca5c0ccadefd9138` |
| `froussard` | `froussard` | `c5f57e3bb9d826062924775bd272e1897cf8e7cf` |
| `headlamp` | `headlamp` | `a6b567f7276d31a698e9106b1873a68738332ded` |
| `hermes-toolchain` | `hermes` | `7f2a47872015c947ac736bcb0058b04032916dc8` |
| `jangar` | `jangar` | `eca42fec89e85453724f57515cfa5bdc14731adf` |
| `oirat` | `oirat` | `af3b6ed875e00f10daf6a1f6b226101fe9599c72` |
| `proompteng` | `proompteng` | `f6093a095748ba9e3c458f327cabd890436974d1` |
| `symphony` | `symphony`, `symphony-jangar` | `3060e63d087044bc693886b91898362c13e11bcb` |
| `synthesis` | `synthesis` | `b2dfa741d53e10a26e8d311a6ba76edccdb06818` |
| `tengri` | `tengri` | `6d4fee3385c9fc556d102812a6705a91dfc54fb8` |
| `torghut` | `torghut` | `10084312b8e7a71fe8f97ad3f8c8a621a44938c6` |

No `kargo/bilig` branch was created.

## Validation evidence

- 18 generated Stage branches and 19 Application manifests passed the repository validator.
- Canonical comparison against current Argo desired state passed for all 385 objects.
- No rendered `Namespace` objects or duplicate resource identities were found.
- All Kargo-selected application images matched Freight and were pinned by `sha256` digest.
- Kubeconform found 385 resources: 232 valid, 0 invalid, 0 errors, and 153 custom resources skipped because no upstream schema was available.
- Namespace-correct Kubernetes server-side dry-run passed for all 19 manifests without applying resources.
- Native Secret validation allows empty certificate placeholders and only one nonempty object: the exact documented `torghut/torghut-notebooks-hub` chart sentinels.

## Cutover blockers retained

- Bilig remains `Unknown/Healthy`; Stage `bilig` is `Ready=False`, reason `NoFreight`. It has no output branch.
- Torghut remains `Synced/Progressing`; Stage readiness, health, and verification are `Unknown`. Its output was seeded for parity only.
- Current desired state contains nine third-party image references that use tags rather than digests. They were retained to preserve exact parity and are reported by the validator; the `lab` source must pin or explicitly govern them before hard cutover.

This report records output-repository preparation only. Argo CD and Kargo still read and write `proompteng/lab`; no deployment cutover occurred.
