const std = @import("std");
const SessionManager = @import("SessionManager.zig").SessionManager;
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    //var reader = File.Reader.interface;
    //var writer = File.Writer.interface;

    var manager = try SessionManager.init(allocator);
    defer manager.deinit();
    try manager.run_manager();
}
