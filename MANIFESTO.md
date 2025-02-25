<details>
  <summary>Addressing the Internet (Click Me)</summary>

> - Redditors have expressed **confusion** and called us out on being political:
> > - https://www.reddit.com/r/linux/comments/1ix0tzs/comment/meip78m/
> > ![image](https://github.com/user-attachments/assets/b715512e-690a-42c5-a9f1-bf056e104941)
> > > You can [view the commit history of this file and see for yourself](https://github.com/pkgforge/soarpkgs/commits/main/MANIFESTO.md).
> > > An explaination was offered however it seemed to have been shadowbanned: https://www.reddit.com/r/linux/comments/1ix0tzs/comment/mem8ilh/
> > > ![image](https://github.com/user-attachments/assets/2a26adf4-8f6e-4d52-aecb-491a3ca1b792)
> - Redditors have expressed **inability to read documentation** and called us out on being partial:
> > - https://www.reddit.com/r/linux/comments/1ix0tzs/comment/meibtlr
> > ![image](https://github.com/user-attachments/assets/4b0f3a55-ca36-44fb-8a62-fdab3edc0cff)
> > - Lobster's comment on this not being a **particularly well thought out project**
> - https://lobste.rs/s/iem7jw/soar_distro_agnostic_package_manager
> > This is why we have the sorry state of Linux Packaging in the first place. Rather than answer any of my questions where it's clearly stated that _**it wouldn’t work the way soar/soarpkgs are designed (Always from latest source)**_, We get lectures on how "other" distros do it and then we also receive our own code as supposed proof...?
> > ![image](https://github.com/user-attachments/assets/33ebe008-9e4b-493e-8f8b-859d63be1c40)
</details>

---
## The Soar Manifesto

#### Vision
In an era where Linux packaging systems [proliferate](https://www.dedoimedo.com/computers/linux-fragmentation-sum-egos.html) and [fragment](https://gist.github.com/bureado/792037b71229db3c37975e70e8a9c54a); every other day there's a new packaging format or a new package manager. Hobby Distros & Mainstream distros alike continue to keep reinventing the wheel that only addresses their problems. Existing solutions like flatpaks, homebrew & snaps etc continue to play favourites, ignoring alternative LIBC & only supporting a handful of the big distros. They have become gatekeepers while [not addressing any of their core issues](https://youtu.be/4WuYGcs0t6I). Even if one of these existing solution is adopted by everyone, it still will not solve the problem of pulling in a zillion dependencies, bloating everything or requiring root access just to install applications that don't even need root. Meanwhile [solutions like NixOs (NixPkgs)](https://www.dgt.is/blog/2025-01-10-nix-death-by-a-thousand-cuts/) are so bloated that they end up recreating a distro within a distro.<br>

Soar isn't a replacement for existing package managers.
Neither it is trying to compete with any so called standards.
We believe in simplicity and no-nonsense approach to building & delivering software, where users don't have to waste their time waiting for:
- Use 100 different package managers to manage 100 different kind of packaging formats, only to watch promising projects get abandoned months later
- Packages to finish compiling from source when binary options should exist
- Upstream maintainers to package the latest versions, forcing users to stick with broken, outdated & insecure packages
- Be forced to use specific distributions solely because they're the only ones that package certain software

#### Goals & Non-Goals
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
If any of these statements resonates with your experience and vision for Linux packaging, join us by becoming a part of the Soar community.<br>
- Discord: https://docs.pkgforge.dev/contact/chat
- Discussions: https://github.com/pkgforge/soarpkgs/discussions
- Docs: https://docs.pkgforge.dev/repositories/soarpkgs

Together, let's make Linux packaging [soar](https://github.com/pkgforge/soar).
