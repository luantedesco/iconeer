# Contributing

Bug reports, ideas, translations, and pull requests are welcome. For a larger change, open an issue first, so we can agree on the approach before you write it.

## Requirements

- macOS 26 or later
- Xcode, or only the Command Line Tools (`xcode-select --install`)

## Build, test, and lint

```sh
./build.sh                                              # builds build/Iconeer.app
swift test                                              # runs the tests, translations included
swift format lint -r -s Sources Tests Tools Package.swift
```

Formatting follows `.swift-format`; `swift format -i -r Sources Tests Tools Package.swift` applies it. The same checks run on every pull request.

## Signing certificate

macOS ties the App Management permission to the app's signature. Signed ad hoc, each build is a new app to macOS, and the permission has to be granted again after every rebuild. `build.sh` signs with a certificate named **Iconeer Local Signing** when it is in your Keychain, which keeps the permission across builds. To create it:

1. Open Keychain Access (`open -a "Keychain Access"`).
2. Choose **Keychain Access → Certificate Assistant → Create a Certificate…**
3. Name: `Iconeer Local Signing`. Identity Type: **Self-Signed Root**. Certificate Type: **Code Signing**. Click **Create**.

The certificate is only for your Mac; it does not need to match the one releases are signed with.

## Code

- Logic that can run without a window goes in `Sources/IconeerCore`, with tests in `Tests/IconeerCoreTests`: listing apps, applying and reverting icons, the macOSicons client, the cache, the Keychain, and reapplying after updates. Network calls come in as closures, so tests never call the real API. The app itself (menu bar, windows, notifications) is in `Sources/Iconeer`.
- Code, comments, and messages are in English.
- Commit messages follow `type(scope): description`, where the description says what changes for the user, for example `fix(core): search results credit the icon creator's name instead of a link to their site`. Types in use: `feat`, `fix`, `refactor`, `docs`, `ci`, `chore`; scopes: `core`, `app`, `build`.

## Testing

The tests cover the core; what depends on the real apps, the Dock, and macOS permissions is checked by hand. Before opening a pull request, run the app you built and check:

- applying an icon from the catalog and from a PNG or ICNS file, then **Revert**
- an app that is closed (the Dock shows the new icon right away) and one that is open (the message says it shows on the next launch)
- that App Store and Apple apps are listed under **Can't Change**
- that a customized app gets its icon back after an update, or after deleting its `Icon\r` file with Iconeer running
- in light and in dark mode, in English and in Brazilian Portuguese

## Translations

Interface text lives in `Resources/<language>.lproj/Localizable.strings`. The English text in the code is the key, so English needs no file. To add a language:

1. Copy `Resources/pt-BR.lproj` to `Resources/<code>.lproj`, using the code macOS uses for the language (for example `de`, `es`, `fr`, `ja`, `zh-Hans`).
2. Translate the text on the right of each `=`; keep the keys on the left and every `%@` and `%lld` as they are. Use the words macOS uses in its own menus where they exist.
3. Add the code to `CFBundleLocalizations` in `Resources/Info.plist`.
4. Run `swift test`, then build and open the app in that language:

   ```sh
   ./build.sh
   open build/Iconeer.app --args -AppleLanguages "(<code>)"
   ```

New text in the code goes through `String(localized: "…")` or a SwiftUI view that takes a literal, and has to be added to every language; `swift test` fails otherwise.

## Releases

Releases are built and signed by the maintainer, so that the App Management permission carries over between versions. Pull requests do not need to change the version number.

```sh
./build.sh
./Tools/make-dmg.sh   # build/Iconeer.dmg, attached to the GitHub release
```
