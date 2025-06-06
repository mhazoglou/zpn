const std = @import("std");
const SessionManager = @import("SessionManager.zig").SessionManager;
const Session = @import("session.zig").Session;
const Token = @import("token.zig").Token;
const Tokenizer = @import("token.zig").Tokenizer;
const Allocator = std.mem.Allocator;

// 4096 bytes more than enough to kill anything that moves
const BUFFERSIZE = 4096;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

//     var sess = Session.init(allocator);
//     defer sess.deinit();
// 
//     var running = true;
//     // Define stdin reader
//     const stdin = std.io.getStdIn().reader();
//     
//     var buffer: [BUFFERSIZE]u8 = undefined;
//     
//     while (running) {
//         sess.print_stack();
//         @memset(buffer[0..], 0);
// 
//         _ = try stdin.readUntilDelimiterOrEof(buffer[0..], '\n');
//         
//         // I need to only use the appropriate length without the null characters
//         var len_buffer: usize = 0;
//         while (buffer[len_buffer] != 0) {
//             len_buffer += 1;
//         }
// 
//         const cmd_input = std.mem.asBytes(&buffer)[0..len_buffer];
//         
//         // print!("\nCurrent Session: {}", self.current_session.borrow());
//         running = try sess.process_input(cmd_input);
//     }


    var manager = try SessionManager.init(allocator);
    defer manager.deinit();
    try manager.run_manager();
}

// fn read_input() []u8 {
// // Define stdin reader
// const stdin = std.io.getStdIn().reader();
// 
// // 4096 bytes more than enough to kill anything that moves
// var buffer: [4096]u8 = undefined;
//  @memset(buffer[0..], 0);
//  
//  _ = try stdin.readUntilDelimiterOrEof(buffer[0..], '\n');
// 
//  // I need to only use the appropriate length without the null characters
//     var len_buffer: usize = 0;
//     while (buffer[len_buffer] != 0) {
//         len_buffer += 1;
//     }
// 
//     var cmd_input = std.mem.asBytes(&buffer)[0..len_buffer];
//  
//  const iter = std.mem.splitAny(u8, cmd_input, " ");
//  
//  while (try iter.next()) |token| {
// 
//  }
// }


test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
