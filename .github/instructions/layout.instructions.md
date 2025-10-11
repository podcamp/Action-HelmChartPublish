# Repository Layout Guidelines

Purpose

- General repository layout.

Repository layout (recommended)
The recommended layout uses a Clean Architecture approach with separate folders for source code, tests, and test data;
and
follows Milan Jovanovic's style.

- docs/                       (documentation, architecture, design, normally in markdown or a docsify app)
- src/
    - Domain/                     (core entities, interfaces)
    - Application/                (business logic, services)
    - Infrastructure/             (data access, external services)
        - API/                    (API layer, controllers)
        - Web/                    (web app, UI)
        - CLI/                    (command-line interface if needed)
    - SharedKernel/               (shared utilities, constants)
    - {Other}/                    (other layers as needed)
- tests/
    - {LayerName}.UnitTests/         (xUnit: fast unit tests)
    - {LayerName}.IntegrationTests/  (xUnit: integration tests, slow)
    - {LayerName}.FunctionalTests/   (xUnit: functional tests, end-to-end within a layer)
    - {LayerName}.ArchitectureTests/ (ArchUnitNET: architecture rules)
    - {LayerName}.E2ETests/          (xUnit + Playwright: browser tests)
- scripts/                   (build, deployment, utility scripts)
- bin/                       (build output, optional)
- obj/                       (intermediate build files, optional)
- Directory.Build.props      (shared build settings)
- .editorconfig              (code style settings)
- README.md
- docker-compose.yml
- docker-compose.override.yml

Notes:

- This is a general .NET layout; adapt as needed for other languages or frameworks.
- The Presentation layer (API, Web, CLI) can be all or one of them and normally contains a Dockerfile to build the
  image.
- Tests depend on the type of project; for example, a class library may not have E2E tests.
- .editorconfig is recommended to enforce consistent code style across the project; other ecosystems may use different
  files (e.g., .prettierrc for JavaScript).
