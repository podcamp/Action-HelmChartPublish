# Testing Guidelines

Primary frameworks: xUnit (for unit/integration tests) and Playwright for .NET (for browser / E2E tests)

Purpose

- Provide consistent, maintainable testing practices for the Copilot agent.
- Make tests reliable, fast where possible, and easy to run locally and in CI.
- Standardize structure, naming, test data management, and CI usage.

Scope

- Unit tests (logic, services, helpers) — xUnit.
- Integration tests (database, real services where necessary) — xUnit with isolated environments.
- Browser / E2E tests — Playwright for .NET driven by xUnit.
- Recommendations apply to test code, CI config, and PR process.

Prerequisites

- .NET SDK (same major/minor used by repo).
- Microsoft.Playwright NuGet package for Playwright tests.
- Optional: Microsoft.Playwright.CLI (dotnet tool) to install browser binaries locally:
    - dotnet tool install --global Microsoft.Playwright.CLI
    - playwright install
- Recommended local dev tools: Visual Studio / VS Code / Rider, Playwright browser devtools.

Repository layout (recommended)

- src/
    - {project code}
- tests/
    - {project}.UnitTests/         (xUnit: fast unit tests)
    - {project}.IntegrationTests/  (xUnit: integration tests, slow)
    - {project}.E2ETests/          (xUnit + Playwright: browser tests)
- tests/TestFixtures/            (shared fixtures/helpers)
- test-data/                      (static test data, sample files)

Naming conventions

- Test classes: [ClassName]Tests (e.g., UserServiceTests)
- Test files: ClassNameTests.cs
- Test methods: MethodUnderTest_StateUnderTest_ExpectedBehavior
    - Example: CreateUser_InvalidEmail_ThrowsValidationException
- E2E test methods may use a more scenario-like style:
    - Example: LoginPage_LoginWithValidUser_NavigatesToDashboard

xUnit best practices

- Use Fact for single-case tests; Theory + InlineData / MemberData for parameterized tests.
- Keep unit tests isolated — mock external dependencies (use Moq / NSubstitute).
- Prefer small, focused tests (Arrange / Act / Assert).
- Use ITestOutputHelper for per-test logs:
    - Inject ITestOutputHelper into constructor and write contextual logs.
- Avoid sleeping; use explicit waits (for integration or E2E tests).
- Group tests requiring shared expensive setup with collection fixtures to control lifecycle:
    - Use IClassFixture<TFixture> or ICollectionFixture<TFixture> when sharing expensive resources (DB container,
      Playwright browser).
- Disable parallelization for tests that share mutable global state or ports:
    - Use [CollectionDefinition("NonParallelCollection", DisableParallelization = true)]

Playwright for .NET guidelines

- Use Playwright via Microsoft.Playwright and integrate with xUnit fixtures for lifecycle management.
- Install browsers once (CI and dev machines): run `playwright install` (or `npx playwright install`) during CI setup.
- Prefer using single browser instance with isolated contexts per test:
    - Create IBrowser in a collection fixture.
    - For each test, create a new IBrowserContext and IPage to ensure isolation.
- Timeouts & waits:
    - Set reasonable default timeouts. Prefer explicit waits for element conditions (Locator.WaitForAsync /
      WaitForSelectorAsync).
    - Avoid Thread.Sleep.
- Network control & determinism:
    - Use route / request interception to stub external services when possible.
    - Seed deterministic test data for E2E.
- Headless vs headed:
    - Use headless mode in CI; allow headed in local dev via environment variable.
- Retry & flakiness:
    - Rather than blind retries, prefer fixing flakiness: ensure determinism, stable selectors, explicit waits.
    - If necessary, use a small retry wrapper at test level or rerun failed test jobs in CI with capped retries.

Example Playwright xUnit fixture (pattern)

```csharp
// BrowserFixture.cs
using Microsoft.Playwright;
using System.Threading.Tasks;
using Xunit;

public class BrowserFixture : IAsyncLifetime
{
    public IPlaywright Playwright { get; private set; }
    public IBrowser Browser { get; private set; }

    public async Task InitializeAsync()
    {
        Playwright = await Playwright.CreateAsync();
        // Optionally install browsers programmatically on first run:
        // await Playwright.InstallAsync();

        Browser = await Playwright.Chromium.LaunchAsync(new BrowserTypeLaunchOptions
        {
            Headless = true,
            // SlowMo = 50, // useful for debugging locally
        });
    }

    public async Task DisposeAsync()
    {
        if (Browser != null) await Browser.CloseAsync();
        Playwright?.Dispose();
    }
}
```

```csharp
// Example test using the fixture
using Microsoft.Playwright;
using Xunit;

[CollectionDefinition("Playwright collection")]
public class PlaywrightCollection : ICollectionFixture<BrowserFixture> { }

[Collection("Playwright collection")]
public class LoginE2ETests
{
    private readonly BrowserFixture _fixture;

    public LoginE2ETests(BrowserFixture fixture) => _fixture = fixture;

    [Fact]
    public async Task LoginPage_LoginWithValidUser_NavigatesToDashboard()
    {
        using var context = await _fixture.Browser.NewContextAsync();
        var page = await context.NewPageAsync();
        await page.GotoAsync("https://localhost:5001/login");
        await page.FillAsync("input#username", "user@example.com");
        await page.FillAsync("input#password", "P@ssw0rd");
        await page.ClickAsync("button[type=submit]");
        await page.WaitForURLAsync("**/dashboard");
        Assert.Contains("/dashboard", page.Url);
    }
}
```

Running tests locally

- Unit tests: dotnet test tests/{project}.UnitTests -c Release
- Filter tests: dotnet test --filter FullyQualifiedName~Namespace.ClassName.MethodName
- Run a single Playwright test with higher verbosity:
    - dotnet test tests/{project}.E2ETests -v n
- Playwright browser install (local & CI):
    - dotnet tool install --global Microsoft.Playwright.CLI
    - playwright install
    - Or run: dotnet test once with Playwright binaries present, or use CI step to run `playwright install` or
      `npx playwright install --with-deps`

CI recommendations (GitHub Actions example snippet)

- Important steps: setup .NET, cache NuGet, install Playwright browsers, run dotnet test, publish test
  results/artifacts.

```yaml
# .github/workflows/tests.yml (snippet)
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'
      - name: Cache NuGet
        uses: actions/cache@v4
        with:
          path: ~/.nuget/packages
          key: ${{ runner.os }}-nuget-${{ hashFiles('**/*.csproj') }}
      - name: Install Playwright browsers
        run: |
          dotnet tool install --global Microsoft.Playwright.CLI || true
          playwright install --with-deps
      - name: Run tests
        run: dotnet test --no-build -v minimal
      - name: Upload Test Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: '**/TestResults/**/*.trx'
```

Test data & secrets

- Never store secrets in repo. Use CI secrets or local env files ignored by git.
- Use environment variables for secrets and configuration:
    - Example: TEST_BASE_URL, TEST_API_KEY
- Prefer small deterministic datasets for tests. For E2E, provide seed scripts or use ephemeral test accounts.
- For integration tests using databases, use test containers, ephemeral DB instances, or in-memory DBs where possible.

Mocking and stubbing

- Unit tests: mock external dependencies (HTTP clients, DB repositories) using Moq or NSubstitute.
- Integration/E2E: prefer network stubbing at the Playwright request level for third-party dependencies, or run a local
  fake/mock service.

Timeouts and stability

- Use reasonable timeouts and set Playwright default timeout in tests if needed:
    - page.SetDefaultTimeout(10_000);
    - page.SetDefaultNavigationTimeout(30_000);
- Use retry policies for transient integration issues (ex: network or container start), but keep retries limited and
  logged.

Debugging tests

- Use logging via ITestOutputHelper or write debug dump files (screenshots, HTML dumps, videos).
- Playwright screenshot & trace helpers:
    - await page.ScreenshotAsync(new PageScreenshotOptions { Path = "screenshot.png" });
    - Consider using tracing in Playwright for complex flakiness: Start tracing and save trace for failed runs.
- To run Playwright in headed mode locally, set Headless = false or use env var:
    - new BrowserTypeLaunchOptions { Headless = Environment.GetEnvironmentVariable("HEADLESS") != "0" }

Artifacts (when tests fail)

- Capture and upload artifacts from failed E2E tests:
    - screenshots, page HTML (Page.ContentAsync()), Playwright traces, logs, video recordings (if enabled)
- Name artifacts with test name + timestamp for easier debugging.

Code review & PR checklist for tests

- Include tests that prove the change works (unit + integration/E2E if behavior affects UI).
- Tests are added/updated alongside feature code.
- Tests are deterministic and do not rely on external flaky services.
- All local tests pass before creating PR:
    - dotnet test --no-build
- CI runs green (or documented flaky tolerance).
- If E2E test added, ensure Playwright browser install step in CI is updated.
- Add test coverage expectations where relevant (coverage tool output).

Performance & test grouping

- Mark long-running tests (Integration/E2E) with a Category or Trait to allow selective runs:
    - Use [Trait("Category", "Integration")] and then run with --filter "Category=Unit"
- Keep unit tests < 50ms where possible. If not achievable, re-evaluate test scope.

Common pitfalls & how to avoid them

- Flaky selectors: prefer data-testid attributes or stable ARIA labels over fragile CSS classes.
- Network dependence: stub third-party endpoints or run mocks in CI.
- Shared state: ensure tests run in isolation (DB transactions, clean state).
- Time-based assertions: use relative waits, not fixed sleeps.

Examples quick commands

- Run all unit tests:
    - dotnet test tests/{project}.UnitTests
- Run only E2E tests:
    - dotnet test tests/{project}.E2ETests
- Run tests and collect coverage (coverlet):
    - dotnet test /p:CollectCoverage=true /p:CoverletOutputFormat=opencover

Appendix: Example test attributes & collection usage

- Disable parallelization for collections that must not run in parallel:

```csharp
[CollectionDefinition("NonParallel", DisableParallelization = true)]
public class NonParallelCollection { }

[Collection("NonParallel")]
public class SomeIntegrationTests { ... }
```

- Use IClassFixture to share context per class, ICollectionFixture to share across multiple test classes.

Closing notes

- Prioritize test reliability over quantity.
- Keep E2E tests targeted to critical flows; most business logic should be covered by fast unit tests.
- Encourage contributors to run the local test suite and include meaningful test names and logs.
