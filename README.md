# ac-library-zig

ac-library-zig is a Zig implementation of AtCoder Library (ACL).

See below for ACL.

- [Original repository (implemented in C++)](https://github.com/atcoder/ac-library)
- [AtCoder Library (ACL) - AtCoder](https://atcoder.jp/posts/517)
- [AtCoder Library - Codeforces](https://codeforces.com/blog/entry/82400)

## API Reference

Automatically generated API Reference for the project can be found at https://repos.ryoga.dev/ac-library-zig.

> [!NOTE]
> Zig autodoc is in beta;
> the website may be broken or incomplete.

## Installation

Add `ac-library-zig` package to your `build.zig.zon` by following command:

```shell
# Use tagged release of ac-library-zig
# Replace `<REPLACE ME>` with the version of ac-library-zig that you want to use
# See: https://github.com/Ryoga-exe/ac-library-zig/releases
zig fetch --save=ac-library git+https://github.com/Ryoga-exe/ac-library-zig#<REPLACE ME>

# Use latest build of master branch
zig fetch --save=ac-library git+https://github.com/Ryoga-exe/ac-library-zig
```

You can then import `ac-library` in your `build.zig` with:

```zig
const ac_library = b.dependency("ac-library", .{});
const exe = b.addExecutable(...);
exe.root_module.addImport("ac-library", ac_library.module("ac-library"));
```
