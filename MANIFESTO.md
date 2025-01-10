## The Soar Manifesto

#### Vision
In an era where Linux packaging systems [proliferate](https://www.dedoimedo.com/computers/linux-fragmentation-sum-egos.html) and [fragment](https://gist.github.com/bureado/792037b71229db3c37975e70e8a9c54a); every other day there's a new packaging format or a new package manager. Hobby Distros & Mainstream distros alike continue to keep reinventing the wheel that only addresses their problems. Existing solutions like flatpaks, homebrew & snaps etc continue to play favourites, ignoring alternative LIBC & only supporting a handful of the big distros. They have become gatekeepers while [not addressing any of their core issues](https://youtu.be/4WuYGcs0t6I). Even if one of these existing solution is adopted by everyone, it still will not solve the problem of pulling in a zillion dependencies, bloating everything or requiring root access just to install applications that don't even need root. Meanwhile solutions like NixOs (NixPkgs) are so bloated that they end up recreating a distro within a distro.<br>

Soar stands as a beacon of simplicity, portability, and accessibility. We envision a world where software packaging transcends the boundaries of distributions, where users don't have to waste their time waiting for:
- Use 100 different package managers to manage 100 different kind of packaging formats, only to watch promising projects get abandoned months later
- Packages to finish compiling from source when binary options should exist
- Upstream maintainers to package the latest versions, forcing users to stick with broken, outdated & insecure packages
- Be forced to use specific distributions solely because they're the only ones that package certain software

#### Mission
Our mission is to make Linux packaging truly portable, simple, and distro-independent.<br>
We aim to:
- Dismantle the barriers imposed by incompatible packaging systems
> - Writing packaging recipes should be simple, easy & avoid unneccessary complexity ([SBUILD](https://docs.pkgforge.dev/sbuild/introduction))
> - Packages once compiled should work universally across ALL distributions, ALL LIBC implementations & require minimal to zero additional dependencies to `just work`
- Have the most recent, the latest & greatest versions of applications whilst still offering stable versions
> - No more using bleeding edge rolling distros that break your system just because you wanted newer version of apps
> - Maintain both cutting-edge and stable versions & let the user choose what they prefer
- Not reinvent things that don't need reinventing
> - Let distro's official package managers do what they do best i.e handle core system tools/libraries
> - Avoid depending/linking on core system tools/libraries by providing truly standalone packages that `just work`
> - Coexist with existing package managers by avoiding conflicts, being completely functional in userspace & using XDG Specifications.
- Provide a unified, streamlined approach that benefits the entire Linux ecosystem
> - Become the true Linux User Repository by becoming Distro Agnostic; Users should be free to use whatever distro/system they like to use & get the same packages to `just work`
- Minimalism where it makes sense
> - Compile packages with sensible profiles: MUSL for lightweightness, mimalloc & LTO for performance, ASLR/PIE for security
> - Use container formats for dependency-heavy packages; while this increases application size, the tradeoff is worthwhile in an era where storage is abundant but time is precious
- Speed
> - Provide prebuilt binary cache & also make this as fast as possible, so installing a package is only limited by your bandwidth & disk IO, not by our packaging tooling
- Transparency & Security at Core
> - Keep an unforgeable record of any & all changes for all our source code, tooling & more
> - Provide reproducible (or nearly reproducible) builds & artifacts
> - Provide CI logs, checksums, provenance, signing & more for each & every package

#### Call to Action
If any of these principles resonates with your experience and vision for Linux packaging, join us in this revolution by becoming a part of the Soar community.<br>
- Discord: https://docs.pkgforge.dev/contact/chat
- Discussions: https://github.com/pkgforge/soarpkgs/discussions
- Docs: https://docs.pkgforge.dev/repositories/soarpkgs

Together, let's make Linux packaging soar.
