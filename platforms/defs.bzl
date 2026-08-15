# SPDX-FileCopyrightText: 2026 Jean-Pierre De Jesus DIAZ <me@jeandudey.tech>
# SPDX-License-Identifier: Apache-2.0 OR MIT

def _execution_platforms_impl(ctx: AnalysisContext) -> list[Provider]:
    platform = ExecutionPlatformInfo(
        label = ctx.label.raw_target(),
        configuration = ctx.attrs.platform[PlatformInfo].configuration,
        executor_config = CommandExecutorConfig(
            local_enabled = True,
            remote_enabled = True,
            use_limited_hybrid = True,
            remote_execution_properties = {
                "OSFamily": "linux",
                "container-image": "",
            },
            remote_execution_use_case = "buck2-default",
            remote_output_paths = "output_paths",
        ),
    )
    return [
        DefaultInfo(),
        ExecutionPlatformRegistrationInfo(platforms = [platform]),
    ]

execution_platforms = rule(
    impl = _execution_platforms_impl,
    attrs = {
        "platform": attrs.dep(providers = [PlatformInfo]),
    },
)
