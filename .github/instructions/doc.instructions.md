---
applyTo: "docs/**/*.md"
---

# Documentation guidelines

Purpose

- Standardize documentation structure, style, and conventions for clarity, maintainability, and usability.
- Note: If this repository isn't Talos/Kubernetes-related, adapt the technology-specific guidance accordingly.

## Documentation style & conventions

- Tone: practical, step-by-step, concise. Assume operator familiarity with SSH, kubectl, and basic networking.
- File format: Markdown (.md). Use fenced code blocks with language tags. Include commands that are copy‑paste ready and
  mark destructive steps clearly.
- Versioning: Always note the tested Talos version and Kubernetes version at the top of each guide (e.g., Talos v1.10+,
  Kubernetes v1.28).
- Commands & outputs: Where possible, include example outputs and expected results for key commands (talosctl, kubectl).
- Idempotence: Prefer idempotent instructions. If a step is not idempotent, warn and indicate recovery steps.
- Inline notes: Use NOTE / WARNING labels for important caveats (security, destructive actions, region/platform
  differences).
- Links: Prefer stable external references (Talos docs, upstream k8s docs) and indicate the date checked (YYYY-MM-DD).
  Prefer permalinks when possible.
- Header notes: At the top of each doc, include the following:
    - Tested versions: Talos vX.Y, Kubernetes v1.Z, talosctl vX.Y, kubectl v1.Z.
    - Date checked: YYYY-MM-DD.
    - Estimated time: N minutes.
    - Prerequisites: short bullets.

Testing, verification & CI

- Docs validation: Prefer simple checks like link-checking, spellcheck, and running scripts in examples/ in a sandboxed
  environment. Document how to run these checks locally. Suggested tools: markdownlint, markdown-link-check, and a
  spellchecker.
- CI: If adding GitHub Actions, include workflows that lint Markdown (markdownlint), run link checks (
  markdown-link-check), run shellcheck on scripts, and validate YAML (yamllint or kubeconform).
    - Minimal CI baseline:
        - Markdown: markdownlint
        - Links: markdown-link-check
        - YAML: yamllint or kubeconform (for Kubernetes manifests)
        - Shell: shellcheck
- Repro steps: For each guide, provide a "What I did" reproducible checklist and expected outcomes.

Security & privacy

- Explicitly warn not to commit keys, kubeconfigs, or sensitive node data. Use placeholders and describe where to store
  secrets required for examples.
- Recommend minimal privileges for example tokens and cleanup steps after test runs.
- For any remote access examples, prefer secure transports (SSH keys, restricted IP) and document how to revoke
  credentials.

Things to avoid

- Do not add operational secrets or live kubeconfigs in examples.
- Avoid platform‑specific assumptions unless stated (e.g., assume generic HomeLab networking unless the doc specifies
  UEFI vs BIOS, or virtualization platform).
- Don't introduce complex automation without documenting cleanup and rollback.
- Avoid changing temporary draft files to “final” wording—keep drafts labeled as such.

Notes for Copilot Chat (how to apply guidance)

- Treat content as "living/draft"—when updating, preserve original drafts (use versioned filenames or append -v2) unless
  asked to finalize. Include a brief "What changed" section at the top of updated drafts.
- When suggesting operational commands that can be destructive, always include a clear WARNING and a recovery
  checklist (how to revert or recreate nodes).
- Prefer minimal, copy‑paste ready commands. If a step requires local environment variables or secrets, state them as
  placeholders and note where to store them for CI.
- If adding automation or publishing steps, include explicit cleanup and rollback instructions for HomeLab use.
- When generating files, remember this repo targets Windows and PowerShell 7+; ensure paths and commands are
  compatible.
