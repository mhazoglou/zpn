const std = @import("std");
const Allocator = std.mem.Allocator;
const Session = @import("session.zig").Session;
const Token = @import("token.zig").Token;
const Tokenizer = @import("token.zig").Tokenizer;
const Colors = @import("colors.zig");

const NUMERIC_COLOR = Colors.NUMERIC_COLOR;
const SESS_NAME_COLOR = Colors.SESS_NAME_COLOR;
const TEXT_COLOR = Colors.TEXT_COLOR;
const ALERT_COLOR = Colors.ALERT_COLOR;

// More than enough to kill anything that moves
const BUFFERSIZE = 4096;

pub const SessionManager = struct {
    map: std.StringHashMap(*Session),
    current_session: []const u8,
    allocator: Allocator,
    
    pub fn init(allocator: Allocator) !SessionManager {
    	var self: SessionManager = .{
            .map = std.StringHashMap(*Session).init(allocator),
            .current_session = "default", // allocator.alloc(u8, length)
            .allocator = allocator,
    	};
        // const default = try allocator.create(Session);
        const name, const default = try self.make_new_session("default");
        
        
        try self.map.put(name, default);
        return self;
    }

    pub fn deinit(self: *SessionManager) void {
        var it = self.map.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
            self.allocator.free(entry.key_ptr.*);
        }
        self.map.deinit();
    }
    
    // This method is to allocate memory for a new session and it's name
    // it returns the value to make their lifetimes persist longer than the 
    // scope they would be defined in
    fn make_new_session(self: *SessionManager, name: []const u8) !struct {[]const u8, *Session} {
        const sess = try self.allocator.create(Session);
        const sess_name = try self.allocator.dupe(u8, name);

        sess.* = Session.init(self.allocator);
        return .{ sess_name, sess};
    }
    
    pub fn run_manager(self: *SessionManager) !void {

        var running = true;
        // Define stdin reader
        const stdin = std.io.getStdIn();
        const reader = stdin.reader();
        var stdout = std.io.getStdOut();
        var writer = stdout.writer();

        _ = std.io.tty.detectConfig(stdout);

        // var buffered_writer = std.io.bufferedWriter(&writer).writer();

        var buffer: [BUFFERSIZE]u8 = undefined;
        try writer.print("Type {}\"exit\"\x1b[0m or {}\"quit\"\x1b[0m to quit\n", 
            .{ALERT_COLOR, ALERT_COLOR});
        while (running) {
            const sess = self.map.get(self.current_session).?;
            try writer.print("{}Current session: {}{s}\x1b[0m\n", 
                .{TEXT_COLOR, SESS_NAME_COLOR, self.current_session}
            );
            try writer.print("{}", .{sess});
            //sess.print_stack();
            @memset(buffer[0..], 0);

            _ = try reader.readUntilDelimiterOrEof(buffer[0..], '\n');
            
            // I need to only use the appropriate length without the null characters
            var len_buffer: usize = 0;
            while (buffer[len_buffer] != 0) {
                len_buffer += 1;
            }

            const cmd_input = std.mem.asBytes(&buffer)[0..len_buffer];
            
            // print!("\nCurrent Session: {}", self.current_session.borrow());
            running = try self.process_input(cmd_input, &writer);
        }
        // try buffered_writer.flush();
    }

    fn process_input(self: *SessionManager, cmd_input: []u8, writer: anytype) !bool {
        var running = true;
        var iter = std.mem.splitAny(u8, cmd_input, " \t\r\n");
        const sess = self.map.get(self.current_session).?;

        while (iter.next()) |tk| {
            if (!std.mem.eql(u8, tk[0..], "")) {
                try sess.append_to_history(tk[0..]);
                const token = Tokenizer(tk[0..]);
                try writer.print("\nToken is : {any}\n", .{token});
                try writer.print("Stack length: {}\n\n", .{sess.stack.items.len});
                running = self.match_token(token, writer);
                if (!running) {
                    break;
                }
            }
        }

        return running;
    }

    fn match_token(self: *SessionManager, token: Token, writer: anytype) bool {
        var sess = self.map.get(self.current_session).?;
        var running = true;
        switch (token) {
            .Number => |num| sess.append_to_stack(num) catch unreachable,
            .OpBinary => |func| sess.op_binary(func) catch unreachable,
            .Elementwise => |group| sess.elementwise(group[0], group[1]) catch unreachable,
            .Reduce => |func| sess.reduce(func) catch unreachable,
            .OpUnary => |func| sess.op_unary(func) catch unreachable,
            .Map => |func| sess.map(func) catch unreachable,
            .Swap => sess.swap() catch unreachable,
            .CyclicPermutation => |num| sess.cyclic_permutation(num) catch unreachable,
            .Get => |num| sess.get(num) catch unreachable,
            .Insert => |nums| sess.insert(nums[0], nums[1]) catch unreachable,
            .ClearStack => sess.clear_stack() catch unreachable,
            .Del => |num| sess.del(num) catch unreachable,
            .PrintHistory => sess.print_history(),
            .Quit => running = false,
            .Copy => |num| sess.copy(num) catch unreachable,
            .NewSession => |name| self.add_new_session(name) catch unreachable, 
            .ChangeSession => |name| self.change_current_session(name, writer) catch unreachable, 
            .RemoveSession => |name| self.remove_session(name, writer) catch unreachable,
            .PrintSessions => self.print_session_names(writer) catch unreachable,
            .Undo => |num| sess.undo(num) catch unreachable,
            .Redo => |num| sess.redo(num) catch unreachable,
            else => {std.debug.print("What a beautiful duwang. Skip\n\n", .{});},
        }
        return running;
    }

    fn add_new_session(self: *SessionManager, name: []const u8) !void {
        const sess_name, const new_sess = try self.make_new_session(name);
        
        try self.map.put(sess_name, new_sess);
    }

    fn change_current_session(self: *SessionManager, name: []const u8, writer: anytype) !void {
        const opt_sess_key = self.map.getKey(name);
        if (opt_sess_key) |key| {
            self.current_session = key;
        } else {
            try writer.print(
                "{}Session name {s} does not exist. Create it with new:{s}\n\n", 
                .{ALERT_COLOR, name, name}
            );
        }
    }

    fn print_session_names(self: *SessionManager, writer: anytype) !void {
        var it = self.map.iterator();
        try writer.print("{}Sessions:\n{}", .{TEXT_COLOR, SESS_NAME_COLOR});
        while (it.next()) |entry| {
            try writer.print("{s}\n", .{entry.key_ptr.*});
        }
        try writer.print("\n", .{});
    }

    fn remove_session(self: *SessionManager, name: []const u8, writer: anytype) !void {
        if (std.mem.eql(u8, name, "default")) {
            try writer.print("{}The default session cannot be deleted.\n\n", .{ALERT_COLOR});
        } else if (std.mem.eql(u8, name, self.current_session)) {
            try writer.print("{}The current session cannot be deleted.\n\n", .{ALERT_COLOR});
        } else {
            const opt_sess_entry = self.map.getEntry(name);
            if (opt_sess_entry) |entry| {
                // deinitialize and destroy session object
                entry.value_ptr.*.deinit();
                self.allocator.destroy(entry.value_ptr.*);
                // remove entry from map make sure key lives long enough 
                // for remove then destroy the key
                const key = entry.key_ptr.*;
                const removed = self.map.remove(key);
                self.allocator.free(key);
                if (removed) {
                    try writer.print(
                        "{}Session {s} has successfully been removed.\n\n", 
                        .{ALERT_COLOR, name}
                    );
                }
            } else {
                try writer.print(
                    "{}Session name {s} does not exist. Create it with new:{s}\n\n",
                    .{ALERT_COLOR, name, name}
                );
            }
        }
    }
};
