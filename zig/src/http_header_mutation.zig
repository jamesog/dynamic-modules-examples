//! HTTP Header Mutation Filter
//!
//! Demonstrates setting/removing request and response headers, and accessing request attributes.

const std = @import("std");
const envoy = @import("envoy-dynamic-modules");

const Header = struct {
    key: []const u8,
    value: []const u8,
};

const Config = struct {
    request_headers: []const [2][]const u8 = &.{},
    remove_request_headers: []const []const u8 = &.{},
    response_headers: []const [2][]const u8 = &.{},
    remove_response_headers: []const []const u8 = &.{},
};

pub const FilterConfig = struct {
    allocator: std.mem.Allocator,
    request_headers: []Header,
    remove_request_headers: [][]const u8,
    response_headers: []Header,
    remove_response_headers: [][]const u8,

    pub fn init(config: []const u8) !*FilterConfig {
        const allocator = std.heap.c_allocator;
        const self = try allocator.create(FilterConfig);
        errdefer allocator.destroy(self);

        // Parse JSON config
        const parsed = std.json.parseFromSlice(Config, allocator, config, .{}) catch {
            envoy.logError("Failed to parse header mutation config", .{});
            allocator.destroy(self);
            return error.InvalidConfig;
        };
        defer parsed.deinit();

        // Convert to owned slices
        var req_headers = std.ArrayList(Header).init(allocator);
        for (parsed.value.request_headers) |h| {
            try req_headers.append(.{
                .key = try allocator.dupe(u8, h[0]),
                .value = try allocator.dupe(u8, h[1]),
            });
        }

        var rem_req_headers = std.ArrayList([]const u8).init(allocator);
        for (parsed.value.remove_request_headers) |h| {
            try rem_req_headers.append(try allocator.dupe(u8, h));
        }

        var resp_headers = std.ArrayList(Header).init(allocator);
        for (parsed.value.response_headers) |h| {
            try resp_headers.append(.{
                .key = try allocator.dupe(u8, h[0]),
                .value = try allocator.dupe(u8, h[1]),
            });
        }

        var rem_resp_headers = std.ArrayList([]const u8).init(allocator);
        for (parsed.value.remove_response_headers) |h| {
            try rem_resp_headers.append(try allocator.dupe(u8, h));
        }

        self.* = .{
            .allocator = allocator,
            .request_headers = try req_headers.toOwnedSlice(),
            .remove_request_headers = try rem_req_headers.toOwnedSlice(),
            .response_headers = try resp_headers.toOwnedSlice(),
            .remove_response_headers = try rem_resp_headers.toOwnedSlice(),
        };

        envoy.logInfo("Header mutation filter config created", .{});
        return self;
    }

    pub fn deinit(self: *FilterConfig) void {
        for (self.request_headers) |h| {
            self.allocator.free(h.key);
            self.allocator.free(h.value);
        }
        self.allocator.free(self.request_headers);

        for (self.remove_request_headers) |h| {
            self.allocator.free(h);
        }
        self.allocator.free(self.remove_request_headers);

        for (self.response_headers) |h| {
            self.allocator.free(h.key);
            self.allocator.free(h.value);
        }
        self.allocator.free(self.response_headers);

        for (self.remove_response_headers) |h| {
            self.allocator.free(h);
        }
        self.allocator.free(self.remove_response_headers);

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

    pub fn onRequestHeaders(self: *Filter, _: envoy.HttpFilterEnvoyPtr, _: bool) envoy.FilterHeadersStatus {
        // Note: SDK doesn't expose set/remove header functions yet
        // Would need to call C functions directly or wait for SDK enhancement
        _ = self;
        return envoy.c.envoy_dynamic_module_type_on_http_filter_request_headers_status_Continue;
    }

    pub fn onRequestBody(_: *Filter, _: envoy.HttpFilterEnvoyPtr, _: bool) envoy.FilterDataStatus {
        return envoy.c.envoy_dynamic_module_type_on_http_filter_request_body_status_Continue;
    }

    pub fn onRequestTrailers(_: *Filter, _: envoy.HttpFilterEnvoyPtr) envoy.FilterTrailersStatus {
        return envoy.c.envoy_dynamic_module_type_on_http_filter_request_trailers_status_Continue;
    }

    pub fn onResponseHeaders(self: *Filter, _: envoy.HttpFilterEnvoyPtr, _: bool) envoy.FilterHeadersStatus {
        // Note: SDK doesn't expose attribute access yet
        // Would need enhancement or direct C calls
        _ = self;
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
