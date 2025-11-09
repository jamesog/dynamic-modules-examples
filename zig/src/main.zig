//! Envoy Dynamic Module Examples in Zig
//!
//! This demonstrates various HTTP filters implemented using the Zig SDK.

const std = @import("std");
const envoy = @import("envoy-dynamic-modules");

// Import filter implementations
const passthrough = @import("http_passthrough.zig");
const header_mutation = @import("http_header_mutation.zig");
const random_auth = @import("http_random_auth.zig");

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
// Filter Configuration Routing
// ============================================================================

// Type-erased filter config to support multiple filter types
const FilterConfigUnion = union(enum) {
    passthrough: *passthrough.FilterConfig,
    header_mutation: *header_mutation.FilterConfig,
    random_auth: *random_auth.FilterConfig,
};

export fn envoy_dynamic_module_on_http_filter_config_new(
    envoy_filter_config_ptr: envoy.HttpFilterConfigEnvoyPtr,
    name_ptr: [*]const u8,
    name_size: usize,
    config_ptr: [*]const u8,
    config_size: usize,
) callconv(.C) envoy.HttpFilterConfigModulePtr {
    _ = envoy_filter_config_ptr;
    const name = name_ptr[0..name_size];
    const config = config_ptr[0..config_size];

    envoy.logInfo("Creating filter config: {s}", .{name});

    const allocator = std.heap.c_allocator;

    // Create wrapper to store filter type
    const wrapper = allocator.create(FilterConfigUnion) catch {
        envoy.logError("Failed to allocate config wrapper", .{});
        return @ptrCast(@alignCast(@as(?*anyopaque, null)));
    };

    if (std.mem.eql(u8, name, "passthrough")) {
        const filter_config = passthrough.FilterConfig.init(config) catch {
            allocator.destroy(wrapper);
            return @ptrCast(@alignCast(@as(?*anyopaque, null)));
        };
        wrapper.* = .{ .passthrough = filter_config };
    } else if (std.mem.eql(u8, name, "header_mutation")) {
        const filter_config = header_mutation.FilterConfig.init(config) catch {
            allocator.destroy(wrapper);
            return @ptrCast(@alignCast(@as(?*anyopaque, null)));
        };
        wrapper.* = .{ .header_mutation = filter_config };
    } else if (std.mem.eql(u8, name, "random_auth")) {
        const filter_config = random_auth.FilterConfig.init(config) catch {
            allocator.destroy(wrapper);
            return @ptrCast(@alignCast(@as(?*anyopaque, null)));
        };
        wrapper.* = .{ .random_auth = filter_config };
    } else {
        envoy.logError("Unknown filter name: {s}", .{name});
        allocator.destroy(wrapper);
        return @ptrCast(@alignCast(@as(?*anyopaque, null)));
    }

    return @ptrCast(wrapper);
}

export fn envoy_dynamic_module_on_http_filter_config_destroy(
    filter_config_ptr: envoy.HttpFilterConfigModulePtr,
) callconv(.C) void {
    const wrapper: *FilterConfigUnion = @ptrCast(@alignCast(filter_config_ptr));
    const allocator = std.heap.c_allocator;

    switch (wrapper.*) {
        .passthrough => |config| config.deinit(),
        .header_mutation => |config| config.deinit(),
        .random_auth => |config| config.deinit(),
    }

    allocator.destroy(wrapper);
}

// ============================================================================
// Filter Instance Routing
// ============================================================================

const FilterUnion = union(enum) {
    passthrough: *passthrough.Filter,
    header_mutation: *header_mutation.Filter,
    random_auth: *random_auth.Filter,
};

export fn envoy_dynamic_module_on_http_filter_new(
    filter_config_ptr: envoy.HttpFilterConfigModulePtr,
    envoy_filter_ptr: envoy.HttpFilterEnvoyPtr,
) callconv(.C) envoy.HttpFilterModulePtr {
    const config_wrapper: *FilterConfigUnion = @ptrCast(@alignCast(filter_config_ptr));
    const allocator = std.heap.c_allocator;

    const filter_wrapper = allocator.create(FilterUnion) catch {
        envoy.logError("Failed to allocate filter wrapper", .{});
        return @ptrCast(@alignCast(@as(?*anyopaque, null)));
    };

    switch (config_wrapper.*) {
        .passthrough => |config| {
            const filter = config.createFilter(envoy_filter_ptr) catch {
                allocator.destroy(filter_wrapper);
                return @ptrCast(@alignCast(@as(?*anyopaque, null)));
            };
            filter_wrapper.* = .{ .passthrough = filter };
        },
        .header_mutation => |config| {
            const filter = config.createFilter(envoy_filter_ptr) catch {
                allocator.destroy(filter_wrapper);
                return @ptrCast(@alignCast(@as(?*anyopaque, null)));
            };
            filter_wrapper.* = .{ .header_mutation = filter };
        },
        .random_auth => |config| {
            const filter = config.createFilter(envoy_filter_ptr) catch {
                allocator.destroy(filter_wrapper);
                return @ptrCast(@alignCast(@as(?*anyopaque, null)));
            };
            filter_wrapper.* = .{ .random_auth = filter };
        },
    }

    return @ptrCast(filter_wrapper);
}

// ============================================================================
// Filter Event Handlers
// ============================================================================

export fn envoy_dynamic_module_on_http_filter_request_headers(
    filter_ptr: envoy.HttpFilterModulePtr,
    envoy_filter_ptr: envoy.HttpFilterEnvoyPtr,
    end_of_stream: bool,
) callconv(.C) envoy.FilterHeadersStatus {
    const wrapper: *FilterUnion = @ptrCast(@alignCast(filter_ptr));
    return switch (wrapper.*) {
        .passthrough => |filter| filter.onRequestHeaders(envoy_filter_ptr, end_of_stream),
        .header_mutation => |filter| filter.onRequestHeaders(envoy_filter_ptr, end_of_stream),
        .random_auth => |filter| filter.onRequestHeaders(envoy_filter_ptr, end_of_stream),
    };
}

export fn envoy_dynamic_module_on_http_filter_request_body(
    filter_ptr: envoy.HttpFilterModulePtr,
    envoy_filter_ptr: envoy.HttpFilterEnvoyPtr,
    end_of_stream: bool,
) callconv(.C) envoy.FilterDataStatus {
    const wrapper: *FilterUnion = @ptrCast(@alignCast(filter_ptr));
    return switch (wrapper.*) {
        .passthrough => |filter| filter.onRequestBody(envoy_filter_ptr, end_of_stream),
        .header_mutation => |filter| filter.onRequestBody(envoy_filter_ptr, end_of_stream),
        .random_auth => |filter| filter.onRequestBody(envoy_filter_ptr, end_of_stream),
    };
}

export fn envoy_dynamic_module_on_http_filter_request_trailers(
    filter_ptr: envoy.HttpFilterModulePtr,
    envoy_filter_ptr: envoy.HttpFilterEnvoyPtr,
) callconv(.C) envoy.FilterTrailersStatus {
    const wrapper: *FilterUnion = @ptrCast(@alignCast(filter_ptr));
    return switch (wrapper.*) {
        .passthrough => |filter| filter.onRequestTrailers(envoy_filter_ptr),
        .header_mutation => |filter| filter.onRequestTrailers(envoy_filter_ptr),
        .random_auth => |filter| filter.onRequestTrailers(envoy_filter_ptr),
    };
}

export fn envoy_dynamic_module_on_http_filter_response_headers(
    filter_ptr: envoy.HttpFilterModulePtr,
    envoy_filter_ptr: envoy.HttpFilterEnvoyPtr,
    end_of_stream: bool,
) callconv(.C) envoy.FilterHeadersStatus {
    const wrapper: *FilterUnion = @ptrCast(@alignCast(filter_ptr));
    return switch (wrapper.*) {
        .passthrough => |filter| filter.onResponseHeaders(envoy_filter_ptr, end_of_stream),
        .header_mutation => |filter| filter.onResponseHeaders(envoy_filter_ptr, end_of_stream),
        .random_auth => |filter| filter.onResponseHeaders(envoy_filter_ptr, end_of_stream),
    };
}

export fn envoy_dynamic_module_on_http_filter_response_body(
    filter_ptr: envoy.HttpFilterModulePtr,
    envoy_filter_ptr: envoy.HttpFilterEnvoyPtr,
    end_of_stream: bool,
) callconv(.C) envoy.FilterDataStatus {
    const wrapper: *FilterUnion = @ptrCast(@alignCast(filter_ptr));
    return switch (wrapper.*) {
        .passthrough => |filter| filter.onResponseBody(envoy_filter_ptr, end_of_stream),
        .header_mutation => |filter| filter.onResponseBody(envoy_filter_ptr, end_of_stream),
        .random_auth => |filter| filter.onResponseBody(envoy_filter_ptr, end_of_stream),
    };
}

export fn envoy_dynamic_module_on_http_filter_response_trailers(
    filter_ptr: envoy.HttpFilterModulePtr,
    envoy_filter_ptr: envoy.HttpFilterEnvoyPtr,
) callconv(.C) envoy.FilterTrailersStatus {
    const wrapper: *FilterUnion = @ptrCast(@alignCast(filter_ptr));
    return switch (wrapper.*) {
        .passthrough => |filter| filter.onResponseTrailers(envoy_filter_ptr),
        .header_mutation => |filter| filter.onResponseTrailers(envoy_filter_ptr),
        .random_auth => |filter| filter.onResponseTrailers(envoy_filter_ptr),
    };
}

export fn envoy_dynamic_module_on_http_filter_destroy(
    filter_ptr: envoy.HttpFilterModulePtr,
) callconv(.C) void {
    const wrapper: *FilterUnion = @ptrCast(@alignCast(filter_ptr));
    const allocator = std.heap.c_allocator;

    switch (wrapper.*) {
        .passthrough => |filter| filter.deinit(),
        .header_mutation => |filter| filter.deinit(),
        .random_auth => |filter| filter.deinit(),
    }

    allocator.destroy(wrapper);
}
