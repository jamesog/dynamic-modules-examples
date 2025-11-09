# Zig Dynamic Module Examples

This directory contains examples of Envoy dynamic modules implemented using the Zig SDK.

## Overview

These examples use the Zig SDK from the Envoy repository to implement HTTP filters. The SDK is vendored in the `sdk/` directory (similar to the Go SDK approach) to make the examples self-contained.

## Architecture

**Proper SDK Pattern:**
- **sdk/**: Vendored Zig SDK from `envoyproxy/envoy/source/extensions/dynamic_modules/sdk/zig/`
  - Provides type-safe wrappers around the C ABI
  - Handles @cImport of abi.h and abi_version.h
  - Offers Zig-idiomatic logging and buffer helpers
- **src/**: Example filter implementations
  - Import the SDK as `@import("envoy-dynamic-modules")`
  - Implement only filter-specific logic
  - No duplication of ABI bindings

This follows the pattern established by:
- **Rust**: References SDK from Envoy repo via Cargo dependency
- **Go**: Vendors SDK in `gosdk/` directory for self-contained examples

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

- **Passthrough Filter**: Demonstrates basic SDK usage with a minimal filter that passes all requests through

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
