## Project context

Personal-use maintenance fork of `lihaoyun6/QuickRecorder`, whose upstream went inactive in 2025-06. Builds run only on the owner's Mac and are never published: keep the upstream bundle id and app name, and ship no update channel. Minimum macOS is 26 (the owner runs 27). Upstream's open PRs and issues are a backlog to mine; cite them in backticks (`lihaoyun6/QuickRecorder#123`) so GitHub posts no cross-reference on upstream.

## Workflow

Every change reaches `main` through a PR on `MosCloud/QuickRecorder`, one branch per issue. The PR body links its issue and carries the test plan with results; the owner merges.

## Build and install

`xcode-select` points at the Command Line Tools, so set `DEVELOPER_DIR` for every Xcode command. Keep DerivedData out of iCloud-synced folders: iCloud's Finder xattrs make codesign fail with "resource fork, Finder information, or similar detritus not allowed". Its name ends in `.noindex` so Spotlight skips the build products: otherwise searching for QuickRecorder also offers the Release and Debug builds next to the installed app.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
DD=~/Library/Developer/Xcode/DerivedData/QuickRecorder-cli.noindex
xcodebuild build -project QuickRecorder.xcodeproj -scheme QuickRecorder -configuration Release \
    -derivedDataPath "$DD" -allowProvisioningUpdates
# install (quit QuickRecorder first); replace the bundle so removed files don't linger
rm -rf /Applications/QuickRecorder.app && ditto "$DD/Build/Products/Release/QuickRecorder.app" /Applications/QuickRecorder.app
# every build registers its products with Launch Services; leave only the installed copy for AppleScript and `open -a`
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
for c in Release Debug; do "$LSREG" -u "$DD/Build/Products/$c/QuickRecorder.app" 2>/dev/null; done
```

Signing is automatic with the owner's Personal Team (`B5JGQB9CXF`). That stable certificate is what keeps the Screen Recording, Microphone and Camera grants across rebuilds; an ad-hoc signed build loses them every time.

## Testing

A PR is ready for review when all three hold:

1. Logic that runs without UI or system permissions (timing, file naming, audio settings, content filters) is covered by unit tests, and a bug fix in such code starts from a test that goes red on the bug.
2. The unit tests pass:
   ```sh
   xcodebuild test -project QuickRecorder.xcodeproj -scheme QuickRecorder -destination 'platform=macOS' \
       -derivedDataPath "$DD" -allowProvisioningUpdates
   ```
3. The sections of `docs/testing/manual-checklist.md` touched by the change were walked on the owner's Mac, with results recorded in the PR.

`QuickRecorderTests` runs hostless: it compiles the files in `QuickRecorder/Core/` itself instead of launching the app, which would ask for screen-recording permission and register global hotkeys. Code in `Core/` therefore works only from Foundation/AVFoundation and its own parameters (no `ud`, `SCContext` or `.local`), and a new `Core/` file joins both targets' Sources. To test more logic, move it into `Core/` as a pure function and call it from the app.

## Agent skills

### Issue tracker

GitHub Issues on the fork `MosCloud/QuickRecorder` (via `gh`), never the upstream repo. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
