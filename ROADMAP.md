<!--
SPDX-FileCopyrightText: 2026 Jean-Pierre De Jesus DIAZ <me@jeandudey.tech>
SPDX-License-Identifier: Apache-2.0 OR MIT
-->

# Roadmap

Where this is, and what reaching a GCC toolchain asks for.

## Done

- **stage0-posix**, all 28 phases, from the `hex0-seed` binary to the thirteen
  mescc-tools-extra programs. `//stage0:check` verifies the nineteen binaries
  against the hashes upstream publishes for them; they match byte for byte.
- **GNU Mes 0.27.1**: `mes-m2` built by M2-Planet, then the C library and
  `mes-mescc` built by MesCC. Both run.
- **tcc**, Janneke's `0.9.26-1149-g46a75d0c`, compiled by MesCC and linked with
  `hex2`. This is upstream's `tcc-mes`, the first stage of its `bootstrap.sh`.
- **The C library again, compiled by that tcc**: the `REBUILD_LIBC` half of
  `bootstrap.sh`. `crt1.o`, `crti.o` and `crtn.o`, `libc.a` from the whole of
  Mes' `libc+gnu.c` as one translation unit, `libtcc1.a` and `libgetopt.a`.
  From here on the objects are ELF that tcc emitted, not hex2 that MesCC did.

Proven on x86: a program compiled by `tcc-mes` and linked against the rebuilt
`crt1.o`, `libc.a` and `libgetopt.a` runs.

## The shape this takes

Everything above is built once per target CPU, as though each architecture had
its own road to GCC. That is not how the bootstrap works, and it is being
changed before anything else is added.

**Guix builds one chain, for x86, and crosses to everything else.** On an
x86_64 machine it does not build a 64-bit Mes or a 64-bit tcc at all. It is
decided at the very bottom, in `gnu/packages/commencement.scm`:

- `stage0-posix` picks its seed with `((or (target-x86-64?) (target-x86-32?))
  "x86")` — one branch for both (`:386`).
- `mes-boot` configures `--host=` `((target-x86-64?) "i686-linux-gnu")`
  (`:470`).
- `tcc-boot` configures `--cpu=i386` and compiles with `-D TCC_TARGET_I386=1`
  (`:764`).
- Every package after that — binutils 2.20.1a, GCC 2.95.3, glibc 2.2.5, GCC
  4.6.4, glibc 2.16.0, GCC 4.9.4 — carries `--build=i686-unknown-linux-gnu
  --host=i686-unknown-linux-gnu` with `--disable-multilib`. Even the kernel
  headers are an i686 tarball.
- There is a comment that says it outright: `;; also for x86_64-linux, we are
  still on i686-linux` (`:1741`).

The word size changes once, at the end. `%bootstrap-inputs+toolchain` (`:1973`)
hands that i686 toolchain to the ordinary commencement, and `binutils-boot0`
and `gcc-boot0` are configured `--target=(boot-triplet)` (`:2411`), which on an
x86_64 machine is `x86_64-guix-linux-gnu`. The i686 GCC 4.9.4 builds a **cross
toolchain to x86_64**, and everything after that is 64-bit. The comment above
it calls this "a cross-toolchain in stage 0 … actually targets the same OS and
arch", which is true on an i686 machine and quietly untrue on an x86_64 one.
That is where the transition hides.

So: **the CPU the bootstrap runs on and the CPU the finished toolchain targets
are two different things, and only the second one is a target platform.** x86
binaries run on x86_64, so on any x86 machine there is exactly one bootstrap
chain, and it is 32-bit. Other architectures are reached by cross-compiling,
which only becomes possible once there is a GCC to configure.

This dissolves rather than fixes every amd64 problem found so far — the MesCC
struct-initializer bug, tcc's unrelocated PLT stubs, and Mes' C library having
no varargs for a register-passing compiler are all reachable only through code
that a 32-bit build never compiles. It also explains why nobody has hit them:
nobody builds a 64-bit Mes or tcc.

The cost is that the machine must be able to execute i686 binaries, which is
what `CONFIG_IA32_EMULATION` is for. Guix depends on this too, and the remote
execution workers here already do it.

riscv64 is unaffected: Guix builds it natively, because there is no 32-bit
RISC-V to fall back to. It stays its own bootstrap CPU, and needs a riscv64
worker or binfmt to get past `tcc-mes`. aarch64 is not a bootstrap CPU at all —
Mes has no port — so it can only ever be a cross target.

### Native for as long as possible

Guix goes 32-bit at the seed. We do not have to, and we do not: **the
architecture stops being built into the tools and becomes a command line
argument at phase 5.** `hex2`, `M1`, `blood-elf`, `M2-Planet` and
`M2-Mesoplanet` all take `-A/--architecture`, so from M2-Planet onward the
output CPU is an argument rather than a property of the binary. Only `M0` and
`cc` are locked, and upstream says so itself: "M0 is the architecture specific
version of M1 and is by design single architecture only".

So the seed chain runs natively and still emits x86. This is already what the
repository does, without anyone having designed it: every stage0 tool and the
Mes interpreter are `exec_dep`s, so they resolve to the execution platform,
while the artifacts resolve to the target platform.

    root//mes:mes_m2         (root//platforms:default#…)      amd64, runs here
    root//stage0:hex2_stage2 (root//platforms:default#…)      amd64, runs here
    root//mes:mescc.scm      (root//platforms:linux-x86_32#…) targets x86
    root//tcc:tcc.o          (root//platforms:linux-x86_32#…) targets x86

The i386 `tcc-mes` that compiles and links working programs was produced by an
amd64 `mes-m2` and assembled by an amd64 `M1` and `hex2`.

**The policy, then: native for everything that runs, x86 for everything that is
produced, until tcc can be built for x86_64.** 32-bit execution is needed from
`tcc-mes` onward and no earlier, because tcc carries its target in the binary
and its boot chain is self-hosting — a cross tcc hosted on amd64 would buy
exactly one step, since the tcc it emits is i386 and has to run to make the
next one.

The one measured cost: an amd64 `mes-m2` spends about 1.3G at
`MES_MAX_ARENA=50000000` because its cells are 64-bit, roughly twice what an
i686 one would. That is the price of not being Guix here, and it is worth
paying while it is only MesCC that pays it.

## Housekeeping, first

Done before the boot chain, so that nothing after it is written twice.

1. **Split the CPU constraint in two.** `root//constraints:cpu` currently means
   both "what this runs on" and "what this targets". The bootstrap layer wants
   the first; binutils and GCC want the second. Everything else follows from
   this.
2. **Pin what `//mes` and `//tcc` target, not where they run.** Where they run
   is already right: the tools are `exec_dep`s and come out native. What is
   wrong is the default target. `target_platform_detector_spec` sends
   everything to `//platforms:linux-x86_64`, so a bare `buck2 build
   //tcc:tcc_mes` spends ten minutes of arena-bound MesCC work producing the
   amd64 compiler that cannot do varargs, rather than the x86 one that works.
   The bootstrap layer should resolve to an x86 target however it is asked for.
3. **Rework `COMPATIBLE_WITH`.** The aarch64 trick in `mes/defs.bzl` — asking
   for a CPU the platform cannot have, so buck2 skips the target rather than
   failing to resolve a `select` — exists only because the bootstrap layer is
   configured per target CPU. Once it is pinned, aarch64 stops reaching these
   targets by itself.
4. **Decide what the amd64 native path is for.** `MESCC_FIXES`, `LINKER_FIXES`,
   `REWRITTEN_SOURCES`, the `x86_64-gen.c` and `tccelf.c` rewrites,
   `EXTRA_OBJECTS`, and the amd64 `HAVE_LONG_LONG` in `CPU_DEFINES` are all
   only reachable from a 64-bit Mes and tcc. They are not the road to GCC, but
   they are close to working and they are the only route on a machine with no
   i686 emulation. Keep them as a documented non-default, or delete them and
   keep only the notes below. Do not leave them looking like the main path.
5. **Give the downloads one place to live.** `TCC_URLS` and `TCC_SHA256` are
   the first of about a dozen: gzip, make twice, tcc 0.9.27, patch, binutils,
   GCC three times, glibc twice, gawk. One table of name, version, mirrors and
   hash, rather than a pair of constants per package.
6. **Settle where kernel headers come from.** Everything from glibc 2.2.5
   onward needs them. Guix seeds a pre-stripped i686 tarball, which is a binary
   seed we would rather not take; the alternative is unpacking a kernel tarball
   for its headers only.
7. **Say what the execution platform is.** `//platforms:default` hardwires
   `linux-x86_64`, which is right — it is the machine — but it reads like a
   target choice, and after the split it should not.
8. **Make `//stage0:check` cover the binaries that do the work.** It is a
   target-configured product, so it hashes the tools in the target
   configuration while the ones assembling and linking are the exec-configured
   copies. Today those are byte for byte the same file, because the default
   target platform and the execution platform are both x86_64 — so the check is
   sound by coincidence rather than by construction. Once the bootstrap layer
   targets x86, the check would be verifying an x86 stage0 that never runs.

## Next: finishing tcc

Small and mechanical, and needed whichever route the middle takes.

1. **The boot chain** — `tcc-mes` builds `tcc-boot0` builds `tcc-boot1`, and so
   on to `tcc-boot5`, until two successive compilers come out identical.
   Upstream checks that by hand with `cmp`; here it can be a target, so the
   fixpoint is asserted by the build rather than by a person.
2. **tcc 0.9.27** — another download, and what everything downstream uses.
   Guix forces `s->static_link = 1;` into `libtcc.c` for it
   (`commencement.scm:755`), so the rewrites here are not a deviation from how
   this is normally done.

## The middle

Guix's route from tcc to a working GCC, in order, all of it i686:

| | package | version |
|---|---|---|
| 1 | gzip-mesboot | 1.2.4 |
| 2 | gnu-make-mesboot0 | 3.80 |
| 3 | tcc-boot | 0.9.27 |
| 4 | patch-mesboot | 2.5.9 |
| 5 | binutils-mesboot0 | 2.20.1a |
| 6 | gcc-core-mesboot0 | 2.95.3 |
| 7 | mesboot-headers | — |
| 8 | glibc-mesboot0 | 2.2.5 |
| 9 | gcc-mesboot0 | 2.95.3 |
| 10 | binutils-mesboot1 | 2.20.1a |
| 11 | gnu-make-mesboot | 3.82 |
| 12 | gcc-core-mesboot1 | 4.6.4 |
| 13 | gcc-mesboot1 | 4.6.4 |
| 14 | binutils-mesboot | 2.20.1a |
| 15 | gawk-mesboot | 3.1.8 |
| 16 | glibc-headers-mesboot | 2.16.0 |
| 17 | glibc-mesboot | 2.16.0 |
| 18 | gcc-mesboot | 4.9.4 |

Then bash, coreutils, grep, sed, tar and xz, and then the cross toolchain to
whatever the target platform actually is.

That is far shorter than live-bootstrap's sixty-odd steps, because most of
those are perl, autoconf, automake and libtool, which exist to satisfy build
systems we do not run. It is longer than it looks in one place: GCC is built
three times and glibc twice, because each one only just about compiles with the
one before it.

## About the shell

A shell is not what stands between here and GCC.

live-bootstrap builds `bash-2.05b` at step fourteen, *after* make, patch, gzip,
tar, sed, bzip2 and coreutils. Those are all built without one: their
`pass1.kaem` scripts run under kaem, invoke tcc once per source file, pass
`-D` flags instead of detecting features, and make an empty `config.h` with
`catm`. That is the same shape as what this repository already does for Mes and
tcc, written imperatively instead of declaratively.

Guix answers it differently: it carries Gash and Gash-Utils, a Scheme shell and
coreutils, and uses them from the very first package. We have neither, and
Buck2 is our make. kaem covers the one case that genuinely needs a working
directory, which is `untar`.

## The decision to make, later

At binutils, one of two routes:

- **Transcribe the builds into Buck2 rules.** No shell, ever. Every compile is
  a declared action with declared inputs. Expensive: these are large builds,
  though GCC's generated sources come from generators (`genattrtab` and its
  siblings) that are themselves C programs, which suits Buck2 well.
- **Build bash 2.05b with tcc under kaem, then wrap `configure && make` in Buck
  actions.** Reaches GCC far sooner and stays hermetic, but Buck2 becomes an
  orchestrator around build steps it cannot see into.

Worth deferring until binutils is actually in front of us, where the difference
in cost is real rather than estimated.

## Notes worth keeping

- **MesCC's memory** is set by `MES_MAX_ARENA`, and Mes grows the arena to that
  maximum at every collection: the maximum is what a compile costs, not a
  ceiling it approaches. Compiling all of tcc as one translation unit needs
  more than 35000000 cells (it dies of a segmentation fault, silently) and is
  happy at 42000000. `//tcc` asks for 50000000, about 1.3G.
- **MesCC bakes the output file name into its string labels**, so the assembly
  it emits depends on where it is written. Buck2 output paths are stable, so
  this is deterministic here, but two builds under different roots will not
  produce identical `.s` files.
- **Which CPU MesCC targets is baked into its script**, not passed on the
  command line, so `mescc` is a `dep` and not an `exec_dep`. Only Mes itself
  has to run on the build machine. The same is true of tcc, except that tcc is
  a binary for its target rather than a script, so a cross build produces a
  compiler the build machine cannot run.
- **A static struct initialised with string literals is not copied by MesCC.**
  `tcc -ar` writes its member headers from a `static ArHdr` declared that way,
  so the archives a MesCC-built tcc produces have pointers where `ar(1)` wants
  text and GNU `ar` calls them malformed. tcc reads its own archives by size
  and links them correctly, which is what upstream has always relied on. This
  one bites on every CPU.
- **A `tcc_debug` target exists** for when the compiler itself is the thing
  that is wrong: same binary, linked with a blood-elf symbol table, so gdb can
  name what it stopped in. It is how the next three notes were found.

### Why amd64 is not a bootstrap CPU

Kept because it took a day to establish, and because it is the argument for the
shape above.

- **MesCC does not copy a struct that initialises a declaration.** `T a = b;`
  where both are structs stores the address of `b` in the first member of `a`
  and leaves the rest whatever was on the stack; `T a; a = b;` is correct.
  `x86_64-gen.c`'s `gfunc_call` writes `SValue tmp = vtop[0];`, so the value
  stack filled with pointers and tcc died in `assert(0)` under `case
  VT_LDOUBLE` — the low nibble of the address decided which case it landed in,
  which is why it depended on how many arguments a call had.
- **tcc 0.9.26 cannot link a static executable on x86_64 unaided.** Every call
  to a global goes through a PLT stub, and the stubs are pointed at the GOT by
  `relocate_plt`, which runs only when there is a dynamic section. `fill_got`
  puts the right addresses in the GOT and the stubs jump into the middle of the
  PLT. Resolving the relocation straight to the symbol when `static_link` is
  set is what newer tcc does, and what i386 does already by never building a
  PLT at all.
- **Mes' C library has no varargs for a register-passing compiler on x86_64.**
  `stdarg.h` is a plain `char *` walked up the stack, right for MesCC, which
  passes everything on the stack, and right for i386. On x86_64 the first six
  integer arguments arrive in registers, so `printf` reads its own format
  string where `%s` should be. Mes has a fudge for this — `ap += (__FOO_VARARGS
  + (__FUNCTION_ARGS << 1)) << 3` in `printf.c` — but only under `__GNUC__`,
  tuned to where GCC puts its register save area; `__riscv` is the one target
  that reaches for `__builtin_va_arg` instead. Fixing it means giving
  `stdarg.h` a `__TINYC__ && __x86_64__` branch and `libtcc1` the `__va_start`
  and `__va_arg` that tcc's own headers expect. That is a port of Mes' C
  library. `TCC_MES_LIBC` looks like it should help and does not: every script
  passes it and no source reads it.
- **Upstream's tcc recipe assumes x86 in three more places.** On x86_64 it
  needs `HAVE_LONG_LONG=1`, because `elf.h` hides the 64-bit ELF typedefs
  behind it but not the structures that use them; it needs `ONE_SOURCE=1`,
  because there is no `x86_64-asm.c` to compile on its own; and it needs
  `abort`, which only `x86_64-gen.c` calls and which upstream keeps in
  `libc+gnu.a` rather than `libc+tcc.a`.
