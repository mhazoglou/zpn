const std = @import("std");
const Allocator = std.mem.Allocator;
const Session = @import("session.zig").Session;
const Token = @import("token.zig").Token;
const Tokenizer = @import("token.zig").Tokenizer;

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
        std.debug.print("Type \"exit\" or \"quit\" to quit\n", .{});
        var running = true;
        // Define stdin reader
        const stdin = std.io.getStdIn().reader();
        
        var buffer: [BUFFERSIZE]u8 = undefined;
        
        while (running) {
            var sess = self.map.get(self.current_session).?;
            std.debug.print("Current session: {s}\n", .{self.current_session});
            sess.print_stack();
            @memset(buffer[0..], 0);

            _ = try stdin.readUntilDelimiterOrEof(buffer[0..], '\n');
            
            // I need to only use the appropriate length without the null characters
            var len_buffer: usize = 0;
            while (buffer[len_buffer] != 0) {
                len_buffer += 1;
            }

            const cmd_input = std.mem.asBytes(&buffer)[0..len_buffer];
            
            // print!("\nCurrent Session: {}", self.current_session.borrow());
            running = try self.process_input(cmd_input);
        }
    }

    fn process_input(self: *SessionManager, cmd_input: []u8) !bool {
        var running = true;
        var iter = std.mem.splitAny(u8, cmd_input, " \t\r\n");
        const sess = self.map.get(self.current_session).?;

        while (iter.next()) |tk| {
            if (!std.mem.eql(u8, tk[0..], "")) {
                try sess.append_to_history(tk[0..]);
                const token = Tokenizer(tk[0..]);
                std.debug.print("Token is : {any}\n\n", .{token});
                running = self.match_token(token);
                if (!running) {
                    break;
                }
            }
        }

        return running;
    }

    fn match_token(self: *SessionManager, token: Token) bool {
        var sess = self.map.get(self.current_session).?;
        var running = true;
        switch (token) {
            .Number => |num| sess.append_to_stack(num) catch unreachable,
            .OpBinary => |func| sess.op_binary(func) catch unreachable,
            .Reduce => |func| sess.reduce(func) catch unreachable,
            .OpUnary => |func| sess.op_unary(func) catch unreachable,
            .Map => |func| sess.map(func) catch unreachable,
            .Swap => sess.swap() catch unreachable,
            .CyclicPermutation => |num| sess.cyclic_permutation(num) catch unreachable,
            .Get => |num| sess.get(num) catch unreachable,
            .ClearStack => sess.clear_stack(),
            .Del => |num| sess.del(num),
            .PrintHistory => sess.print_history(),
            .Quit => running = false,
            .Copy => |num| sess.copy(num) catch unreachable,
            .NewSession => |name| self.add_new_session(name) catch unreachable, 
            .ChangeSession => |name| self.change_current_session(name), 
            .RemoveSession => |name| self.remove_session(name),
            .PrintSessions => self.print_session_names(),
            else => {std.debug.print("What a beautiful duwang. Skip\n\n", .{});},
        }
        return running;
    }

    fn add_new_session(self: *SessionManager, name: []const u8) !void {
        const sess_name, const new_sess = try self.make_new_session(name);
        
        try self.map.put(sess_name, new_sess);
    }

    fn change_current_session(self: *SessionManager, name: []const u8) void {
        const opt_sess_key = self.map.getKey(name);
        if (opt_sess_key) |key| {
            self.current_session = key;
        } else {
            std.debug.print(
                "Session name {s} does not exist. Create it with new:{s}\n\n", 
                .{name, name}
            );
        }
    }

    fn print_session_names(self: *SessionManager) void {
        var it = self.map.iterator();
        std.debug.print("Sessions:\n", .{});
        while (it.next()) |entry| {
            std.debug.print("{s}\n", .{entry.key_ptr.*});
        }
        std.debug.print("\n", .{});
    }

    fn remove_session(self: *SessionManager, name: []const u8) void {
        if (std.mem.eql(u8, name, "default")) {
            std.debug.print("The default session cannot be deleted.\n\n", .{});
        } else if (std.mem.eql(u8, name, self.current_session)) {
            std.debug.print("The current session cannot be deleted.\n\n", .{});
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
                    std.debug.print(
                        "Session {s} has successfully been removed.\n\n", 
                        .{name}
                    );
                }
            } else {
                std.debug.print(
                    "Session name {s} does not exist. Create it with new:{s}\n\n",
                    .{name, name}
                );
            }
        }
    }
};

