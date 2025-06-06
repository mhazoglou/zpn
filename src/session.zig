const std = @import("std");
const Token = @import("token.zig").Token;
const Tokenizer = @import("token.zig").Tokenizer;
const Allocator = std.mem.Allocator;

pub const Session = struct {
    stack: std.ArrayList(f64),
    history: std.ArrayList(u8),
    allocator: Allocator,
    // states:
    // undone_states: 
   	
    pub fn init(allocator: Allocator) Session {
        return .{
            .stack = std.ArrayList(f64).init(allocator),
            .history = std.ArrayList(u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Session) void {
        self.stack.deinit();
        self.history.deinit();
    }
    
    pub fn append_to_stack(self: *Session, val: f64) !void {
        try self.stack.append(val);
    }
    
    pub fn pop_from_stack(self: *Session) f64 {
        return self.stack.pop().?;
    }
    
    pub fn append_to_history(self: *Session, str: []const u8) !void {
        try self.history.appendSlice(str);
        try self.history.appendSlice("\n");
    }
    
    pub fn op_binary(self: *Session, bin_closure: *const fn(num1: f64, num2: f64) f64) !void {
        if (self.stack.items.len > 1) {
            const y = self.pop_from_stack();
            const x = self.pop_from_stack();
            try self.append_to_stack(bin_closure(x, y));
        } else {
            std.debug.print("You need at least two numbers in ", .{});
            std.debug.print("the stack to perform binary operations.\n", .{});
        }
        // self.update_states();
    }
    
    pub fn op_unary(self: *Session, un_closure: *const fn(num: f64) f64) !void {
        if (self.stack.items.len >= 1) {
            const x = self.pop_from_stack();
            try self.append_to_stack(un_closure(x));
        } else {
            std.debug.print("You need at least one number in ", .{});
            std.debug.print("the stack to perform unary operations.\n", .{});
        }
        // self.update_states();
    }

    pub fn swap(self: *Session) !void {
        if (self.stack.items.len > 1) {
            const y = self.pop_from_stack();
            const x = self.pop_from_stack();
            try self.append_to_stack(y);
            try self.append_to_stack(x);
        } else {
            std.debug.print("You need at least two numbers in ", .{});
            std.debug.print("the stack to perform binary operations.\n", .{});
        }
        // self.update_states();
    }

    pub fn cyclic_permutation(self: *Session, num: i32) !void {
        if (self.stack.items.len > 1) {
            if (num >= 0) {
                const count = @as(usize, @intCast(num));
                const dst = try self.stack.addManyAt(0, count);
                for (0..count) |i| {
                    dst[count - i - 1] = self.pop_from_stack();
                }
            } else {
                const count = @as(usize, @intCast(-num));
                for (0..count) |_| {
                    const x = self.stack.orderedRemove(0);
                    try self.append_to_stack(x);
                }
            }
        }
    }

    pub fn del(self: *Session, num: u32) void {
        if (self.stack.items.len >= num) {
            for (0..num) |_| {
                _ = self.pop_from_stack();
            }
        }
    }

    pub fn clear_stack(self: *Session) void {
        self.stack.clearAndFree();
    }

    pub fn copy(self: *Session, num: u32) !void {
        if (self.stack.items.len >= 1) {
            const last = self.stack.getLast();
            for (0..num) |_| {
                try self.append_to_stack(last);
            }
        } else {
            std.debug.print("Cannot copy any elements the stack is empty.\n", .{});
        }
    }

    pub fn get(self: *Session, num: usize) !void {
        if (num < self.stack.items.len) {
            const item = self.stack.orderedRemove(num);
            try self.append_to_stack(item);
        } else {
            std.debug.print("Index exceeds stack length.\n", .{});
        }
    }

    pub fn insert(self: *Session, num: usize, val: f64) !void {
        try self.stack.insert(num, val);
    }

    pub fn process_input(self: *Session, cmd_input: []u8) !bool {
        var running = true;
        var iter = std.mem.splitAny(u8, cmd_input, " \t\r\n");

        while (iter.next()) |tk| {
            if (!std.mem.eql(u8, tk[0..], "")) {
                try self.append_to_history(tk[0..]);
                const token = Tokenizer(tk[0..]);
                running = self.match_token(token);
                if (!running) {
                    break;
                }
            }
        }

        return running;
    }

    fn match_token(self: *Session, token: Token) bool {
        var running = true;
        switch (token) {
            .Number => |num| self.append_to_stack(num) catch unreachable,
            .OpBinary => |func| self.op_binary(func) catch unreachable,
            .OpUnary => |func| self.op_unary(func) catch unreachable,
            .Swap => self.swap() catch unreachable,
            .CyclicPermutation => |num| self.cyclic_permutation(num) catch unreachable,
            .Get => |num| self.get(num) catch unreachable,
            .ClearStack => self.clear_stack(),
            .Del => |num| self.del(num),
            .PrintHistory => self.print_history(),
            .Quit => running = false,
            .Copy => |num| self.copy(num) catch unreachable,
            else => {std.debug.print("Skip\n", .{});},
        }
        return running;
    }

    pub fn print_stack(self: *Session) void {
        std.debug.print("{any}\n", .{self});
    }

    pub fn print_history(self: *Session) void {
        std.debug.print("{s}\n", .{self.history.items});
    }

    pub fn format(self: *Session, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("Stack {{\n", .{});
        for (self.stack.items) |n| {
            try writer.print("    {d}\n", .{n});
        }
        try writer.print("}}\n", .{});
    }

};
