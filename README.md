# MailToGmail

A tiny macOS helper that redirects `mailto:` links to Gmail's web compose
window, so clicking an email address in Safari (or any other app) opens a
Gmail compose tab in your browser instead of launching Mail.app.

It exists as an alternative to paid App Store utilities that do the same
thing (Mail to Web, Open In Webmail) — same idea, but free, tiny, and fully
inspectable.

## How it works

Safari has no "default mail app" setting of its own. It just defers to
whatever app macOS has registered as the system's default mail reader
(configured in Mail.app's own settings). That picker only lists installed
apps that declare themselves as a `mailto:` handler — it has no way to point
at a web service like Gmail directly.

MailToGmail closes that gap by being exactly such a handler:

1. It registers itself with Launch Services as claiming the `mailto:` URL
   scheme (via `CFBundleURLTypes` in its `Info.plist`).
2. When something invokes a `mailto:` link and macOS is configured to hand
   those to MailToGmail, the app is launched and receives a `GetURL` Apple
   Event carrying the full `mailto:` string.
3. It parses that string — recipient(s), `cc`, `bcc`, `subject`, `body` — and
   builds the equivalent Gmail compose URL
   (`https://mail.google.com/mail/?view=cm&fs=1&to=...`).
4. It opens that URL with `NSWorkspace.shared.open()`, which hands off to
   whatever your system default *browser* is (Safari, in the common case) —
   MailToGmail doesn't hardcode Safari, it just respects that setting.
5. It quits immediately. It never shows a Dock icon, a menu bar icon, or any
   persistent UI — it exists only for the moment it takes to redirect a link.

If you double-click the app directly (instead of it being launched via a
`mailto:` link), it shows a one-time alert explaining what it is and how to
set it up, then quits — it isn't meant to be used that way, but a silent
no-op quit would just look broken.

## What's supported

All the fields a typical `mailto:` link carries are mapped through to
Gmail's compose parameters:

| mailto field | Gmail compose param |
|---|---|
| address(es) before the `?` | `to` |
| `to=` | `to` |
| `cc=` | `cc` |
| `bcc=` | `bcc` |
| `subject=` | `su` |
| `body=` | `body` |

Handled correctly:
- Multiple recipients, separated by either commas or semicolons
  (`mailto:a@b.com,c@d.com` and `mailto:a@b.com;c@d.com` both work)
- Links with no query string at all (`mailto:someone@example.com`)
- Links with the address only in the query, not before the `?`
  (`mailto:?to=someone@example.com`)
- Percent-encoded characters, decoded once and re-encoded once (no
  double-encoding of things like spaces, `&`, or line breaks in the body)
- Missing/empty fields are simply omitted from the Gmail URL rather than
  passed through blank

Not supported (by design, kept intentionally simple):
- Multiple Google accounts / `authuser` switching — compose opens under
  whichever Google account is currently active in your browser
- Other RFC 6068 mailto headers beyond `to`/`cc`/`bcc`/`subject`/`body`
  (e.g. `in-reply-to`) — these are ignored, not errored on

## Installing

### 1. Build it

Requires the Xcode Command Line Tools (`swiftc`, `iconutil`, `codesign` —
already present if you can run `xcode-select -p` successfully).

```sh
cd MailToGmail
./build.sh
```

This compiles `MailToGmail.swift`, generates the app icon on first run (via
`make_icon.sh`/`MakeIcon.swift`), assembles `MailToGmail.app`, strips the
quarantine flag, and code-signs it (ad-hoc, unless you've created a
`"MailToGmail Local Signing"` identity in Keychain Access — this app doesn't
need a stable identity across rebuilds since it holds no privacy-scoped OS
permissions).

### 2. Put it somewhere permanent

Launch Services doesn't care what folder an app lives in, but `/Applications`
is the conventional spot:

```sh
cp -R MailToGmail.app /Applications/
```

### 3. Register it and launch it once

```sh
open /Applications/MailToGmail.app
```

This registers the app's `mailto:` claim with Launch Services. Since you
launched it directly (no URL), you'll see the one-time explanatory alert —
that's expected; click OK.

If macOS is slow to pick up the registration, force it directly:

```sh
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f /Applications/MailToGmail.app
```

### 4. Set it as the default mail reader

1. Open the **Mail** app
2. Open the **Mail** menu (top-left of the screen) → **Settings...**
3. Click **General**
4. Set **Default Email Reader** to **MailToGmail**

You can quit Mail again afterward if you don't otherwise use it — this
setting persists as a system-level preference.

## Testing without touching system settings

You can exercise the app directly, independent of whatever your current
default mail reader is, by targeting it explicitly with `open -a`:

```sh
open -a /Applications/MailToGmail.app "mailto:test@example.com?subject=Hi%20There&body=Hello%2C%20World%0AWith%20a%20line%20break&cc=cc@example.com,cc2@example.com&bcc=bcc@example.com"
```

This should open a Gmail compose tab in your default browser with the `to`,
`cc`, `bcc`, subject, and (multi-line) body all populated, and the
MailToGmail process should exit immediately afterward — check with:

```sh
ps aux | grep MailToGmail
```

(no output means it quit cleanly, as expected).

Once it's set as your actual default mail reader, click a real `mailto:`
link on any web page to confirm the full end-to-end path.

## Uninstalling

1. In Mail's Settings → General, change **Default Email Reader** back to
   Mail (or whatever you'd prefer) — do this first, otherwise mailto links
   will have no handler once the app is removed.
2. Delete the app: `rm -rf /Applications/MailToGmail.app`

## Project layout

```
MailToGmail.swift    the entire app: mailto parsing, Gmail URL building,
                      Apple Event handling, the direct-launch alert
MakeIcon.swift        renders the app icon (squircle plate + SF Symbol glyph)
make_icon.sh          drives MakeIcon.swift, assembles MailToGmail.icns
build.sh              compiles the app, assembles the .app bundle, signs it
MailToGmail.icns      generated icon (checked in so a rebuild isn't required
                      just to get an icon)
MailToGmail.app/      the built app bundle (checked in for convenience)
```

No Xcode project, no Swift Package Manager — just `swiftc` and a shell
script, in the same style as the `Caffeine` utility elsewhere in this `Tools`
directory.
