//! Envoy Dynamic Module Examples in Zig
//!
//! This demonstrates various HTTP filters implemented using the Zig SDK.

const std = @import("std");
const envoy = @import("envoy-dynamic-modules");

// ============================================================================
// Program Initialization
// ============================================================================

export fn envoy_dynamic_module_on_program_init() callconv(.C) ?[*:0]const u8 {
    if (!programInit()) {
        return null;
    }
    return envoy.c.kAbiVersion;
}

fn programInit() bool {
    envoy.logInfo("Zig dynamic module initialized successfully!", .{});
    return true;
}

// ============================================================================
// HTTP Filter Configuration
// ============================================================================

export fn envoy_dynamic_module_on_http_filter_config_new(
    envoy_filter_config_ptr: envoy.HttpFilterConfigEnvoyPtr,
    name_ptr: [*]const u8,
    name_size: usize,
    config_ptr: [*]const u8,
    config_size: usize,
) callconv(.C) envoy.HttpFilterConfigModulePtr {
    const name = name_ptr[0..name_size];
    const config = config_ptr[0..config_size];

    envoy.logInfo("Creating filter config: {s}", .{name});

    // For now, just implement passthrough
    const filter_config = PassthroughFilterConfig.init(
        envoy.EnvoyHttpFilterConfig.init(envoy_filter_config_ptr),
        name,
        config,
    ) catch |err| {
        envoy.logError("Failed to create filter config: {}", .{err});
        return @ptrCast(@alignCast(@as(?*anyopaque, null)));
    };

    return @ptrCast(filter_config);
}

export fn envoy_dynamic_module_on_http_filter_config_destroy(
    filter_config_ptr: envoy.HttpFilterConfigModulePtr,
) callconv(.C) void {
    const config: *PassthroughFilterConfig = @ptrCast(@alignCast(filter_config_ptr));
    config.deinit();
}

// ============================================================================
// HTTP Filter
// ============================================================================

export fn envoy_dynamic_module_on_http_filter_new(
    filter_config_ptr: envoy.HttpFilterConfigModulePtr,
    envoy_filter_ptr: envoy.HttpFilterEnvoyPtr,
) callconv(.C) envoy.HttpFilterModulePtr {
    const config: *PassthroughFilterConfig = @ptrCast(@alignCast(filter_config_ptr));

    const filter = config.createFilter(envoy_filter_ptr) catch |err| {
        envoy.logError("Failed to create filter: {}", .{err});
        return @ptrCast(@alignCast(@as(?*anyopaque, null)));
    };

    return @ptrCast(filter);
}

export fn envoy_dynamic_module_on_http_filter_request_headers(
    filter_ptr: envoy.HttpFilterModulePtr,
    envoy_filter_ptr: envoy.HttpFilterEnvoyPtr,
    end_of_stream: bool,
) callconv(.C) envoy.FilterHeadersStatus {
    const filter: *PassthroughFilter = @ptrCast(@alignCast(filter_ptr));
    return filter.onRequestHeaders(envoy_filter_ptr, end_of_stream);
}

export fn envoy_dynamic_module_on_http_filter_request_body(
    filter_ptr: envoy.HttpFilterModulePtr,
    envoy_filter_ptr: envoy.HttpFilterEnvoyPtr,
    end_of_stream: bool,
) callconv(.C) envoy.FilterDataStatus {
    const filter: *PassthroughFilter = @ptrCast(@alignCast(filter_ptr));
    return filter.onRequestBody(envoy_filter_ptr, end_of_stream);
}

export fn envoy_dynamic_module_on_http_filter_request_trailers(
    filter_ptr: envoy.HttpFilterModulePtr,
    envoy_filter_ptr: envoy.HttpFilterEnvoyPtr,
) callconv(.C) envoy.FilterTrailersStatus {
    const filter: *PassthroughFilter = @ptrCast(@alignCast(filter_ptr));
    return filter.onRequestTrailers(envoy_filter_ptr);
}

export fn envoy_dynamic_module_on_http_filter_response_headers(
    filter_ptr: envoy.HttpFilterModulePtr,
    envoy_filter_ptr: envoy.HttpFilterEnvoyPtr,
    end_of_stream: bool,
) callconv(.C) envoy.FilterHeadersStatus {
    const filter: *PassthroughFilter = @ptrCast(@alignCast(filter_ptr));
    return filter.onResponseHeaders(envoy_filter_ptr, end_of_stream);
}

export fn envoy_dynamic_module_on_http_filter_response_body(
    filter_ptr: envoy.HttpFilterModulePtr,
    envoy_filter_ptr: envoy.HttpFilterEnvoyPtr,
    end_of_stream: bool,
) callconv(.C) envoy.FilterDataStatus {
    const filter: *PassthroughFilter = @ptrCast(@alignCast(filter_ptr));
    return filter.onResponseBody(envoy_filter_ptr, end_of_stream);
}

export fn envoy_dynamic_module_on_http_filter_response_trailers(
    filter_ptr: envoy.HttpFilterModulePtr,
    envoy_filter_ptr: envoy.HttpFilterEnvoyPtr,
) callconv(.C) envoy.FilterTrailersStatus {
    const filter: *PassthroughFilter = @ptrCast(@alignCast(filter_ptr));
    return filter.onResponseTrailers(envoy_filter_ptr);
}

export fn envoy_dynamic_module_on_http_filter_destroy(
    filter_ptr: envoy.HttpFilterModulePtr,
) callconv(.C) void {
    const filter: *PassthroughFilter = @ptrCast(@alignCast(filter_ptr));
    filter.deinit();
}

// ============================================================================
// Passthrough Filter Implementation
// ============================================================================

const PassthroughFilterConfig = struct {
    allocator: std.mem.Allocator,
    envoy_config: envoy.EnvoyHttpFilterConfig,
    config_data: []const u8,

    pub fn init(
        envoy_config: envoy.EnvoyHttpFilterConfig,
        name: []const u8,
        config: []const u8,
    ) !*PassthroughFilterConfig {
        _ = name;
        const allocator = std.heap.c_allocator;
        const self = try allocator.create(PassthroughFilterConfig);
        errdefer allocator.destroy(self);

        self.* = .{
            .allocator = allocator,
            .envoy_config = envoy_config,
            .config_data = try allocator.dupe(u8, config),
        };

        return self;
    }

    pub fn deinit(self: *PassthroughFilterConfig) void {
        self.allocator.free(self.config_data);
        self.allocator.destroy(self);
    }

    pub fn createFilter(self: *PassthroughFilterConfig, envoy_filter: envoy.HttpFilterEnvoyPtr) !*PassthroughFilter {
        const filter = try self.allocator.create(PassthroughFilter);
        errdefer self.allocator.destroy(filter);

        filter.* = .{
            .allocator = self.allocator,
            .config = self,
            .envoy_filter = envoy_filter,
        };

        return filter;
    }
};

const PassthroughFilter = struct {
    allocator: std.mem.Allocator,
    config: *PassthroughFilterConfig,
    envoy_filter: envoy.HttpFilterEnvoyPtr,

    pub fn onRequestHeaders(
        self: *PassthroughFilter,
        envoy_filter: envoy.HttpFilterEnvoyPtr,
        end_of_stream: bool,
    ) envoy.FilterHeadersStatus {
        _ = self;
        _ = envoy_filter;
        _ = end_of_stream;
        return envoy.c.envoy_dynamic_module_type_on_http_filter_request_headers_status_Continue;
    }

    pub fn onRequestBody(
        self: *PassthroughFilter,
        envoy_filter: envoy.HttpFilterEnvoyPtr,
        end_of_stream: bool,
    ) envoy.FilterDataStatus {
        _ = self;
        _ = envoy_filter;
        _ = end_of_stream;
        return envoy.c.envoy_dynamic_module_type_on_http_filter_request_body_status_Continue;
    }

    pub fn onRequestTrailers(
        self: *PassthroughFilter,
        envoy_filter: envoy.HttpFilterEnvoyPtr,
    ) envoy.FilterTrailersStatus {
        _ = self;
        _ = envoy_filter;
        return envoy.c.envoy_dynamic_module_type_on_http_filter_request_trailers_status_Continue;
    }

    pub fn onResponseHeaders(
        self: *PassthroughFilter,
        envoy_filter: envoy.HttpFilterEnvoyPtr,
        end_of_stream: bool,
    ) envoy.FilterHeadersStatus {
        _ = self;
        _ = envoy_filter;
        _ = end_of_stream;
        return envoy.c.envoy_dynamic_module_type_on_http_filter_response_headers_status_Continue;
    }

    pub fn onResponseBody(
        self: *PassthroughFilter,
        envoy_filter: envoy.HttpFilterEnvoyPtr,
        end_of_stream: bool,
    ) envoy.FilterDataStatus {
        _ = self;
        _ = envoy_filter;
        _ = end_of_stream;
        return envoy.c.envoy_dynamic_module_type_on_http_filter_response_body_status_Continue;
    }

    pub fn onResponseTrailers(
        self: *PassthroughFilter,
        envoy_filter: envoy.HttpFilterEnvoyPtr,
    ) envoy.FilterTrailersStatus {
        _ = self;
        _ = envoy_filter;
        return envoy.c.envoy_dynamic_module_type_on_http_filter_response_trailers_status_Continue;
    }

    pub fn deinit(self: *PassthroughFilter) void {
        self.allocator.destroy(self);
    }
};
