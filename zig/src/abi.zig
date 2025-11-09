const std = @import("std");

// Status codes for different filter phases
pub const RequestHeadersStatus = enum(usize) {
    Continue = 0,
    StopIteration = 1,
    StopAllIterationAndBuffer = 3,
};

pub const RequestBodyStatus = enum(usize) {
    Continue = 0,
    StopIterationAndBuffer = 1,
    StopIterationNoBuffer = 2,
};

pub const RequestTrailersStatus = enum(usize) {
    Continue = 0,
    StopIteration = 1,
};

pub const ResponseHeadersStatus = enum(usize) {
    Continue = 0,
    StopIteration = 1,
    StopAllIterationAndBuffer = 3,
};

pub const ResponseBodyStatus = enum(usize) {
    Continue = 0,
    StopIterationAndBuffer = 1,
    StopIterationNoBuffer = 2,
};

pub const ResponseTrailersStatus = enum(usize) {
    Continue = 0,
    StopIteration = 1,
};

// Envoy callback functions
extern "c" fn envoy_dynamic_module_callback_http_get_request_header(
    filter_envoy_ptr: usize,
    key: [*c]const u8,
    key_length: usize,
    result_buffer_ptr: *usize,
    result_buffer_length_ptr: *usize,
    index: usize,
) usize;

extern "c" fn envoy_dynamic_module_callback_http_set_request_header(
    filter_envoy_ptr: usize,
    key: [*c]const u8,
    key_length: usize,
    value: [*c]const u8,
    value_length: usize,
) bool;

extern "c" fn envoy_dynamic_module_callback_http_remove_request_header(
    filter_envoy_ptr: usize,
    key: [*c]const u8,
    key_length: usize,
) bool;

extern "c" fn envoy_dynamic_module_callback_http_get_response_header(
    filter_envoy_ptr: usize,
    key: [*c]const u8,
    key_length: usize,
    result_buffer_ptr: *usize,
    result_buffer_length_ptr: *usize,
    index: usize,
) usize;

extern "c" fn envoy_dynamic_module_callback_http_set_response_header(
    filter_envoy_ptr: usize,
    key: [*c]const u8,
    key_length: usize,
    value: [*c]const u8,
    value_length: usize,
) bool;

extern "c" fn envoy_dynamic_module_callback_http_remove_response_header(
    filter_envoy_ptr: usize,
    key: [*c]const u8,
    key_length: usize,
) bool;

extern "c" fn envoy_dynamic_module_callback_http_send_response(
    filter_envoy_ptr: usize,
    status_code: u32,
    headers: [*c]const u8,
    headers_count: usize,
    body: [*c]const u8,
    body_length: usize,
) void;

extern "c" fn envoy_dynamic_module_callback_http_filter_get_attribute_string(
    filter_envoy_ptr: usize,
    attribute_id: usize,
    result: *usize,
    result_length: *usize,
) bool;

extern "c" fn envoy_dynamic_module_callback_http_filter_get_attribute_int(
    filter_envoy_ptr: usize,
    attribute_id: usize,
    result: *i64,
) bool;

// Attribute IDs
pub const AttributeId = enum(usize) {
    SourceAddress = 24,
    UpstreamAddress = 26,
    ResponseCode = 9,
    XdsRouteName = 12,
};

// EnvoyHttpFilter wrapper
pub const EnvoyHttpFilter = struct {
    ptr: usize,

    pub fn getRequestHeader(self: EnvoyHttpFilter, key: []const u8) ?[]const u8 {
        var result_ptr: usize = undefined;
        var result_len: usize = undefined;

        const found = envoy_dynamic_module_callback_http_get_request_header(
            self.ptr,
            key.ptr,
            key.len,
            &result_ptr,
            &result_len,
            0,
        );

        if (found == 0) return null;

        const result_slice = @as([*]const u8, @ptrFromInt(result_ptr))[0..result_len];
        return result_slice;
    }

    pub fn setRequestHeader(self: EnvoyHttpFilter, key: []const u8, value: []const u8) bool {
        return envoy_dynamic_module_callback_http_set_request_header(
            self.ptr,
            key.ptr,
            key.len,
            value.ptr,
            value.len,
        );
    }

    pub fn removeRequestHeader(self: EnvoyHttpFilter, key: []const u8) bool {
        return envoy_dynamic_module_callback_http_remove_request_header(
            self.ptr,
            key.ptr,
            key.len,
        );
    }

    pub fn getResponseHeader(self: EnvoyHttpFilter, key: []const u8) ?[]const u8 {
        var result_ptr: usize = undefined;
        var result_len: usize = undefined;

        const found = envoy_dynamic_module_callback_http_get_response_header(
            self.ptr,
            key.ptr,
            key.len,
            &result_ptr,
            &result_len,
            0,
        );

        if (found == 0) return null;

        const result_slice = @as([*]const u8, @ptrFromInt(result_ptr))[0..result_len];
        return result_slice;
    }

    pub fn setResponseHeader(self: EnvoyHttpFilter, key: []const u8, value: []const u8) bool {
        return envoy_dynamic_module_callback_http_set_response_header(
            self.ptr,
            key.ptr,
            key.len,
            value.ptr,
            value.len,
        );
    }

    pub fn removeResponseHeader(self: EnvoyHttpFilter, key: []const u8) bool {
        return envoy_dynamic_module_callback_http_remove_response_header(
            self.ptr,
            key.ptr,
            key.len,
        );
    }

    pub fn sendResponse(self: EnvoyHttpFilter, status_code: u32, body: []const u8) void {
        envoy_dynamic_module_callback_http_send_response(
            self.ptr,
            status_code,
            null,
            0,
            body.ptr,
            body.len,
        );
    }

    pub fn getAttributeString(self: EnvoyHttpFilter, attribute_id: AttributeId) ?[]const u8 {
        var result_ptr: usize = undefined;
        var result_len: usize = undefined;

        const found = envoy_dynamic_module_callback_http_filter_get_attribute_string(
            self.ptr,
            @intFromEnum(attribute_id),
            &result_ptr,
            &result_len,
        );

        if (!found) return null;

        const result_slice = @as([*]const u8, @ptrFromInt(result_ptr))[0..result_len];
        return result_slice;
    }

    pub fn getAttributeInt(self: EnvoyHttpFilter, attribute_id: AttributeId) ?i64 {
        var result: i64 = undefined;

        const found = envoy_dynamic_module_callback_http_filter_get_attribute_int(
            self.ptr,
            @intFromEnum(attribute_id),
            &result,
        );

        if (!found) return null;
        return result;
    }
};
