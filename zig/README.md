# Zig Dynamic Module Examples

This directory contains examples of Envoy dynamic modules implemented in Zig.

## Overview

Zig is a great language for implementing Envoy dynamic modules because:
- It can easily interface with C ABIs without FFI overhead
- It provides memory safety features
- It has excellent cross-compilation support
- The build system is simple and powerful

## Implementation

These examples implement the Envoy dynamic module ABI directly using Zig's C interop features. The implementation includes:

- **abi.zig**: Defines the C ABI bindings for Envoy callbacks and data structures
- **http_passthrough.zig**: A simple passthrough filter that does nothing
- **http_header_mutation.zig**: Mutates request and response headers based on configuration
- **http_random_auth.zig**: Randomly rejects requests with 403 status
- **http_access_logger.zig**: Logs request and response information (simplified)
- **http_metrics.zig**: Records per-route latency metrics (simplified)

## Building

To build the Zig module locally:

```bash
cd zig
zig build
```

The shared library will be created in `zig-out/lib/libzig_module.so` (or `.dylib` on macOS, `.dll` on Windows).

## Testing

To run the tests:

```bash
cd zig
zig build test
```

## Requirements

- Zig 0.12.0 or later

## Notes

These examples demonstrate the core concepts of implementing Envoy dynamic modules in Zig. Some features are simplified compared to the Rust examples:

- The access logger doesn't use worker threads for file I/O
- The metrics filter prints to stdout rather than using Envoy's metrics API (which would require additional ABI bindings)
- No regex WAF example is included yet (would require a regex library)

## Configuration

Each filter accepts configuration in JSON format, matching the Rust examples. See the Rust README and integration tests for configuration examples.

## Integration with Envoy

To use these modules with Envoy, specify the path to `libzig_module.so` in your Envoy configuration's `DynamicModuleConfig`.
