# Zig Dynamic Module Examples

This directory contains examples of Envoy dynamic modules implemented using the Zig SDK.

## Overview

These examples use the Zig SDK from the Envoy repository to implement HTTP filters. The SDK is vendored in the `sdk/` directory (similar to the Go SDK approach) to make the examples self-contained.

## Architecture

**SDK Pattern:**
- **sdk/**: Vendored Zig SDK from `envoyproxy/envoy/source/extensions/dynamic_modules/sdk/zig/`
  - Provides type-safe wrappers around the C ABI
  - Handles @cImport of abi.h and abi_version.h
  - Offers Zig-idiomatic logging and buffer helpers
- **src/**: Example filter implementations
  - Import the SDK as `@import("envoy-dynamic-modules")`
  - Implement only filter-specific logic
  - No duplication of ABI bindings

**Why vendor instead of using build.zig.zon?**

The SDK is vendored (copied) here because:
1. The Envoy repo is too large (~12k files, 100s of MB) to fetch as a dependency
2. Zig's package manager can't fetch from subdirectories of git repos
3. Examples should be self-contained and easy to build (`git clone && zig build`)

**Future: Dedicated SDK repo**

The proper long-term solution is creating `envoyproxy/envoy-dynamic-modules-zig-sdk` (like Rust has), then using:
```zig
// In build.zig.zon
.dependencies = .{
    .@"envoy-dynamic-modules" = .{
        .url = "https://github.com/envoyproxy/envoy-dynamic-modules-zig-sdk/archive/vX.Y.Z.tar.gz",
        .hash = "...",
    },
}
```

Until then, vendoring follows Go's approach and is the cleanest option.

## Building

To build the Zig module locally:

```bash
cd zig
zig build
```

The shared library will be created in `zig-out/lib/libzig_module.so`.

## Testing

To run the tests:

```bash
cd zig
zig build test
```

## Requirements

- Zig 0.14.0 or later

## Current Examples

- **http_passthrough**: Minimal passthrough filter demonstrating basic SDK usage
- **http_header_mutation**: Mutates request/response headers based on JSON config (Note: Partially implemented - SDK needs header manipulation functions)
- **http_random_auth**: Randomly rejects requests with 403 status (Note: Partially implemented - SDK needs sendLocalReply function)

**What's Different from Rust Examples?**

The Zig SDK (vendored from the Envoy repo) is still evolving. Some features available in Rust are not yet exposed in the Zig SDK:
- Header manipulation functions (set/remove headers)
- Attribute access (source address, response code, etc.)
- Send local reply functionality
- Metrics API

These examples show the pattern for implementing filters and note where SDK enhancements are needed. Filters can still be implemented by calling C functions directly via `envoy.c.*`.

## Adding New Filters

To add a new filter:

1. Import the SDK: `const envoy = @import("envoy-dynamic-modules");`
2. Implement FilterConfig and Filter structs
3. Export the required C ABI functions
4. Use SDK helpers like `envoy.logInfo()`, `envoy.c.kAbiVersion`, etc.

See `src/main.zig` for a complete example.

## SDK Synchronization

The SDK in `sdk/` is copied from the Envoy repository. To update it:

```bash
# From a clone of envoyproxy/envoy
cp source/extensions/dynamic_modules/sdk/zig/lib.zig zig/sdk/
cp source/extensions/dynamic_modules/abi.h zig/sdk/
cp source/extensions/dynamic_modules/abi_version.h zig/sdk/
```

## Integration with Envoy

To use these modules with Envoy, specify the path to `libzig_module.so` in your Envoy configuration's `DynamicModuleConfig`.
