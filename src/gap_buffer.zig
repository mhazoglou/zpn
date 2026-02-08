const std = @import("std");
const Allocator = std.mem.Allocator;

const GapBuffer = struct {
    size: usize,
    cursor: usize,
    gap_len: usize,
    buffer: std.ArrayList(u8),
    
    pub fn initCapacity(allocator: Allocator, buffersize: usize) !GapBuffer {
        if (buffersize > 0) {
            return .{
                .size = buffersize,
                .cursor = 0,
                .gap_len = buffersize,
                .buffer = try std.ArrayList(u8).initCapacity(allocator, buffersize),
            };
        } else {
            return .{
                .size = 0,
                .cursor = 0,
                .gap_len = 0,
                .buffer = std.ArrayList(u8).empty,
            };
        }
    }

    pub fn deinit(self: *GapBuffer, allocator: Allocator) void {
        self.buffer.deinit(allocator);
    }

    pub fn ensureUnusedCapacity(self: *GapBuffer, allocator: Allocator, additional_count: usize) !void {
        try self.buffer.ensureUnusedCapacity(allocator, additional_count);
        self.size += additional_count;
    }

    pub fn growGap(self: *GapBuffer, allocator: Allocator, count: usize) !void {
        if (self.size < self.cursor + self.gap_len + count) {
            try self.ensureUnusedCapacity(allocator, count);
        }
        self.gap_len += count;
    }

    pub fn moveCursorLeft(self: *GapBuffer) void {
        if (self.cursor == 0) {
            return;
        }
        self.cursor -= 1;
        self.buffer.items[self.cursor + self.gap_len] = self.buffer.items[self.cursor];
    }

    pub fn moveCursorRight(self: *GapBuffer) void {
        if (self.cursor + self.gap_len >= self.size) {
            return;
        }
        self.buffer.items[self.cursor] = self.buffer.items[self.cursor + self.gap_len];
        self.cursor += 1;
    }

    pub fn insertInGap(self: *GapBuffer, allocator: Allocator, char: u8) !void {
        self.buffer.items[self.cursor] = char;
        if (self.gap_len <= 1) {
            try self.growGap(allocator, self.size);
        }
        self.gap_len -= 1;
        self.cursor += 1;
    }

    pub fn deleteLeft(self: *GapBuffer) void {
        if (self.cursor == 0) {
            return;
        }
        self.cursor -= 1;
        self.gap_len += 1;
    }

    pub fn deleteRight(self: *GapBuffer) void {
        if (self.cursor + self.gap_len == self.size) {
            return;
        }
        self.gap_len += 1;
    }

    pub fn format(self: *GapBuffer, writer: *Io.Writer) !void {
        try writer.print("\x1B[0G\x1B[2K", .{});
        try writer.print("{s}", .{self.buffer.items[0..self.cursor]});
        if (self.cursor + self.gap_len <= self.size - 1) {
              try writer.print("{s}", .{self.buffer.items[self.cursor + self.gap_len..]});
        }
        // Don't really understand why it needs this offset
        try writer.print("\x1B[{d}G", .{self.cursor + 1});
    }
};

