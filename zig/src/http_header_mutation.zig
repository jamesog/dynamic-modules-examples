const std = @import("std");
const abi = @import("abi.zig");

const Header = struct {
    key: []const u8,
    value: []const u8,
};

/// Header mutation filter config
pub const FilterConfig = struct {
    request_headers: []Header,
    remove_request_headers: [][]const u8,
    response_headers: []Header,
    remove_response_headers: [][]const u8,
    allocator: std.mem.Allocator,

    pub fn create(config: []const u8) usize {
        const allocator = std.heap.c_allocator;
        const filter_config = allocator.create(FilterConfig) catch return 0;

        // Parse JSON config
        const parsed = std.json.parseFromSlice(
            struct {
                request_headers: ?[]const [2][]const u8 = null,
                remove_request_headers: ?[]const []const u8 = null,
                response_headers: ?[]const [2][]const u8 = null,
                remove_response_headers: ?[]const []const u8 = null,
            },
            allocator,
            config,
            .{},
        ) catch {
            std.debug.print("Error parsing header mutation config\n", .{});
            allocator.destroy(filter_config);
            return 0;
        };
        defer parsed.deinit();

        // Convert request headers
        var request_headers = std.ArrayList(Header).init(allocator);
        if (parsed.value.request_headers) |headers| {
            for (headers) |header| {
                const key = allocator.dupe(u8, header[0]) catch continue;
                const value = allocator.dupe(u8, header[1]) catch continue;
                request_headers.append(Header{ .key = key, .value = value }) catch continue;
            }
        }

        // Convert remove request headers
        var remove_request_headers = std.ArrayList([]const u8).init(allocator);
        if (parsed.value.remove_request_headers) |headers| {
            for (headers) |header| {
                const key = allocator.dupe(u8, header) catch continue;
                remove_request_headers.append(key) catch continue;
            }
        }

        // Convert response headers
        var response_headers = std.ArrayList(Header).init(allocator);
        if (parsed.value.response_headers) |headers| {
            for (headers) |header| {
                const key = allocator.dupe(u8, header[0]) catch continue;
                const value = allocator.dupe(u8, header[1]) catch continue;
                response_headers.append(Header{ .key = key, .value = value }) catch continue;
            }
        }

        // Convert remove response headers
        var remove_response_headers = std.ArrayList([]const u8).init(allocator);
        if (parsed.value.remove_response_headers) |headers| {
            for (headers) |header| {
                const key = allocator.dupe(u8, header) catch continue;
                remove_response_headers.append(key) catch continue;
            }
        }

        filter_config.* = FilterConfig{
            .request_headers = request_headers.toOwnedSlice() catch &[_]Header{},
            .remove_request_headers = remove_request_headers.toOwnedSlice() catch &[_][]const u8{},
            .response_headers = response_headers.toOwnedSlice() catch &[_]Header{},
            .remove_response_headers = remove_response_headers.toOwnedSlice() catch &[_][]const u8{},
            .allocator = allocator,
        };

        return @intFromPtr(filter_config);
    }

    pub fn destroy(self: *FilterConfig) void {
        for (self.request_headers) |header| {
            self.allocator.free(header.key);
            self.allocator.free(header.value);
        }
        self.allocator.free(self.request_headers);

        for (self.remove_request_headers) |key| {
            self.allocator.free(key);
        }
        self.allocator.free(self.remove_request_headers);

        for (self.response_headers) |header| {
            self.allocator.free(header.key);
            self.allocator.free(header.value);
        }
        self.allocator.free(self.response_headers);

        for (self.remove_response_headers) |key| {
            self.allocator.free(key);
        }
        self.allocator.free(self.remove_response_headers);

        self.allocator.destroy(self);
    }

    pub fn newFilter(self: *FilterConfig) Filter {
        return Filter{
            .request_headers = self.request_headers,
            .remove_request_headers = self.remove_request_headers,
            .response_headers = self.response_headers,
            .remove_response_headers = self.remove_response_headers,
        };
    }
};

pub const Filter = struct {
    request_headers: []Header,
    remove_request_headers: [][]const u8,
    response_headers: []Header,
    remove_response_headers: [][]const u8,

    pub fn onRequestHeaders(
        self: *Filter,
        envoy: abi.EnvoyHttpFilter,
        _: bool,
    ) abi.RequestHeadersStatus {
        for (self.request_headers) |header| {
            _ = envoy.setRequestHeader(header.key, header.value);
        }

        for (self.remove_request_headers) |key| {
            _ = envoy.removeRequestHeader(key);
        }

        return .Continue;
    }

    pub fn onResponseHeaders(
        self: *Filter,
        envoy: abi.EnvoyHttpFilter,
        _: bool,
    ) abi.ResponseHeadersStatus {
        // Get and set downstream address
        if (envoy.getAttributeString(.SourceAddress)) |addr| {
            _ = envoy.setResponseHeader("X-Downstream-Address", addr);
        }

        // Get and set upstream address
        if (envoy.getAttributeString(.UpstreamAddress)) |addr| {
            _ = envoy.setResponseHeader("X-Upstream-Address", addr);
        }

        // Get and set response code
        if (envoy.getAttributeInt(.ResponseCode)) |code| {
            var buf: [32]u8 = undefined;
            const code_str = std.fmt.bufPrint(&buf, "{d}", .{code}) catch "";
            _ = envoy.setResponseHeader("X-Response-Code", code_str);
        }

        for (self.response_headers) |header| {
            _ = envoy.setResponseHeader(header.key, header.value);
        }

        for (self.remove_response_headers) |key| {
            _ = envoy.removeResponseHeader(key);
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

    pub fn onResponseBody(
        _: *Filter,
        _: abi.EnvoyHttpFilter,
        _: bool,
    ) abi.ResponseBodyStatus {
        return .Continue;
    }
};
