
Sandbox Testing Harness
What it is
A local, engine-agnostic harness that lets an AI coding agent modify and test application code against a disposable copy of a database — with hard guarantees that it can never (a) leak data off the machine or (b) cause irreversible changes to real code or real data. The only thing that crosses back to a human is a reviewable patch plus a test report; you apply the changes yourself.

It's a developer tool, optimized for safety, reproducibility, and clarity over performance. The current build is a PostgreSQL vertical slice: the complete safety model and the full workflow, working end-to-end on Postgres. MySQL/MariaDB, SQLite, and SQL Server are stubbed behind the same adapter interface for a later milestone.

How it works
The design rests on three independent safety nets. They fail independently, so no single failure produces a breach.

Net 1 — Isolation. The database the agent touches is a throwaway postgres:16 container on an ephemeral volume, bound to 127.0.0.1 only (never a routable interface), seeded with synthetic data. Tearing it down with docker compose down -v destroys it completely — there's nothing permanent to delete and nothing real to leak. Reset is near-instant via PostgreSQL template databases: a known-good snapshot is captured as a template, and reset just drops the working DB and recreates it from that template, independent of data size.

Net 2 — Least privilege. Even inside the sandbox, connections use restricted roles:

readonly — SELECT only, and connections also force default_transaction_read_only = on.
testwriter — INSERT/UPDATE/DELETE on a single test schema only, with no DDL and no write access to the main tables.
Both roles are NOSUPERUSER. Every connection defaults to readonly; code escalates to testwriter only for the duration of an explicit write test, then drops back. An admin role exists strictly for harness-internal provisioning/snapshot/reset and never runs agent-authored queries.

Net 3 — OS-level confinement. Claude Code runs with its Bash sandbox enabled, so filesystem writes are kernel-blocked outside the working directory and all network traffic is forced through a proxy whose allowlist is just localhost (the sandbox DB) and api.anthropic.com. This is the real anti-exfiltration guarantee — there's no network route off the machine except the allowlisted hosts. It's OS-enforced via bubblewrap and socat on macOS/Linux/WSL2, and is inert on native Windows.

Backing those up:

A destructive-SQL guard (a PreToolUse hook) blocks shell-issued DROP, TRUNCATE, ALTER … DROP, and unscoped DELETE/UPDATE unless you opt in with ALLOW_DESTRUCTIVE=1 for a deliberate migration test.
The agent works in a git worktree, never the canonical checkout, and the harness never auto-applies — it emits a diff + report and stops.
The whole thing fails closed: if any net is unavailable or unverifiable, preflight (and therefore test) refuses to run.
The end-to-end workflow
up — bring up the disposable DB, apply the schema, provision the least-privilege roles, seed synthetic data, and capture a known-good snapshot.
preflight — verify all three nets are live; abort otherwise.
test — reset to known-good, then run the target project's own detected test suite (pytest or npm test) against the sandbox DB via injected least-privilege connection strings; capture output to out/reports/.
patch — on green, emit a unified diff + a human-readable report to out/patches/. Stops there.
You review the patch, git apply it yourself, and run any migration against your real DB.
reset to return to known-good, or down to destroy everything.
How to set it up
Requirements
Run under WSL2, Linux, or macOS. Native Windows can't enforce Net 3 — you can edit code and run the logic tests there, but real sandboxed runs must happen under WSL2/Linux.
Python ≥ 3.11
Docker + Docker Compose (v2 docker compose syntax)
On Linux/WSL2 only: bubblewrap and socat
sudo apt-get install bubblewrap socat      # Linux/WSL2
Install
# exact pinned dependencies
pip install -r requirements.lock

# or an editable install that also gives you the `harness` console script
pip install -e ".[dev]"
Dependencies are small: psycopg[binary] (Postgres driver), faker (deterministic synthetic seed), and pytest (dev/tests only).

Run it
python scripts/setup.py            # platform + dependency check (fail-closed report)
python -m harness.cli up           # disposable DB up: schema, roles, seed, snapshot
python -m harness.cli preflight    # verify all three nets (aborts if any is down)
python -m harness.cli test         # reset to known-good, run the sample_target suite
python -m harness.cli patch --worktree <path> --summary "what changed" --test-rc 0
python -m harness.cli reset        # restore known-good
python -m harness.cli down         # destroy the DB + volume
With the editable install, harness up works in place of python -m harness.cli up.

Configuration
Config is sandbox-only and non-secret. Defaults live in docker/.env.example (committed, throwaway credentials for a disposable loopback-bound container); override locally with a gitignored docker/.env, and the process environment overrides those keys at runtime. Key variables: ENGINE (default postgres), the POSTGRES_* connection settings, the SANDBOX_READONLY_* / SANDBOX_TESTWRITER_* role credentials, SANDBOX_TEST_SCHEMA, and SANDBOX_TEMPLATE_DB. Never put real or production credentials anywhere in the repo or the agent's environment — the agent's file tools run outside the Bash sandbox, so anything in its environment is readable by it.

Verify the safety guarantees
python -m pytest -q
The acceptance suite proves each guarantee: deletion-blocked, fail-closed, exfil-blocked, no-leak-to-canonical, privilege-enforced, and reset-correct. The DB-dependent tests skip cleanly when no sandbox is up, so the suite is safe to collect on a dev box; run harness up first (under WSL2/Linux) to exercise them fully.
