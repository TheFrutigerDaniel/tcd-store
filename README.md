# tcd-store

An app store for legacy Mac OS X. **10.7 Lion through 10.10 Yosemite** — Cydia's
model (signed or unsigned package indexes you add yourself, dependency
resolution, system-level installs) aimed at Macs that fell out of Apple's
support window years ago.

```
prototype/   clickable design — open it and click around
native/      the Objective-C implementation of that design
docs/        architecture, and the signing argument
test/        headless functional test of the prototype
```

## Look at the design first

```bash
cd prototype
python3 serve.py          # http://localhost:8080, caching disabled
```

No build step, no dependencies.

Use `serve.py` rather than `python3 -m http.server`. The built-in server sends
`Last-Modified` with no `Cache-Control`, so browsers treat it as heuristically
fresh and will reuse a cached stylesheet or script without revalidating. You
edit `app.css`, reload, see the old version, and conclude nothing changed.
`serve.py` sends `no-store` and suppresses `Last-Modified`, so a 304 is not
possible and a plain reload always shows the current build. The asset URLs in
`index.html` also carry a `?v=N` stamp; bump that number when you change
`app.css`, `app.js` or `data.js`.

It is a real, working prototype — not a mockup. Dark cards down the left
(Store, then Categories), a large icon grid on the right.

Try the **blue triangle** in the corner of any tile. It unfolds every version
the source carries, Cydia-style, so you can install, update, **downgrade**, or
reinstall. Downgrading is explicitly labelled and warned about, and a package
sitting behind its source shows as updatable again — the route back up is the
same triangle.

Click **Mesa3D for Intel HD 4000** and press Install: the dependency on *Intel Graphics Fixup* is resolved
and pulled into the plan, the password warning appears because a `.pkg` is in
it, and the progress window walks the real pipeline. Then go to
**Settings → Code signing**, switch to ad-hoc re-signing, and install something
else: the step list grows by two, because the install pipeline asks the signer
what steps it needs rather than the two hard-coding the same list.

Things worth trying:

- **Sources → All Sources → + Add Source.** Type `not-a-url`; the sheet refuses
  it. Type a real URL and watch the refresh run. The *Ninth Row* source is
  deliberately broken — its packages still list, marked as cached.
- **FakeSMC** depends on *OpenSCPX* and conflicts with *SMCSuperIO*. Install it,
  then remove it again: the confirm sheet tells you the dependency goes too.
  That is the orphan rule from `docs/ARCHITECTURE.md` doing its job in the UI.
- Install *Mesa3D*, then *GraphicsOverride* — the second is refused, because
  they conflict.
- **Sources → All Sources → Remove** on *TCD Legacy Archive*: it warns that
  packages from it are installed, and confirms that removing a source does not
  uninstall anything.

## Test it

```bash
npm i jsdom
cd prototype && python3 -m http.server 8080 &
node test/verify.js
```

120 assertions covering every screen, the dependency resolver, the version
disclosure and downgrade path, both signing policies, the orphan rules and the
source flows. It runs the prototype's real
scripts in a real DOM, so it catches runtime errors rather than just checking
that markup exists.

## Build the native app

```bash
cd native && make FLOOR=10.7
```

Objective-C, ARC, `posix_spawn` instead of `NSTask`, `NSURLConnection` instead
of `NSURLSession`, frames instead of `NSStackView`. The reasoning for each 10.7
constraint is in `docs/ARCHITECTURE.md`.

One thing to know before you start: **Xcode 15+ will not target 10.7** — it
refuses anything below macOS 10.13. A real 10.7 binary needs Xcode 5 or 6. The
source is written so that building on a modern toolchain is a
deployment-target change and nothing more.

## The problem nobody warns you about

Gatekeeper, and the fact that Apple retired third-party Mac App Store
distribution in 2012. There is no way for an independent store to be a
*recognised publisher* on these systems, so every policy is a compromise.

The default is conservative: **never modify a signature**, ship a self-signed
certificate and an `spctl` profile, and let the user grant permission once. The
alternative — re-signing every installed payload — works, and needs a persistent
privileged helper, and can invalidate licence checks in software that has them.

`docs/SIGNING.md` lays out both, what each costs, and the third option that is
strictly better than either: re-sign only payloads that are not *already*
trusted, which most good legacy packages are not.

## Status

The prototype is complete and tested, and follows the concept: dark card
sidebar, large icon grid, Cydia-style version disclosure. The native tree is a
real, readable implementation of the model, index parser, database, resolver,
install engine, privilege and signing layers — but the AppKit UI is a source list and a table,
not the designed interface, and there is no rollback, no differential download,
and no real version-constraint resolver. `docs/ARCHITECTURE.md` has an explicit
list of what is deliberately not built yet.
