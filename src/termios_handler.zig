const std = @import("std");
const builtin = @import("builtin");
const GapBuffer = @import("gap_buffer.zig").GapBuffer;
const Allocator = std.mem.Allocator;
const Io = std.Io;
const posix = std.posix;
const fs = std.fs;
const File = fs.File;

pub const is_posix: bool = switch (builtin.os.tag) {
    .windows, .uefi, .wasi => false,
    else => true,
};

pub fn termiosHandler(reader: *Io.Reader, writer: *Io.Writer, 
    allocator: Allocator, buffersize: usize, history: *std.ArrayList(u8)) ![]u8 {

    var gap_buffer = try GapBuffer.initCapacity(allocator, buffersize);
    gap_buffer.buffer.appendNTimesAssumeCapacity(' ', buffersize);
    defer gap_buffer.deinit(allocator);

    const tty_file = try fs.openFileAbsolute("/dev/tty", .{});
    defer tty_file.close();
    const tty_fd = tty_file.handle;

    var old_settings: posix.termios = undefined;
    old_settings = try posix.tcgetattr(tty_fd);

    var new_settings: posix.termios = old_settings;
    new_settings.lflag.ICANON = false;
    new_settings.lflag.ECHO = false;
    new_settings.cc[6] = 1; //VMIN
    new_settings.cc[5] = 0; //VTIME
    new_settings.lflag.ECHOE = false;

    _ = try posix.tcsetattr(tty_fd, posix.TCSA.NOW, new_settings);

    var iter = std.mem.splitScalar(u8, history.items, '\n');
    var cmds = std.ArrayList([]const u8).empty;
    defer cmds.deinit(allocator);

    while (iter.peek() != null) {
        try cmds.append(allocator, iter.next().?);
    }
    const history_len = cmds.items.len;
    var history_idx = history_len - 1;

    blk: while (true) {
        const c: u8 = reader.takeByte() catch continue: blk;

        if (c == '\n') {
            _ = try posix.tcsetattr(tty_fd, posix.TCSA.NOW, old_settings);
            try writer.print("\n", .{});
            const str = try gap_buffer.outputString(allocator);
            return str;
        } else if (c == '\t') {
            continue: blk;
        } else if (c == '\x7F') {
            gap_buffer.deleteLeft();
        } else if (c == '\x1B') {

            // switch to non-blocking to handle escape sequences
            new_settings.cc[6] = 0; //VMIN
            _ = try posix.tcsetattr(tty_fd, posix.TCSA.NOW, new_settings);

            var char: u8 = reader.takeByte() catch |err| switch (err) {
                error.EndOfStream => {
                    _ = try posix.tcsetattr(tty_fd, posix.TCSA.NOW, old_settings);
                    var quit_cmd = [_]u8{'q', 'u', 'i', 't', '\n'};
                    try gap_buffer.replaceAll(allocator, quit_cmd[0..quit_cmd.len]);
                    try writer.print("{f}", .{&gap_buffer});
                    const str = try gap_buffer.outputString(allocator);
                    return str;
                },
                error.ReadFailed => return err,
            };

            esc: switch (char) {
                '[' => {

                    char = reader.takeByte() catch |err| switch (err) {
                        error.EndOfStream => break: esc,
                        error.ReadFailed => return err,
                    };

                    switch (char) {

                        '3' => {
                            char = reader.takeByte() catch |err| switch (err) {
                                error.EndOfStream => break: esc,
                                error.ReadFailed => return err,
                            };
                            if (char == '~') {
                                gap_buffer.deleteRight();
                            } else {
                                break: esc;
                            }
                        },

                        'A' => {
                            // Handle up arrow input
                            if (history_idx > 0) {
                                history_idx -= 1;
                            }
                            try gap_buffer.replaceAll(allocator, cmds.items[history_idx]);
                            try writer.print("{f}", .{&gap_buffer});
                        },

                        'B' => {
                            // Handle down arrow input
                            if (history_idx < history_len - 1) {
                                history_idx += 1;
                            }
                            try gap_buffer.replaceAll(allocator, cmds.items[history_idx]); 
                            try writer.print("{f}", .{&gap_buffer});
                        },

                        'C' => {
                            // Handle right arrow input
                            gap_buffer.moveCursorRight();
                            try writer.print("{f}", .{&gap_buffer});
                        },

                        'D' => {
                            // Handle left arrow input
                            gap_buffer.moveCursorLeft();
                            try writer.print("{f}", .{&gap_buffer});
                        },

                        'H' => {
                            // Handle Home key
                            gap_buffer.moveCursorToStart();
                            try writer.print("{f}", .{&gap_buffer});
                        },

                        'F' => {
                            // Handle End key
                            gap_buffer.moveCursorToEnd();
                            try writer.print("{f}", .{&gap_buffer});
                        },
                        // '5' => continue: esc '~',
                        // '6' => continue: esc '~',
                        // '~' => break: esc,
                        else => try writer.print(
                            "failed to handle escape [: {c}", .{char}
                        ),
                    }

                    break: esc;

                },

                else => {
                    try writer.print("{c}", .{char});
                    break: esc;
                },
            }

            new_settings.cc[6] = 0; //VMIN
            _ = try posix.tcsetattr(tty_fd, posix.TCSA.NOW, new_settings);

        } else {
            try gap_buffer.insertInGap(allocator, c);
        }
        try writer.print("{f}", .{&gap_buffer});
        try writer.flush();
    }

}
