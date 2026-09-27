# Architecture

Target: **Mac OS X 10.7 Lion through 10.10 Yosemite**, i386 and x86_64,
Objective-C, ARC.

The clickable prototype in `prototype/` is the design. This document is the
translation, screen by screen, into the classes in `native/TCDStore/`.

## Why 10.7 changes the code, not just the deployment target

10.7 is not "an old target", it is a different available API surface. The
following are simply absent, and the code is written to avoid each:

| API | Introduced | What the code does instead |
|---|---|---|
| `NSURLSession` | 10.9 | `NSURLConnection sendAsynchronousRequest:queue:completionHandler:` |
| `NSStackView` | 10.9 | frames + autoresizing masks |
| `NSVisualEffectView` | 10.10 | plain window background colour |
| `NSTask` | 10.13 | `TCDProcessRunner` on `posix_spawn` |
| `SecCode` copy-signing | 10.9 | `SecStaticCode*` (10.7) for checks, `codesign(1)` for signing |

`NSTask` is the one people trip over. There is no backport, and the store
shells out constantly — `/usr/sbin/installer`, `/usr/sbin/kextutil`,
`/usr/bin/codesign`, `/usr/sbin/spctl`. All of it goes through
`TCDProcessRunner`, which is the only file in the project that deals with
pipes, exit codes and the privilege boundary.

It drains stdout and stderr with `poll()` rather than reading them in sequence,
because `/usr/sbin/installer` writes progress to stderr; reading stdout to EOF
first deadlocks the moment stderr's pipe buffer fills.

> **Build caveat.** Xcode 15 and later refuse a deployment target below
> macOS 10.13. Producing a real 10.7 binary needs Xcode 5 or 6. The source is
> written so that building against a modern toolchain is a deployment-target
> change and nothing more — see `native/Makefile`.

## Module map

```
TCDIndexParser     Packages index  ->  TCDPackage[]
TCDPackage         one package, index metadata + local install state
TCDPackageDatabase SQLite; the merge point for all sources
TCDResolver        package + catalogue -> ordered install plan, conflicts, orphans
TCDInstaller       plan -> download, verify, install, re-sign, commit
TCDAuthorizer      root, via AuthorizationExecuteWithPrivileges or SMJobBless
TCDSigner          signing policy; opt-in (default) or ad-hoc re-sign
TCDProcessRunner   posix_spawn wrapper; the only place that runs a tool
TCDAppDelegate     window, source list, content table, install wiring
```

Data flows one way: an index is parsed into `TCDPackage`s, which the database
merges, which the resolver turns into a plan, which the installer executes.
Nothing reads back up the chain.

## Screen → class

| Prototype screen | Native |
|---|---|
| Sidebar (Featured / Categories / Updates / Search / Installed / Sources / Settings) | `NSOutlineView` in `TCDAppDelegate` |
| Featured grid | `NSTableView`, `-installPackage:` from a double-click |
| Package detail, Description tab | `TCDPackage` |
| Package detail, Dependencies tab | `TCDResolver`, `-removalBlockersForPackage:` |
| Sources list + Add Source | `-addSource:`, `-removeSourceWithIdentifier:` |
| Install confirm sheet | `TCDInstallPlan` rendered directly — the sheet **is** the plan |
| Install progress | `TCDInstallSession`, one `TCDInstallStep` per stage |
| Settings → signing | `TCDSigner` |

The install step list is data, not control flow. `-[TCDInstaller stepsForPlan:]`
returns an array; the progress window renders it; `additionalPipelineSteps` from
the signer is folded in, so switching the signing policy in Settings changes
the visible step list automatically and the two cannot drift.

## Source indexes

A source is an HTTP directory containing a `Packages` file — the Debian
control-stanza format Cydia already uses, because it is trivial to generate,
trivial to diff, and a maintainer can hand-write one in an emergency.

```
Package: fakesmc
Version: 1.3.1
Architecture: any
Installed-Size: 228
Depends: openscpx
Conflicts: smcsuperio
TCD-Type: kext
TCD-Section: System
TCD-Developer: Slice
TCD-Prefix: /System/Library/Extensions/FakeSMC.kext
TCD-SHA256: 9f2c...
Filename: pool/fakesmc/1.3.1/fakesmc.pkg
```

Full field list in `TCDIndexParser.h`. Notable points:

- **A malformed stanza is skipped, not fatal.** One broken entry in a
  third-party index must not cost the user every other package in it.
- **Version constraints are parsed away.** `Depends: a (>= 1.0), b` becomes
  `["a", "b"]`. The resolver treats a dependency as satisfied by any version
  of the named package. Tightening that is a resolver change, not a parser
  change, and until someone writes a real resolver the loose form is the
  honest one.
- **A refresh is a transaction.** A connection dropped halfway through a 4 MB
  index cannot leave a package list missing its second half.
- **The last good index is cached** in `sources.index_blob`, so a source that
  is down shows a cached list marked as cached, not an empty page.

## Storage

SQLite via `libsqlite3.dylib`, which is in the OS on 10.7 — no system package,
nothing to install. Two tables: `packages` (merged view of every source plus
local annotations) and `sources` (which indexes we have and their cached
bytes). Every value from an index or from the user is **bound**, never spliced
into SQL text.

## The two rules that are easy to get wrong

Both were bugs in the prototype before the test suite pinned them down, so they
are called out here rather than left implicit.

### 1. Conflicts are checked against what is *installed*, not against the plan

A plan is invalid if any member conflicts with an already-installed package.
Checking within the plan instead would let a user install A and B together and
only then discover they are mutually exclusive.

`-[TCDResolver planForPackages:withPrimary:]` compares every member's
`conflicts` against installed packages that are not themselves in the plan.

### 2. Autoremove is scoped to the dependency closure

"Remove package X" may also remove dependencies of X — but only ones that were
auto-installed, and only ones that something *in the removal set* depends on.

The tempting wrong rule is "this package has no dependents, so it is orphaned".
It is wrong. An installed application's dependency usually has no dependents
either. Removing it breaks the application. `-[TCDResolver orphansAfterRemovingPackage:]`
therefore walks the closure: start with `{X}`, and a package may join only if
something already in the set depends on it.

Concretely, with `mesa → intelopenglfix` installed and `fakesmc → openscpx`
installed, removing `fakesmc` takes `openscpx` with it and leaves
`intelopenglfix` alone. The prototype's test suite asserts exactly this.

## What is deliberately not built yet

Stated plainly so nobody assumes it exists:

- **A real resolver.** The current one is greedy depth-first with no backtracking
  and no version constraints. It handles the shapes in the prototype; it will
  not solve a genuinely contradictory index.
- **Price and accounts.** The model has `cPrice`; there is no purchase flow.
- **Differential updates.** A 100 MB `Mesa3D` is downloaded whole every time.
- **Rollback.** An install that half-completes leaves a mess and says so. A
  transactional installer that snapshots the receipt payload first is the right
  fix and is not written.
- **The privileged helper.** `TCDAuthorizer` implements the
  `AuthorizationExecuteWithPrivileges` path fully. The `SMJobBless` path is a
  stub, because it only matters under the ad-hoc signing policy (see
  `docs/SIGNING.md`).
