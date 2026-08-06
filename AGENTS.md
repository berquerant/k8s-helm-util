# AGENTS.md

This document provides guidelines and essential context for AI agents working on the `k8s-helm-util` codebase.

---

## 1. Overview & Purpose

`k8s-helm-util` is a collection of Bash utility scripts designed to simplify, validate, and automate operations with **Kubernetes Helm** and **Helmfile**.

Key capabilities include:
- **Fetching & Unpacking**: Downloading remote or copying local Helm charts (`fetch.sh`).
- **Linting & Schema Validation**: Automatically generating `values.schema.json` via `helm-schema` prior to running `helm lint` (`lint.sh`).
- **Value Computation**: Evaluating fully merged `.Values` using Helm templating or raw `yq` merging (`compute-values.sh`).
- **CLI Argument Generation**: Extracting dependency definitions (`dep-args.sh`) or reconstructing Helm CLI flags from `helmfile.yaml` (`helmfile-args.sh`).
- **Helmfile Integration**: Serving as a wrapper binary for `helmfile lint` to ensure schema validation (`helmfile-lint-helm.sh`).

---

## 2. Repository Architecture & Core Scripts

```
.
├── Makefile                     # Build, test, lint (shellcheck) execution targets
├── Dockerfile                   # Isolated testing environment with all required binaries
├── common.sh                    # Shared utility functions (logging, tempdir, schema generation)
├── fetch.sh                     # Fetches or copies Helm charts
├── lint.sh                      # Lints charts after auto-generating values schema
├── compute-values.sh            # Computes final merged Helm values (template-based or raw)
├── dep-args.sh                  # Builds CLI flags for subchart dependencies
├── helmfile-args.sh             # Reconstructs Helm CLI flags from helmfile.yaml
├── helmfile-lint-helm.sh        # Helm binary wrapper for helmfile linting
├── renovate.json                # Dependency update configuration
├── scripts/
│   └── install_deps.sh          # Installs fixed tool versions (helm, yq, helm-schema, helmfile)
└── tests/
    ├── run_tests.sh             # Test suite execution runner
    ├── test_helper.sh           # Test assertion framework
    └── test_*.sh                # Feature-specific unit and integration tests
```

---

## 3. Script Reference & Key Behaviors

### `common.sh`
Shared helper library. Key functions include:
- `log`: Standardized stderr logging.
- `debug`: Conditional logging enabled when `DEBUG` environment variable is set.
- `tempdir`: Creates a temporary directory (automatically registered for cleanup if `DEBUG` is set).
- `run_with_debug`: Logs command before execution.
- `find_version`: Parses `--version` argument from argument array.
- `build_schema`: Invokes `helm-schema` if `values.schema.json` does not exist in the chart directory.

### `fetch.sh CHART DEST_DIR [VERSION]`
- If `CHART` starts with `/` or `./`, performs local directory copy.
- Otherwise, runs `helm fetch --version VERSION --untar` to extract the chart into `DEST_DIR`.

### `lint.sh CHART [helm lint options...]`
- Downloads/copies chart to a temporary directory.
- Automatically generates `values.schema.json` if missing.
- Filters out `--version` arguments and forwards remaining flags to `helm lint`.

### `compute-values.sh CHART [helm template options...]` / `compute-values.sh r|raw values.yaml...`
- **Default Mode**: Creates a temporary template `{{ toYaml .Values }}` inside the fetched chart and runs `helm template --show-only` to output the final evaluated `.Values` object.
- **Raw Mode (`r` / `raw`)**: Uses `yq` (`. as $item ireduce ({}; . * $item )`) to deep-merge multiple `values.yaml` files in order.

### `dep-args.sh CHART VERSION DEPNAME`
- Inspects `dependencies` in the chart's metadata using `helm show chart`.
- Outputs CLI arguments to target the specified dependency (supports both HTTP repositories `--repo URL` and OCI registries `oci://...`).

### `helmfile-args.sh RELEASE_NAME [STATE]`
- Parses `helmfile.yaml` (or specified state file) for the given release name.
- Resolves chart name, version, and repository configuration (handling OCI flag).
- Returns Helm CLI arguments (e.g. `--repo URL chartname --version X` or `oci://...`).

### `helmfile-lint-helm.sh`
- Designed to be passed to `helmfile` via `-b helmfile-lint-helm.sh`.
- For `lint` subcommands, runs `build_schema` before delegating execution to `helm`.
- Passes through all other subcommands directly to `helm`.

---

## 4. Development Workflow & Verification

All testing and linting rely on the Docker container (`Dockerfile`) to guarantee consistent tool versions (`helm`, `yq`, `helmfile`, `helm-schema`, `shellcheck`).

### Execution Commands (`Makefile`)

- **Build Test Docker Image**:
  ```bash
  make build
  ```
- **Run All Test Suites**:
  ```bash
  make test
  ```
- **Run ShellCheck Analysis** (via `lint` or `shellcheck` targets):
  ```bash
  make lint
  # or
  make shellcheck
  ```

> **Mandatory Rule for AI Agents**: Always run `make test` and `make lint` (or `make shellcheck`) and ensure zero failures before concluding any task.

---

## 5. Coding Standards & Conventions

1. **Interpreter & Error Directives**:
   - Every executable script must start with `#!/bin/bash`.
   - Enable strict pipeline and error flags:
     ```bash
     set -e
     set -o pipefail
     ```
2. **Include Common Infrastructure**:
   - Source `common.sh` using relative directory resolution:
     ```bash
     d="$(cd "$(dirname "$0")" || exit 1; pwd)"
     . "${d}/common.sh"
     ```
3. **Variable Scoping & Immutability**:
   - Use `local` or `local -r` for function-scoped variables.
   - Use `readonly` for top-level immutable script variables.
4. **CLI Help & Argument Handling**:
   - Include a `usage()` function printing usage instructions to stderr on `-h`/`--help` or invalid arguments.
5. **ShellCheck Compliance**:
   - Maintain 100% compliance with `shellcheck`. Use explicit disable comments (e.g., `# shellcheck disable=SC...`) only when technically necessary and justified.

---

## 6. Testing Guidelines

- **Test Suite Structure**: Located in `tests/`. New functionality must be accompanied by tests in `tests/test_<feature>.sh`.
- **Test Framework**: Use assertion helpers from [`tests/test_helper.sh`](./tests/test_helper.sh):
  - `assert_equals "want" "got" "test description"`
  - `assert_contains "$output" "expected substring" "test description"`
  - `assert_exit_code 0 $exit_code "test description"`
- **Completion**: Ensure `print_test_summary` is called at the end of each test script.
