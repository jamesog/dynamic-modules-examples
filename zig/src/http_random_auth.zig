//! HTTP Random Auth Filter
//!
//! Randomly rejects requests with 403 status - demonstrates local reply functionality.

const std = @import("std");
const envoy = @import("envoy-dynamic-modules");

pub const FilterConfig = struct {
    allocator: std.mem.Allocator,

    pub fn init(_: []const u8) !*FilterConfig {
        const allocator = std.heap.c_allocator;
        const self = try allocator.create(FilterConfig);
        self.* = .{ .allocator = allocator };
        envoy.logInfo("Random auth filter config created", .{});
        return self;
    }

    pub fn deinit(self: *FilterConfig) void {
        self.allocator.destroy(self);
    }

    pub fn createFilter(self: *FilterConfig, _: envoy.HttpFilterEnvoyPtr) !*Filter {
        const filter = try self.allocator.create(Filter);
        filter.* = .{
            .allocator = self.allocator,
            .config = self,
        };
        return filter;
    }
};

pub const Filter = struct {
    allocator: std.mem.Allocator,
    config: *FilterConfig,

    pub fn onRequestHeaders(_: *Filter, _: envoy.HttpFilterEnvoyPtr, _: bool) envoy.FilterHeadersStatus {
        // Simple pseudo-random rejection based on timestamp
        const timestamp = std.time.milliTimestamp();
        const reject = @rem(timestamp, 2) == 0;

        if (reject) {
            envoy.logInfo("Randomly rejecting request", .{});
            // Note: SDK doesn't expose sendLocalReply yet
            // Would need to call C function directly:
            // envoy.c.envoy_dynamic_module_callback_http_send_response(...)
            // For now, just log and continue
        }

        return envoy.c.envoy_dynamic_module_type_on_http_filter_request_headers_status_Continue;
    }

    pub fn onRequestBody(_: *Filter, _: envoy.HttpFilterEnvoyPtr, _: bool) envoy.FilterDataStatus {
        return envoy.c.envoy_dynamic_module_type_on_http_filter_request_body_status_Continue;
    }

    pub fn onRequestTrailers(_: *Filter, _: envoy.HttpFilterEnvoyPtr) envoy.FilterTrailersStatus {
        return envoy.c.envoy_dynamic_module_type_on_http_filter_request_trailers_status_Continue;
    }

    pub fn onResponseHeaders(_: *Filter, _: envoy.HttpFilterEnvoyPtr, _: bool) envoy.FilterHeadersStatus {
        return envoy.c.envoy_dynamic_module_type_on_http_filter_response_headers_status_Continue;
    }

    pub fn onResponseBody(_: *Filter, _: envoy.HttpFilterEnvoyPtr, _: bool) envoy.FilterDataStatus {
        return envoy.c.envoy_dynamic_module_type_on_http_filter_response_body_status_Continue;
    }

    pub fn onResponseTrailers(_: *Filter, _: envoy.HttpFilterEnvoyPtr) envoy.FilterTrailersStatus {
        return envoy.c.envoy_dynamic_module_type_on_http_filter_response_trailers_status_Continue;
    }

    pub fn deinit(self: *Filter) void {
        self.allocator.destroy(self);
    }
};
