# proompteng/argocd

Public, generated Kubernetes desired state for Argo CD. Kargo owns every
`kargo/<stage>` branch. Humans own `main`.

## Repository contract

- `main` contains documentation, validation, and the delivery inventory.
- `kargo/<stage>` contains only `.kargo/freight.yaml` and
  `apps/<application>/manifest.yaml`.
- Generated branches are deployment records. They are never merged into `main`,
  and pull requests are never used for promotion.
- Kargo updates a generated branch with an ordinary fast-forward commit. Force
  pushes are forbidden.
- Argo CD consumes fully rendered YAML from the generated branch. Helm,
  Kustomize, and config-management plugins do not run against this repository.

The intended delivery path is:

```text
lab/main merge -> immutable multi-arch image -> Kargo Freight
  -> automatic Stage promotion -> kargo/<stage> commit
  -> Argo CD exact-revision sync -> health and verification
```

`proompteng/lab` remains the authored source repository. This repository is an
output store, not a second source of authored configuration.

## Validation

Validate the human-maintained contract:

```bash
ruby scripts/validate_contract.rb
ruby tests/contract_test.rb
```

Validate a generated branch from a separate checkout:

```bash
ruby scripts/validate_output.rb \
  --inventory contract/inventory.yaml \
  --root /path/to/generated-branch \
  --stage proompteng
```

See [AGENTS.md](AGENTS.md) before changing repository automation.
