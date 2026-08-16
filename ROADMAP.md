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
  It runs and compiles C to ELF objects on amd64, x86 and riscv64.

Everything is built for four target platforms, of which Mes and tcc support
three: there is no aarch64 port of Mes, and those targets are skipped rather
than failed.

## Next: finishing tcc

Small and mechanical, and needed whichever route the middle takes.

1. **Rebuild the C library with tcc** — the `REBUILD_LIBC` half of
   `bootstrap.sh`: `crt1.o`, `crti.o`, `crtn.o`, `libc.a` from Mes'
   `libc+gnu.c`, `libtcc1.a` and `libgetopt.a`, all compiled by `tcc_mes`.
   Until this happens tcc links against hex2-format objects that MesCC made;
   after it, tcc stands on what it produced itself.
2. **The boot chain** — `tcc-mes` builds `tcc-boot0` builds `tcc-boot1`, and so
   on to `tcc-boot5`, until two successive compilers come out identical.
   Upstream checks that by hand with `cmp`; here it can be a target, so the
   fixpoint is asserted by the build rather than by a person.
3. **tcc 0.9.27** — another download, and what everything downstream uses.

## The middle

live-bootstrap runs about sixty steps between tcc and `gcc-4.0.4`. Most of them
are not about compiling anything we want: perl five times, autoconf nine times,
automake eight, libtool, help2man. They are there to satisfy the build systems
of the packages that follow.

We do not run `configure` and we do not run `automake`, so nearly all of that
disappears. What is actually required is:

- **musl 1.1.24** (or glibc 2.2.5, the older Guix route) — GCC needs a C
  library that is not Mes'.
- **binutils** — unavoidable. GCC emits assembly text and shells out to `as`
  and `ld`. tcc's integrated assembler does not help, because GCC will not call
  it.
- **GCC** itself, 4.0.4 on live-bootstrap's route, or 2.95.3 first on Guix's.

## About the shell

A shell is not what stands between here and GCC.

live-bootstrap builds `bash-2.05b` at step fourteen, *after* make, patch, gzip,
tar, sed, bzip2 and coreutils. Those are all built without one: their
`pass1.kaem` scripts run under kaem, invoke tcc once per source file, pass
`-D` flags instead of detecting features, and make an empty `config.h` with
`catm`. That is the same shape as what this repository already does for Mes and
tcc, written imperatively instead of declaratively.

Buck2 is our make. kaem covers the one case that genuinely needs a working
directory, which is `untar`. So the question is not whether a shell can be
avoided, but whether avoiding it is worth what it costs at binutils and GCC
scale.

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
- **Upstream's tcc recipe assumes x86.** On x86_64 it needs `HAVE_LONG_LONG=1`,
  because `elf.h` hides the 64-bit ELF typedefs behind it but not the
  structures that use them; it needs `ONE_SOURCE=1`, because there is no
  `x86_64-asm.c` to compile on its own; and it needs `abort`, which only
  `x86_64-gen.c` calls and which upstream keeps in `libc+gnu.a` rather than
  `libc+tcc.a`.
- **Which CPU MesCC targets is baked into its script**, not passed on the
  command line, so `mescc` is a `dep` and not an `exec_dep`. Only Mes itself
  has to run on the build machine.
