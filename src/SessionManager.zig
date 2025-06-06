const std = @import("std");
const Allocator = std.mem.Allocator;
const Session = @import("session.zig").Session;
const Token = @import("token.zig").Token;
const Tokenizer = @import("token.zig").Tokenizer;

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
        
        
        try self.map.put(name.*, default);
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

    fn make_new_session(self: *SessionManager, name: []const u8) !struct {*[]const u8, *Session} {
        const sess = try self.allocator.create(Session);
        const sess_name = try self.allocator.create([]const u8);

        sess.* = Session.init(self.allocator);
        sess_name.* = name;
        return .{ sess_name, sess};
    }
    
    pub fn run_manager(self: *SessionManager) !void {
        // println!("Type \"exit\" or \"quit\" to quit");
        var running = true;
        // Define stdin reader
        const stdin = std.io.getStdIn().reader();
        
        var buffer: [BUFFERSIZE]u8 = undefined;
        
        while (running) {
            var sess = self.map.get(self.current_session).?;
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

        while (iter.next()) |tk| {
            if (!std.mem.eql(u8, tk[0..], "")) {
                //self.append_to_history(tk[0..]);
                const token = Tokenizer(tk[0..]);
                std.debug.print("Token is : {any}\n\n", .{token});
                running = self.match_token(token);
                if (!running) {
                    break;
                }
                std.debug.print("Hashmap: {!}\n\n", .{self.map});
                var it = self.map.iterator();
                while (it.next()) |entry| {
                    std.debug.print("{s}\n", .{entry.key_ptr.*});
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
            .OpUnary => |func| sess.op_unary(func) catch unreachable,
            .Swap => sess.swap() catch unreachable,
            .CyclicPermutation => |num| sess.cyclic_permutation(num) catch unreachable,
            .Get => |num| sess.get(num) catch unreachable,
            .ClearStack => sess.clear_stack(),
            .Del => |num| sess.del(num),
            .PrintHistory => sess.print_history(),
            .Quit => running = false,
            .Copy => |num| sess.copy(num) catch unreachable,
            .NewSession => |name| self.add_new_session(name[0..]) catch unreachable, 
            .ChangeSession => |name| self.change_current_session(name[0..]), 
            else => {std.debug.print("What a beautiful duwang. Skip\n\n", .{});},
        }
        return running;
    }

    fn add_new_session(self: *SessionManager, name: []const u8) !void {
        const sess_name, const new_sess = try self.make_new_session(name);
        
        try self.map.put(sess_name.*, new_sess);
    }

    fn change_current_session(self: *SessionManager, name: []const u8) void {
        const opt_sess = self.map.get(name);
        if (opt_sess) |_| {
            self.current_session = name[0..];
        } else {
            std.debug.print("Session name {s} does not exist. Create it with new:{s}\n\n", .{name, name});
        }
    }
};

