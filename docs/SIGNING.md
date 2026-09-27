# Gatekeeper and code signing on 10.7–10.10

This is the part of a legacy Mac store nobody warns you about, and the reason
most "just repackage the old apps" projects die. Here is the actual situation
and the two survivable answers.

## Why there is no good answer

Gatekeeper arrived in Lion (10.7). It blocks anything that is not signed by a
developer whose certificate chains to a root macOS trusts. Apple enforced it on
a rolling basis and turned it on by default in later releases.

For an iOS-style store the escape hatch is the App Store. For the Mac there
**was** a Mac App Store, and it was retired in 2012. That matters because
Apple's third-party macOS distribution system — the thing that would have let
an independent store be a *recognised publisher* — is gone. There is no
re-application, no waiting list, no notarisation path.

So: a store for 10.7–10.10 is, permanently, either redistributing signatures it
does not own, or asking the user for permission, or taking root.

That is the real constraint. Everything below is a way of spending it.

## Option A — user opt-in *(recommended, and the default)*

**What it does.** Never touch the signature of an installed payload. The store
ships its own self-signed certificate and an `spctl` assessment profile, and on
first launch walks the user through enabling it:

```
sudo profile install -f /Library/Application Support/TCDStore/tcd.der
```

`/usr/sbin/spctl --assess` then accepts anything that chain trusts, so a
`.pkg` the store has verified and the user has explicitly allowed installs
without a Finder prompt.

**What it costs you**

- The user must do a one-time, deliberately scary thing (type a password to
  install a profile). Converting that user is your problem, not Apple's.
- Payloads signed by a developer whose certificate has since expired or been
  revoked still prompt. No amount of local policy fixes that.
- Support burden stays with you: when a legacy binary prompts, the answer is
  "right-click, Open", and the user has to know that.

**Why it is still the right default**

It is the only option that cannot damage a machine. You never re-sign something
Apple already has a trust relationship with, so you can never invalidate a
licence check, break an updater, or turn a working app into a broken one. The
blast radius of a bug in this mode is "the user saw an extra dialog".

In `TCDSigner` this is `TCDSigningPolicyOptIn`; it inserts **zero** extra
pipeline steps. Install runs as: download → verify → authorise → install →
finish.

## Option B — ad-hoc re-signing

**What it does.** After an install, re-sign every bundle on the payload path
with the TCD Store identity so it launches clean:

```
codesign -f -s "TCD Store" --deep /Applications/Foo.app
```

**What it costs you**

- A **persistent privileged helper**. `AuthorizationExecuteWithPrivileges` is
  scoped to a single tool invocation; re-signing needs the `codesign` identity
  to be usable repeatedly. That means `SMJobBless` and a LaunchDaemon, which
  means the user approves an installer, which is a much larger ask than a
  profile. See `TCDAuthorizer`.
- **Licence checks can break.** If a payload validates its own signature as part
  of a licence or update check, you have just invalidated it. Some legacy
  applications genuinely do this.
- **You become responsible for every signature you write.** A payload that is
  re-signed and then fails at runtime is now your bug, not the developer's.
- Nested code must be signed before its container. `TCDSigner` sorts by path
  depth for exactly this reason — get it wrong and `--deep` silently produces
  a bundle that still fails verification.

In `TCDSigner` this is `TCDSigningPolicyAdHoc`; it inserts **two** extra steps.
Install runs as: download → verify → authorise → install → re-sign → commit →
finish. Switch policies in the store's Settings pane and the step list in the
install window changes with it, so the two can never drift apart.

## Recommendation

Ship A. Ship the `spctl` profile, put the one-time setup on first launch with a
plain explanation, and keep B behind a setting.

Then, when you are ready, add a third path that is strictly better than both
and costs you nothing today:

> **Re-sign only what needs it.** Before installing, ask
> `SecStaticCodeCheckValidity` whether the payload is *already* trusted
> (`TCDSigner -payloadAtPathIsTrusted:`). If it is, install it untouched — a
> correctly signed legacy app keeps its signature and its updater keeps working.
> Only fall back to re-signing when the answer is no. Most good legacy
> packages are signed by someone whose certificate is still valid, and the
> store should not be rewriting those signatures for no reason.

That is the policy this project is built to support. It is not the default
because the fallback path still has to exist, and shipping a half-finished
trust policy is worse than shipping a conservative one.

## What is *not* an option

- **Notarisation / stapling.** Both arrived in 10.14.5 / 10.15 and require
  Apple's developer portal. There is no backport.
- **Apple as a recognised publisher.** The Mac App Store distribution
  programme is closed. It has been since 2012.
- **Disabling Gatekeeper wholesale.** `spctl --master-disable` works until
  10.15, where it stops existing. Teaching users to run it is teaching them to
  run an unsupported incantation that will break on their next OS upgrade, and
  it disables a real security control for the entire machine to solve a problem
  scoped to a handful of directories.
