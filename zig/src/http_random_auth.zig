const std = @import("std");
const abi = @import("abi.zig");

/// Random auth filter - randomly rejects requests with 403
pub const FilterConfig = struct {
    pub fn create(_: []const u8) usize {
        const allocator = std.heap.c_allocator;
        const filter_config = allocator.create(FilterConfig) catch return 0;
        filter_config.* = FilterConfig{};
        return @intFromPtr(filter_config);
    }

    pub fn destroy(self: *FilterConfig) void {
        const allocator = std.heap.c_allocator;
        allocator.destroy(self);
    }

    pub fn newFilter(_: *FilterConfig) Filter {
        return Filter{};
    }
};

pub const Filter = struct {
    pub fn onRequestHeaders(
        _: *Filter,
        envoy: abi.EnvoyHttpFilter,
        _: bool,
    ) abi.RequestHeadersStatus {
        // Use a simple pseudo-random check
        // Get current timestamp as a simple random source
        const timestamp = std.time.milliTimestamp();
        const reject = @rem(timestamp, 2) == 0;

        if (reject) {
            envoy.sendResponse(403, "Access forbidden");
            return .StopIteration;
        }

        return .Continue;
    }

    pub fn onRequestBody(
        _: *Filter,
        _: abi.EnvoyHttpFilter,
        _: bool,
    ) abi.RequestBodyStatus {
        return .Continue;
    }

    pub fn onResponseHeaders(
        _: *Filter,
        _: abi.EnvoyHttpFilter,
        _: bool,
    ) abi.ResponseHeadersStatus {
        return .Continue;
    }

    pub fn onResponseBody(
        _: *Filter,
        _: abi.EnvoyHttpFilter,
        _: bool,
    ) abi.ResponseBodyStatus {
        return .Continue;
    }
};
