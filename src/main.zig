const std = @import("std");
const c = @cImport({
    @cInclude("nng/nng.h");
    @cInclude("nng/protocol/pubsub0/sub.h");
    @cInclude("nng/supplemental/util/platform.h");
});

fn fatal(msg: []const u8, code: c_int) void {
    // TODO: std.fmt should accept [*c]const u8 for {s} format specific, should not require {s}
    // in this case?
    std.debug.print("{?s}: {?d}\n", .{ msg, code });
    std.os.exit(1);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    var sock: c.nng_socket = undefined;
    var r: c_int = undefined;

    r = c.nng_sub0_open(&sock);
    if (r != 0) {
        fatal("nng_sub0_open", r);
    }
    defer _ = c.nng_close(sock);

    r = c.nng_setopt(sock, c.NNG_OPT_SUB_SUBSCRIBE, "", 0);
    if (r != 0) {
        fatal("nng_setopt", r);
    }
    defer _ = c.nng_close(sock);

    r = c.nng_dial(sock, "ipc:///tmp/pubsub.ipc", 0, 0);
    if (r != 0) {
        fatal("nng_dial", r);
    }

    var msg: ?*c.nng_msg = undefined;
    var msg_len: usize = 0;

    std.debug.print("Wait for message\n", .{});

    r = c.nng_recv(sock, @ptrCast(*anyopaque, &msg), &msg_len, c.NNG_FLAG_ALLOC);
    if (r != 0) {
        fatal("nng_recv", r);
    }
    var msg_body: []const u8 = @ptrCast([*]u8, msg)[0..msg_len];

    std.debug.print("got message {s} {d}\n", .{ msg_body, msg_len });

    var parser = std.json.Parser.init(allocator, false);
    defer parser.deinit();
    var tree = try parser.parse(msg_body);
    defer tree.deinit();

    tree.root.dump();
}
