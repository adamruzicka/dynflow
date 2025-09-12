# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Dynflow is a Ruby workflow engine that allows for asynchronous execution, progress tracking, error recovery, and workflow composition. It's designed to support distributed execution with features like:

- Workflow orchestration with plan/run/finalize phases
- Asynchronous execution with persistence
- Error recovery and resumption capabilities
- Step concurrency detection and parallel execution
- Middleware support for extending behavior
- Multiple backend adapters (database, coordinator, executor)

## Development Commands

Use bundler for all Ruby commands:

### Testing
- `bundle exec rake test` - Run the full test suite (default task)
- `bundle exec rake` - Same as above (default)

### Code Quality
- `bundle exec rubocop` - Run RuboCop linting (uses theforeman-rubocop configuration)
- `bundle exec rubocop --auto-correct` - Auto-fix RuboCop violations

### Database Setup
The test suite supports multiple databases via `DB_CONN_STRING` environment variable:
- SQLite (default): `sqlite:/`
- PostgreSQL: `postgres://postgres@localhost/travis_ci_test`
- MySQL: `mysql2://root@127.0.0.1/travis_ci_test`

### Examples
Run example workflows from the `examples/` directory:
- `ruby examples/orchestrate.rb` - Basic workflow orchestration
- `ruby examples/orchestrate_evented.rb` - Event-driven workflows with suspension
- `ruby examples/remote_executor.rb` - Remote execution patterns

## Architecture

### Core Components

**Action**: Base class (`Dynflow::Action`) - the fundamental building block for workflows. Actions have three phases:
- Plan phase: constructs execution plan (`plan` method)
- Run phase: executes the work (`run` method) 
- Finalize phase: cleanup/recording (`finalize` method)

**World**: Central orchestrator (`Dynflow::World`) that coordinates all components:
- Manages persistence, coordination, execution, and middleware
- Contains executor, dispatcher, coordinator, and clock
- Entry point for triggering workflows

**ExecutionPlan**: Represents a complete workflow with dependency graph and flow definitions for run/finalize phases.

**Executor**: Executes planned workflows, supports parallel execution across multiple workers/processes.

**Persistence**: Handles storage via adapter pattern (primarily Sequel-based database adapter).

### Key Patterns

**Three-Phase Execution**: Every action participates in plan → run → finalize lifecycle.

**Subscription Model**: Actions can subscribe to other actions for automatic inclusion in workflows.

**Flow Composition**: Flows define execution order - Sequence (serial), Concurrence (parallel), Atom (single step).

**Middleware Stack**: Extensible middleware system for cross-cutting concerns (transactions, logging, etc).

**Adapter Pattern**: Pluggable adapters for persistence, coordination, logging, executors, and transactions.

### File Organization

- `lib/dynflow/` - Core library code
  - `action.rb` - Base Action class and extensions
  - `world.rb` - Main World orchestrator
  - `execution_plan.rb` - Workflow representation
  - `flows/` - Flow composition classes
  - `executors/` - Execution engines
  - `persistence_adapters/` - Storage backends
  - `middleware/` - Middleware components
- `test/` - Minitest-based test suite with custom helpers
- `examples/` - Working examples demonstrating features
- `web/` - Web console for monitoring (Sinatra-based)

## Testing Patterns

Tests use Minitest with custom helpers in `test_helper.rb`:
- `WorldFactory` for creating test worlds with proper cleanup
- `TestPause` for step-by-step workflow inspection
- `PlanAssertions` for workflow validation
- Concurrent execution testing utilities
- Database adapter testing across multiple backends

The test suite includes comprehensive integration tests that exercise full workflows end-to-end, not just unit tests.