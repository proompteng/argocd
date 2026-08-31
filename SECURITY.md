# Security Policy

Do not commit credentials, tokens, private keys, unsealed application secrets,
or private registry authentication to this repository.

Report a vulnerability privately with GitHub's **Report a vulnerability**
feature under the repository Security tab. Do not disclose sensitive findings
in a public issue or pull request.

Generated manifests may contain SealedSecret ciphertext and documented
non-secret chart sentinels. The validator rejects nonempty native Secrets except
the explicitly validated JupyterHub chart sentinel object.
