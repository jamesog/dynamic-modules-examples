const std = @import("std");
const abi = @import("abi.zig");

/// Passthrough filter that does nothing - just passes requests through
pub const FilterConfig = struct {
    config: []const u8,

    pub fn create(config: []const u8) usize {
        const allocator = std.heap.c_allocator;
        const filter_config = allocator.create(FilterConfig) catch return 0;

        // Store a copy of the config
        const config_copy = allocator.dupe(u8, config) catch {
            allocator.destroy(filter_config);
            return 0;
        };

        filter_config.* = FilterConfig{
            .config = config_copy,
        };

        return @intFromPtr(filter_config);
    }

    pub fn destroy(self: *FilterConfig) void {
        const allocator = std.heap.c_allocator;
        allocator.free(self.config);
        allocator.destroy(self);
    }
};

/// Filter instance - does nothing, just returns Continue for all phases
pub const Filter = struct {
    pub fn onRequestHeaders(
        _: *Filter,
        _: abi.EnvoyHttpFilter,
        _: bool,
    ) abi.RequestHeadersStatus {
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
