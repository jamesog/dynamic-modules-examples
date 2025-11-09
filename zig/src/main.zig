const std = @import("std");
const abi = @import("abi.zig");
const passthrough = @import("http_passthrough.zig");
const header_mutation = @import("http_header_mutation.zig");
const random_auth = @import("http_random_auth.zig");
const access_logger = @import("http_access_logger.zig");
const metrics = @import("http_metrics.zig");

// ABI version hash from Envoy
const abi_version = "f2712929b605772d35c34d9ac8ccd7e168197a50951e9c96b64e03256bf80265\x00";

/// Program initialization function called once when the module is loaded
export fn envoy_dynamic_module_on_program_init() [*c]const u8 {
    return abi_version;
}

/// Called when a new HTTP filter config is created
export fn envoy_dynamic_module_on_http_filter_config_new(
    _: usize,
    name_ptr: [*c]const u8,
    name_len: usize,
    config_ptr: [*c]const u8,
    config_len: usize,
) usize {
    const name = name_ptr[0..name_len];
    const config = config_ptr[0..config_len];

    if (std.mem.eql(u8, name, "passthrough")) {
        return passthrough.FilterConfig.create(config);
    } else if (std.mem.eql(u8, name, "header_mutation")) {
        return header_mutation.FilterConfig.create(config);
    } else if (std.mem.eql(u8, name, "random_auth")) {
        return random_auth.FilterConfig.create(config);
    } else if (std.mem.eql(u8, name, "access_logger")) {
        return access_logger.FilterConfig.create(config);
    } else if (std.mem.eql(u8, name, "metrics")) {
        return metrics.FilterConfig.create(config);
    }

    std.debug.print("Unknown filter name: {s}\n", .{name});
    return 0;
}

/// Called when an HTTP filter config is destroyed
export fn envoy_dynamic_module_on_http_filter_config_destroy(config_ptr: usize) void {
    if (config_ptr == 0) return;

    // The config_ptr points to our FilterConfig struct
    // We need to determine which type it is and call its destroy method
    // For now, we just free the memory
    const allocator = std.heap.c_allocator;
    const ptr = @as(*anyopaque, @ptrFromInt(config_ptr));
    allocator.destroy(@as(*u8, @ptrCast(@alignCast(ptr))));
}

/// Called when a new HTTP filter instance is created for a request
export fn envoy_dynamic_module_on_http_filter_new(
    config_ptr: usize,
    _: usize,
) usize {
    _ = config_ptr;
    // For now, return a dummy pointer
    // Each filter implementation will handle this differently
    return 1;
}

/// Called when an HTTP filter instance is destroyed
export fn envoy_dynamic_module_on_http_filter_destroy(filter_ptr: usize) void {
    _ = filter_ptr;
}

/// Called when request headers are received
export fn envoy_dynamic_module_on_http_filter_request_headers(
    envoy_filter_ptr: usize,
    filter_ptr: usize,
    end_of_stream: bool,
) abi.RequestHeadersStatus {
    _ = envoy_filter_ptr;
    _ = filter_ptr;
    _ = end_of_stream;
    return .Continue;
}

/// Called when request body is received
export fn envoy_dynamic_module_on_http_filter_request_body(
    envoy_filter_ptr: usize,
    filter_ptr: usize,
    end_of_stream: bool,
) abi.RequestBodyStatus {
    _ = envoy_filter_ptr;
    _ = filter_ptr;
    _ = end_of_stream;
    return .Continue;
}

/// Called when request trailers are received
export fn envoy_dynamic_module_on_http_filter_request_trailers(
    envoy_filter_ptr: usize,
    filter_ptr: usize,
) abi.RequestTrailersStatus {
    _ = envoy_filter_ptr;
    _ = filter_ptr;
    return .Continue;
}

/// Called when response headers are received
export fn envoy_dynamic_module_on_http_filter_response_headers(
    envoy_filter_ptr: usize,
    filter_ptr: usize,
    end_of_stream: bool,
) abi.ResponseHeadersStatus {
    _ = envoy_filter_ptr;
    _ = filter_ptr;
    _ = end_of_stream;
    return .Continue;
}

/// Called when response body is received
export fn envoy_dynamic_module_on_http_filter_response_body(
    envoy_filter_ptr: usize,
    filter_ptr: usize,
    end_of_stream: bool,
) abi.ResponseBodyStatus {
    _ = envoy_filter_ptr;
    _ = filter_ptr;
    _ = end_of_stream;
    return .Continue;
}

/// Called when response trailers are received
export fn envoy_dynamic_module_on_http_filter_response_trailers(
    envoy_filter_ptr: usize,
    filter_ptr: usize,
) abi.ResponseTrailersStatus {
    _ = envoy_filter_ptr;
    _ = filter_ptr;
    return .Continue;
}
