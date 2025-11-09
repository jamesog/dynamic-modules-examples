//! HTTP Passthrough Filter
//!
//! A simple passthrough filter that does nothing - demonstrates minimal SDK usage.

const std = @import("std");
const envoy = @import("envoy-dynamic-modules");

pub const FilterConfig = struct {
    allocator: std.mem.Allocator,
    config_data: []const u8,

    pub fn init(config: []const u8) !*FilterConfig {
        const allocator = std.heap.c_allocator;
        const self = try allocator.create(FilterConfig);
        errdefer allocator.destroy(self);

        self.* = .{
            .allocator = allocator,
            .config_data = try allocator.dupe(u8, config),
        };

        envoy.logInfo("Passthrough filter config created", .{});
        return self;
    }

    pub fn deinit(self: *FilterConfig) void {
        self.allocator.free(self.config_data);
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
