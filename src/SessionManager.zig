const std = @import("std");
const Allocator = std.mem.Allocator;
const Session = @import("session.zig").Session;
const Token = @import("token.zig").Token;
const Tokenizer = @import("token.zig").Tokenizer;

const BUFFERSIZE = 4096;

pub const SessionManager = struct {
    map: std.StringHashMap(Session),
    current_session: []const u8,
    allocator: Allocator,
    
    pub fn init(allocator: Allocator) SessionManager {
    	var self = .{
            .map = std.StringHashMap(Session).init(allocator),
            .current_session = "default", // allocator.alloc(u8, length)
            .allocator = allocator,
    	};
        try self.map.put("default", Session.init(allocator));
        return self;
    }
    
    pub fn run_manager(self: *SessionManager) !void {
        // println!("Type \"exit\" or \"quit\" to quit");
        var running = true;
        // Define stdin reader
        const stdin = std.io.getStdIn().reader();
        
        var buffer: [BUFFERSIZE]u8 = undefined;
        
        while (running) {
            @memset(buffer[0..], 0);

            _ = try stdin.readUntilDelimiterOrEof(buffer[0..], '\n');
            
            // I need to only use the appropriate length without the null characters
            var len_buffer: usize = 0;
            while (buffer[len_buffer] != 0) {
                len_buffer += 1;
            }

            const cmd_input = std.mem.asBytes(&buffer)[0..len_buffer];
            
            // print!("\nCurrent Session: {}", self.current_session.borrow());
            self.print_stack();
            running = try self.process_input(cmd_input);
        }
    }

    fn process_input(self: *SessionManager, cmd_input: []u8) !bool {
        var running = true;
        var iter = std.mem.splitAny(u8, cmd_input, " \t\r\n");

        while (iter.next()) |tk| {
            // self.push_to_history(tk);
            const token = Tokenizer(tk);
            running = self.match_token(token);
            if (!running) {
                break;
            }
        }

        return running;
    }

    fn match_token(self: *SessionManager, token: Token) bool {
        var running = true;
        switch (token) {
            .Number => |num| self.map.get(self.current_session).?.append_to_stack(num),
            .OpUnary => |func| self.map.get(self.current_session).?.op_unary(func),
            .Quit => running = false,
            else => {},
        }
        return running;
    }

    fn print_stack(self: *SessionManager) void {
        std.debug.print("{!}", .{self.map.get(self.current_session).?.stack});
    }
};

