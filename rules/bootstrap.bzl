# SPDX-FileCopyrightText: 2026 Jean-Pierre De Jesus DIAZ <me@jeandudey.tech>
# SPDX-License-Identifier: Apache-2.0 OR MIT

def _hex_prebuilt_impl(ctx: AnalysisContext) -> list[Provider]:
    return [
        DefaultInfo(default_output = ctx.attrs.hex),
        RunInfo(args = cmd_args(ctx.attrs.hex)),
    ]

bootstrap_hex_prebuilt = rule(
    impl = _hex_prebuilt_impl,
    attrs = {
        "hex": attrs.source(),
    },
)

def _hex_assemble_impl(ctx: AnalysisContext) -> list[Provider]:
    out = ctx.actions.declare_output(ctx.label.name)
    ctx.actions.run(
        cmd_args(ctx.attrs.assembler[RunInfo], ctx.attrs.src, out.as_output()),
        category = "bootstrap_hex",
        identifier = ctx.label.name,
    )
    return [
        DefaultInfo(default_output = out),
        RunInfo(args = cmd_args(out)),
    ]

bootstrap_hex_assemble = rule(
    impl = _hex_assemble_impl,
    attrs = {
        "assembler": attrs.exec_dep(providers = [RunInfo]),
        "src": attrs.source(),
    },
)

def _concat_file_impl(ctx: AnalysisContext) -> list[Provider]:
    out = ctx.actions.declare_output(ctx.label.name)
    ctx.actions.run(
        cmd_args(ctx.attrs.catm[RunInfo], out.as_output(), ctx.attrs.srcs),
        category = "bootstrap_catm",
        identifier = ctx.label.name,
    )
    return [DefaultInfo(default_output = out)]

bootstrap_concat_file = rule(
    impl = _concat_file_impl,
    attrs = {
        "catm": attrs.exec_dep(providers = [RunInfo]),
        "srcs": attrs.list(attrs.source()),
    },
)

def _m0_assemble_impl(ctx: AnalysisContext) -> list[Provider]:
    out = ctx.actions.declare_output(ctx.label.name)
    ctx.actions.run(
        cmd_args(ctx.attrs.assembler[RunInfo], ctx.attrs.src, out.as_output()),
        category = "bootstrap_m0",
        identifier = ctx.label.name,
    )
    return [
        DefaultInfo(default_output = out),
        RunInfo(args = cmd_args(out)),
    ]

bootstrap_m0_assemble = rule(
    impl = _m0_assemble_impl,
    attrs = {
        "assembler": attrs.exec_dep(providers = [RunInfo]),
        "src": attrs.source(),
    },
)

def _cc_compile_impl(ctx: AnalysisContext) -> list[Provider]:
    out = ctx.actions.declare_output(ctx.label.name)
    ctx.actions.run(
        cmd_args(ctx.attrs.compiler[RunInfo], ctx.attrs.src, out.as_output()),
        category = "bootstrap_cc",
        identifier = ctx.label.name,
    )
    return [
        DefaultInfo(default_output = out),
        RunInfo(args = cmd_args(out)),
    ]

bootstrap_cc_compile = rule(
    impl = _cc_compile_impl,
    attrs = {
        "compiler": attrs.exec_dep(providers = [RunInfo]),
        "src": attrs.source(),
    },
)

def _m2_compile_impl(ctx: AnalysisContext) -> list[Provider]:
    out = ctx.actions.declare_output(ctx.label.name)
    cmd = cmd_args(ctx.attrs.compiler[RunInfo], "--architecture", ctx.attrs.architecture)
    for src in ctx.attrs.srcs:
        cmd.add("-f", src)
    if ctx.attrs.bootstrap_mode:
        cmd.add("--bootstrap-mode")
    if ctx.attrs.debug:
        cmd.add("--debug")
    cmd.add("-o", out.as_output())
    ctx.actions.run(
        cmd,
        category = "bootstrap_m2",
        identifier = ctx.label.name,
    )
    return [DefaultInfo(default_output = out)]

bootstrap_m2_compile = rule(
    impl = _m2_compile_impl,
    attrs = {
        "compiler": attrs.exec_dep(providers = [RunInfo]),
        "srcs": attrs.list(attrs.source()),
        "architecture": attrs.string(),
        "bootstrap_mode": attrs.bool(default = False),
        "debug": attrs.bool(default = False),
    },
)

def _m1_assemble_impl(ctx: AnalysisContext) -> list[Provider]:
    out = ctx.actions.declare_output(ctx.label.name)
    cmd = cmd_args(
        ctx.attrs.assembler[RunInfo],
        "--architecture",
        ctx.attrs.architecture,
        ctx.attrs.endianness,
    )
    for src in ctx.attrs.srcs:
        cmd.add("-f", src)
    cmd.add("-o", out.as_output())
    ctx.actions.run(
        cmd,
        category = "bootstrap_m1",
        identifier = ctx.label.name,
    )
    return [DefaultInfo(default_output = out)]

bootstrap_m1_assemble = rule(
    impl = _m1_assemble_impl,
    attrs = {
        "assembler": attrs.exec_dep(providers = [RunInfo]),
        "srcs": attrs.list(attrs.source()),
        "architecture": attrs.string(),
        "endianness": attrs.string(default = "--little-endian"),
    },
)

def _hex2_link_impl(ctx: AnalysisContext) -> list[Provider]:
    out = ctx.actions.declare_output(ctx.label.name)
    cmd = cmd_args(
        ctx.attrs.linker[RunInfo],
        "--architecture",
        ctx.attrs.architecture,
        ctx.attrs.endianness,
        "--base-address",
        ctx.attrs.base_address,
    )
    for src in ctx.attrs.srcs:
        cmd.add("-f", src)
    cmd.add("-o", out.as_output())
    ctx.actions.run(
        cmd,
        category = "bootstrap_hex2",
        identifier = ctx.label.name,
    )
    return [
        DefaultInfo(default_output = out),
        RunInfo(args = cmd_args(out)),
    ]

bootstrap_hex2_link = rule(
    impl = _hex2_link_impl,
    attrs = {
        "linker": attrs.exec_dep(providers = [RunInfo]),
        "srcs": attrs.list(attrs.source()),
        "architecture": attrs.string(),
        "base_address": attrs.string(),
        "endianness": attrs.string(default = "--little-endian"),
    },
)

def _blood_elf_impl(ctx: AnalysisContext) -> list[Provider]:
    out = ctx.actions.declare_output(ctx.attrs.out or ctx.label.name)
    # blood-elf assumes 32-bit and rejects a --32 it doesn't know about.
    word_size = ["--64"] if ctx.attrs.word_size == "64" else []
    ctx.actions.run(
        cmd_args(
            ctx.attrs.blood_elf[RunInfo],
            word_size,
            ctx.attrs.endianness,
            "-f", ctx.attrs.src,
            "-o", out.as_output(),
        ),
        category = "bootstrap_blood_elf",
        identifier = ctx.label.name,
    )
    return [DefaultInfo(default_output = out)]

bootstrap_blood_elf = rule(
    impl = _blood_elf_impl,
    attrs = {
        "blood_elf": attrs.exec_dep(providers = [RunInfo]),
        "src": attrs.source(),
        "word_size": attrs.enum(["32", "64"]),
        "endianness": attrs.string(default = "--little-endian"),
        "out": attrs.option(attrs.string(), default = None),
    },
)
