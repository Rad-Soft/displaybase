# Contributing

Thanks for helping. Monitor reports are the most useful thing you can send, since every monitor is a little different. Use the [monitor report](https://github.com/Rad-Soft/displaybase/issues/new?template=monitor.yml) form.

## Build it

You need a Mac with Apple silicon, Xcode 26 or later, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
make build
make test
```

`make install` builds it, quits the running copy, replaces it in Applications and opens it. The tests never launch the app or talk to a monitor. They run whole hand-overs on a simulated desk, with monitors that refuse, screens that won't turn off and keyboards that wander off.

`make check` runs everything CI does: lint, dead code, coverage, the site checks and the report scripts. See [docs/quality.md](docs/quality.md).

## Where things are

| Folder | What's in it |
| --- | --- |
| `Displaybase/Core` | Monitors, layout, rotation, USB, SSH and the controller that ties them together |
| `Displaybase/Views` | The menu, settings and setup |
| `Displaybase/App` | App start, the setup window and updates |
| `DisplaybaseTests` | Unit tests |
| `site` | The landing page, in Next.js |
| `docs` | Tested monitors and how releases are made |
| `scripts` | Release tools |

## Changes

- Open an issue first for anything bigger than a fix.
- Keep a pull request to one thing.
- Match the code around you. Comments are short and only say why.
- Screen changes need before and after screenshots, in light and dark. Anything else needs the command you ran and its result.
- If you touch inputs, layout or the switch, hand over and back on a real desk and say what you used.

Be careful when you test. A mistake can leave a monitor on the other computer's input. The monitor's own input button always brings it back, and logging out turns every screen back on.

By contributing you agree that your work is released under the [MIT license](LICENSE).
