# Main instructions for GitHub Copilot

In this file you can find the main instructions for GitHub Copilot to assist with code suggestions and generation.

# Other instructions files

- See `.github/instructions/branching.instructions.md`, if exists, for branching strategy.
- See `.github/instructions/commit.instructions.md`, if exists, for commit and PR message guidelines.
- See `.github/instructions/doc.instructions.md`, if exists, for documentation guidelines.
- See `.github/instructions/testing.instructions.md`, if exists, for testing guidelines.
- See `.github/instructions/layout.instructions.md`, if exists, for project structure and layout guidelines.
- See `.github/instructions/ci.instructions.md`, if exists, for CI/CD guidelines.

## Preferred response style

- Be concise and action-oriented. In case of ambiguity, ask clarifying questions.
- When suggesting code, prefer idiomatic typical of the framework in use (e.g., PowerShell for PowerShell modules) and
  follow the style/conventions outlined above.
- When adding constants or configuration files always check for existing patterns in the repo first, and if adding new
  ones, keep them minimal, documented and don't forget to substitute the hardcoded value on the other files.
- When suggesting CLI or CI snippets, include the minimal working example and note required secrets or environment
  variables.
- When giving examples, state assumptions (PowerShell version, OS compatibility) and any follow-ups (e.g., credentials
  needed for integration tests).
- When executed command considered you are using a PowerShell 7+ environment, unless specified otherwise.

### Language & translation

- Default to English for responses and new content.
- If you detect non-English text in the repository or prompt, warn about it and propose an English translation alongside
  the original.
- Preserve technical terms/names; note where meaning is ambiguous.
- Do not overwrite existing non-English content without confirmation; prefer adding an "English translation" section.
- Flag that translations may need human review for nuance.

## Maintainers & contacts

- Primary maintainers: @nicola-preden
- For policy exceptions, security concerns, or architecture changes: open an RFC or issue and tag the maintainers.

## Specific Repository Instructions

This is a Template repository, update the instructions below to match the project if needed.