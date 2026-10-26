# Contributing

Read [`docs/FORMAT.md`](docs/FORMAT.md) for how a package is written. This
page covers which packages are accepted.

## Package requirements

A package must run on any recent Linux distribution without the user
installing anything first. That includes musl distributions such as Alpine and
non-FHS distributions such as NixOS, not only glibc distributions like Ubuntu.
A package that works on only some of them is not accepted.

### Preferred formats

Use the first of these that the project can provide:

1. A static binary.
2. A onelf, when a static binary is not possible.
3. An AppImage, when neither of the above is available.

### Binaries

Binaries must be statically linked. A binary that needs a shared library from
the host is not accepted, even a common one such as glibc or OpenSSL.

```sh
file ./tool    # should say "statically linked" or "static-pie linked"
ldd ./tool     # should say "not a dynamic executable"
```

### AppImages

An AppImage must not depend on FUSE. Many systems do not have it, and it is
often unavailable in containers. It must still start when FUSE is missing.

### AppImages, onelfs and other portable formats

The bundle must provide everything it needs, including its own loader and
libraries. It may carry them or fetch them itself at runtime, as long as the
user does not have to install anything on the host. Check it on Alpine and
NixOS before opening a pull request. Most glibc distributions work once those
two do.

```sh
docker run --rm -it -v "$PWD:/pkg" alpine /pkg/app.AppImage --version
docker run --rm -it -v "$PWD:/pkg" nixos/nix /pkg/app.AppImage --version
```

### Programs needed at runtime

Any package, AppImages included, may call another program at runtime, such as
Docker or `git`. It must still not need a library installed on the host. If
the package cannot work without that program, mark it `portable = false` and
give a `portable-reason`, as described in [`docs/FORMAT.md`](docs/FORMAT.md).
