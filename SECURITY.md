# Security

Please report security problems privately, through [GitHub's security advisories](https://github.com/Rad-Soft/displaybase/security/advisories/new) or hello@radsoftinc.com. You should hear back within a week.

Only the latest release gets fixes.

A few things worth knowing:

- Displaybase runs `ssh` with your own config and keys, only if you give it a host. It never stores a password.
- Updates are signed. The app checks the feed and the download before it opens either.
- It isn't sandboxed, because switching inputs and turning screens off needs system services the sandbox blocks.
