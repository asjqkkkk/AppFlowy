# AppFlowy Rust Library - Claude Code Assistant Guide

This file contains important information about the AppFlowy Premium frontend Rust library workspace to help Claude work
effectively with this codebase.

## Project Overview

This is a Rust workspace containing multiple crates that power AppFlowy's frontend functionality, including user
management, documents, databases, folders, AI features, search, and more.

## Workspace Structure

Key directories:

- `frontend/appflowy_flutter/`: UI implementation in Flutter
- `flowy-*/`: Core feature crates (user, document, database, folder, AI, search, etc.). They impplement the logic for
  the flutter frontend to call.
- `lib-*/`: Library crates (dispatch, log, infra)
- `dart-ffi/`: Dart FFI bindings for Flutter integration. It use protobuf to communicate with the rust backend.
- `integration-test/`: Integration tests
- `build-tool/`: Code generation tools

## Common Cargo Commands

```bash
# Build all crates which will generate protobuf for flutter and rust. 
cargo make --profile development-mac-arm64 appflowy-core-dev
```

## Development Workflow

**IMPORTANT**: Always run these commands after making code changes:

1. `cargo fmt` - Format the code according to project standards
2. `cargo clippy` - Check for common mistakes and improvements
3. `cargo test` - Run tests to ensure nothing is broken
4. `cargo check` - Quick compilation check

## Code Style Guidelines

- Follow Rust standard naming conventions (snake_case for functions/variables, PascalCase for types)
- Use the existing code patterns in each crate
- Imports should be organized: std -> external crates -> workspace crates -> module imports
- Keep functions focused and single-purpose
- User FlowyResult for error handling

## Testing Guidelines

- Unit tests go in the same file using `#[cfg(test)]` module
- Integration tests go in `tests/` directory of each crate or in `integration-test/` crate
- Use descriptive test names that explain what is being tested
- Mock external dependencies when appropriate

## Script Updates

To update collaborative editing dependencies:

```bash
# From frontend directory:
scripts/tool/update_collab_rev.sh new_rev_id
```

To update cloud API dependencies:

```bash
# From frontend directory:
scripts/tool/update_client_api_rev.sh new_rev_id
```
