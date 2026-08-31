# Repository Agent Guide

## Ownership

- Humans and agents may change `main` only through a reviewed pull request.
- Kargo is the sole normal writer to `kargo/*`.
- Never open, merge, or automate a pull request from a generated branch.
- Never force-push, rebase, squash, or manually repair a generated branch.

## Generated output

Each `kargo/<stage>` branch contains exactly:

- `.kargo/freight.yaml`: immutable Freight/source/image provenance.
- `apps/<application>/manifest.yaml`: fully rendered Kubernetes YAML.

Do not add Helm values, Kustomizations, source code, credentials, or workflows
to generated branches. A retry must produce a normal descendant commit. If a
promotion conflicts, stop and repair the writer/ownership problem instead of
forcing the branch.

## Promotion contract

The only supported deployment path is `lab/main` merge, successful immutable
image publication, Kargo Freight discovery, exact automatic Stage promotion,
generated branch commit, Argo CD sync/health, and Kargo verification.

Do not create SHA-bump pull requests, release branches, deployment pull
requests, manual Argo syncs, direct Kubernetes applies, or alternate writers.

`main` changes must keep `contract/inventory.yaml`, the provenance schema, the
validators, and the repository rulesets consistent. Generated output must pass
`scripts/validate_output.rb` before it is accepted as a migration seed.
