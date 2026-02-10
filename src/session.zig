const std = @import("std");
const Io = std.Io;
const Token = @import("token.zig").Token;
const Tokenizer = @import("token.zig").Tokenizer;
const Allocator = std.mem.Allocator;
const Colors = @import("colors.zig");

const NUMERIC_COLOR = Colors.NUMERIC_COLOR;
const SESS_NAME_COLOR = Colors.SESS_NAME_COLOR;
const TEXT_COLOR = Colors.TEXT_COLOR;
const ALERT_COLOR = Colors.ALERT_COLOR;
const INDEX_COLOR = Colors.INDEX_COLOR;

pub const Session = struct {
    stack: std.ArrayList(f64),
    history: std.ArrayList(u8),
    allocator: Allocator,
    states: std.ArrayList(std.ArrayList(f64)),
    undone_states: std.ArrayList(std.ArrayList(f64)),
   	
    pub fn init(allocator: Allocator) Session {
        return .{
            .stack = std.ArrayList(f64).empty,
            .history = std.ArrayList(u8).empty,
            .allocator = allocator, 
            .states = std.ArrayList(std.ArrayList(f64)).empty,
            .undone_states = std.ArrayList(std.ArrayList(f64)).empty,
        };
    }

    pub fn deinit(self: *Session) void {
        self.stack.deinit(self.allocator);
        self.history.deinit(self.allocator);
        for (self.states.items) |*state| {
            state.deinit(self.allocator);
        }
        self.states.deinit(self.allocator);
        for (self.undone_states.items) |*state| {
            state.deinit(self.allocator);
        }
        self.undone_states.deinit(self.allocator);
    }

    pub fn update_states(self: *Session) !void {
        const state = try self.stack.clone(self.allocator);
        try self.states.append(self.allocator, state);

        if (self.undone_states.items.len > 0) {
            for (self.undone_states.items) |*ustate| {
                ustate.deinit(self.allocator);
            }
            self.undone_states.clearAndFree(self.allocator);
        }
    }
    
    pub fn append_to_stack(self: *Session, val: f64) !void {
        try self.stack.append(self.allocator, val);
        try self.update_states();
    }
    
    pub fn pop_from_stack(self: *Session) f64 {
        return self.stack.pop().?;
    }
    
    pub fn append_to_history(self: *Session, str: []const u8) !void {
        try self.history.appendSlice(self.allocator, str);
        try self.history.appendSlice(self.allocator, "\n");
    }
    
    pub fn op_binary(self: *Session, bin_fn: *const fn(f64, f64) f64, writer: *Io.Writer) !void {
        if (self.stack.items.len > 1) {
            const y = self.pop_from_stack();
            const x = self.pop_from_stack();
            try self.append_to_stack(bin_fn(x, y));
        } else {
            try writer.print("{f}You need at least two numbers in ", .{ALERT_COLOR});
            try writer.print("the stack to perform binary operations.\n\n", .{});
        }
    }

    pub fn reduce(self: *Session, bin_fn: *const fn(f64, f64) f64, writer: *Io.Writer) !void {
        var acc = self.pop_from_stack();
        while (self.stack.items.len > 0) {
            const x = self.pop_from_stack();
            acc = bin_fn(x, acc);
            if (self.stack.items.len == 0) {
                try  self.append_to_stack(acc);
                break;
            }
        } else {
            try writer.print("{f}You need at least two numbers in ", .{ALERT_COLOR});
            try writer.print("the stack to perform binary operations.\n\n", .{});
        }
    }

    pub fn elementwise(self: *Session, num: f64, bin_fn: *const fn(f64,f64) f64, writer: *Io.Writer) !void {
        if (self.stack.items.len >= 1) {
            for (self.stack.items) |*el_ptr| {
                el_ptr.* = bin_fn(el_ptr.*, num);
            }
            try self.update_states();
        } else {
            try writer.print("{f}You need at least one number in ", .{ALERT_COLOR});
            try writer.print("the stack to perform unary operations.\n\n", .{});
        }

    }
    
    pub fn op_unary(self: *Session, un_fn: *const fn(f64) f64, writer: *Io.Writer) !void {
        if (self.stack.items.len >= 1) {
            const x = self.pop_from_stack();
            try self.append_to_stack(un_fn(x));
        } else {
            try writer.print("{f}You need at least one number in ", .{ALERT_COLOR});
            try writer.print("the stack to perform unary operations.\n\n", .{});
        }
    }

    pub fn map(self: *Session, un_fn: *const fn(num: f64) f64, writer: *Io.Writer) !void {
        if (self.stack.items.len >= 1) {
            for (self.stack.items) |*el_ptr| {
                el_ptr.* = un_fn(el_ptr.*);
            }
            try self.update_states();
        } else {
            try writer.print("{f}You need at least one number in ", .{ALERT_COLOR});
            try writer.print("the stack to perform unary operations.\n\n", .{});
        }
    }

    pub fn swap(self: *Session, writer: *Io.Writer) !void {
        if (self.stack.items.len > 1) {
            const y = self.pop_from_stack();
            const x = self.pop_from_stack();
            try self.stack.append(self.allocator, y);
            try self.stack.append(self.allocator, x);
            try self.update_states();
        } else {
            try writer.print("{f}You need at least two numbers in ", .{ALERT_COLOR});
            try writer.print("the stack to perform binary operations.\n\n", .{});
        }
    }

    pub fn cyclic_permutation(self: *Session, num: i32) !void {
        if (self.stack.items.len > 1) {
            if (num >= 0) {
                const count = @as(usize, @intCast(num));
                const dst = try self.stack.addManyAt(self.allocator, 0, count);
                for (0..count) |i| {
                    dst[count - i - 1] = self.pop_from_stack();
                }
            } else {
                const count = @as(usize, @intCast(-num));
                for (0..count) |_| {
                    const x = self.stack.orderedRemove(0);
                    try self.stack.append(self.allocator, x);
                }
            }
            try self.update_states();
        }
    }

    pub fn del(self: *Session, num: u32) !void {
        if (self.stack.items.len >= num) {
            for (0..num) |_| {
                _ = self.pop_from_stack();
            }
            try self.update_states();
        }
    }

    pub fn clear_stack(self: *Session) !void {
        self.stack.clearAndFree(self.allocator);
        try self.update_states();
    }

    pub fn copy(self: *Session, num: u32, writer: *Io.Writer) !void {
        if (self.stack.getLastOrNull()) |last| {
            try self.stack.appendNTimes(self.allocator, last, num);
        } else {
            try writer.print("{f}Cannot copy any elements the stack is empty.\n", .{ALERT_COLOR});
        }
        try self.update_states();
    }

    pub fn get(self: *Session, num: usize, writer: *Io.Writer) !void {
        if (num < self.stack.items.len) {
            const item = self.stack.orderedRemove(num);
            try self.append_to_stack(item);
        } else {
            try writer.print("Index exceeds stack length.\n", .{});
        }
    }

    pub fn insert(self: *Session, num: usize, val: f64, writer: *Io.Writer) !void {
        if (self.stack.items.len >= num) {
            try self.stack.insert(self.allocator, num, val);
        } else {
            try writer.print("{f}Provided index {} exceeds the length of the stack {}\n\n", .{ALERT_COLOR, num, self.stack.items.len});
        }
        try self.update_states();
    }

    pub fn undo(self: *Session, num: u32, writer: *Io.Writer) !void {
        if (self.states.items.len >= num) {
            for (0..num) |_| {
                const state = self.states.pop().?;
                try self.undone_states.append(self.allocator, state);
            }
            if (self.states.getLastOrNull()) |stack| {
                self.stack.deinit(self.allocator);
                self.stack = try stack.clone(self.allocator);
            }
        } else {
            try writer.print("{f}Exceeded the total history of operations.\n\n", .{ALERT_COLOR});
        }
    }

    pub fn redo(self: *Session, num: u32, writer: *Io.Writer) !void {
         if (self.undone_states.items.len >= num) {
            for (0..num) |_| {
                const state = self.undone_states.pop().?;
                try self.states.append(self.allocator, state);
            }
            if (self.states.getLastOrNull()) |stack| {
                self.stack.deinit(self.allocator);
                self.stack = try stack.clone(self.allocator);
            }
        } else {
            try writer.print("{f}Exceeded the total history of operations.\n\n", .{ALERT_COLOR});
        }
    }

    pub fn reset(self: *Session) void {
        self.stack.clearAndFree(self.allocator);
        self.history.clearAndFree(self.allocator);
        for (self.states.items) |*state| {
            state.deinit(self.allocator);
        }
        self.states.clearAndFree(self.allocator);
        for (self.undone_states.items) |*state| {
            state.deinit(self.allocator);
        }
        self.undone_states.clearAndFree(self.allocator);
    }

    pub fn print_history(self: *Session, writer: *Io.Writer) !void {
        try writer.print("{f}History:\n{s}\n\n", .{TEXT_COLOR, self.history.items});
    }

    pub fn format(self: *Session,  writer: *Io.Writer) !void {
        try writer.print("{f}Index:\t{f}Stack {{\n", 
            .{INDEX_COLOR, NUMERIC_COLOR});
        for (self.stack.items, 0..) |n, i| {
            if ((@abs(n) > 1e6) or (@abs(n) < 1e-3) and (n != 0)) {
                try writer.print("{f}{}\t    {f}{e}\n", 
                    .{INDEX_COLOR, i, NUMERIC_COLOR, n});
            } else {
                try writer.print("{f}{}\t    {f}{d}\n", 
                    .{INDEX_COLOR, i, NUMERIC_COLOR, n});
            }
        }
        try writer.print("\t}}\x1b[0m\n", .{});
    }

};
