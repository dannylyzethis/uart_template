# Project Instructions for AI Agents

This file provides instructions and context for AI coding agents working on this project.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:6cd5cc61 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.

## Agent Context Profiles

The managed Beads block is task-tracking guidance, not permission to override repository, user, or orchestrator instructions.

- **Conservative (default)**: Use `bd` for task tracking. Do not run git commits, git pushes, or Dolt remote sync unless explicitly asked. At handoff, report changed files, validation, and suggested next commands.
- **Minimal**: Keep tool instruction files as pointers to `bd prime`; use the same conservative git policy unless active instructions say otherwise.
- **Team-maintainer**: Only when the repository explicitly opts in, agents may close beads, run quality gates, commit, and push as part of session close. A current "do not commit" or "do not push" instruction still wins.

## Session Completion

This protocol applies when ending a Beads implementation workflow. It is subordinate to explicit user, repository, and orchestrator instructions.

1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Handle git/sync by active profile**:
   ```bash
   # Conservative/minimal/default: report status and proposed commands; wait for approval.
   git status

   # Team-maintainer opt-in only, unless current instructions forbid it:
   git pull --rebase
   git push
   git status
   ```
5. **Hand off** - Summarize changes, validation, issue status, and any blocked sync/commit/push step

**Critical rules:**
- Explicit user or orchestrator instructions override this Beads block.
- Do not commit or push without clear authority from the active profile or the current user request.
- If a required sync or push is blocked, stop and report the exact command and error.
<!-- END BEADS INTEGRATION -->


## Build & Test

```bash
make test-host          # offline Python packet tests (runs anywhere)
make sim-regression     # ModelSim: cd simulation && vsim -c -do "do run_regression.do"
make synth              # Quartus compile for 10M08SAE144C8G (quartus/uart_max10_top)
make check-cdc          # after fitting: quartus_sta -t quartus/check_cdc.tcl
```

Simulation and fitting run through the ModelSim and Quartus MCP servers on the
user's Windows machine (see `docs/FPGA_VALIDATION.md` for the exact calls). They
are not available in cloud sessions, so mark HDL changes as unverified until the
regression has been run. Keep the ModelSim project files (`simulation/*.mpf`,
`*.cr.mti`) in the repo.

## Architecture Overview

UART register bridge for FPGA instrument control (MAX 10, 50 MHz), kept as a
**template**: registers 0x00-0x05 and 0x10-0x15 are general-purpose slots to be
assigned per design.

```
uart_max10_top
 |- reset_synchronizer
 |- uart_register_interface (protocol FSM, sticky errors, strobes)
 |   |- uart_core, sync_byte_fifo (RX), sync_byte_fifo (TX)
 |- i2c_master x2, spi_master x2
```

Packets: command `[DEV][CMD][ADDR][DATA x8][CRC8]`, reply `[DEV][0x02][DATA x8][CRC8]`.
See `docs/UART_Register_Interface_Specification.md`.

## Conventions & Patterns

- Template, not a design: do not hard-wire meanings into the general-purpose registers.
- Memory and flash safety: the design uses M9K RAM only (volatile). Never write
  the on-chip UFM/CFM at runtime; `DEVICE_ADDRESS` stays a compile-time constant.
  Planned persistent data (e.g. LUTs) loads from an external EEPROM with a magic
  number, version and CRC, and falls back safely if the check fails.
- `src/simple_i2c_spi_module.vhd` is a legacy stub that redefines `i2c_master` and
  `spi_master`. It is intentionally kept; do not add it to compile scripts.
- Comments and docs are plain ASCII/UTF-8; avoid non-ASCII in VHDL sources.
