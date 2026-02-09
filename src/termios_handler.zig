const std = @import("std");
const builtin = @import("builtin");
const GapBuffer = @import("gap_buffer.zig").GapBuffer;
const Allocator = std.mem.Allocator;
const Io = std.Io;
const linux = std.os.linux;
const fs = std.fs;
const File = fs.File;

pub fn termios_handler(reader: *Io.Reader, writer: *Io.Writer, 
    allocator: Allocator, buffersize: usize) ![]u8 {

    var gap_buffer = try GapBuffer.initCapacity(allocator, buffersize);
    gap_buffer.buffer.appendNTimesAssumeCapacity(' ', buffersize);
    defer gap_buffer.deinit(allocator);

    const tty_file = try fs.openFileAbsolute("/dev/tty", .{});
    defer tty_file.close();
    const tty_fd = tty_file.handle;

    var old_settings: linux.termios = undefined;
    _ = linux.tcgetattr(tty_fd, &old_settings);

    var new_settings: linux.termios = old_settings;
    new_settings.lflag.ICANON = false;
    new_settings.lflag.ECHO = false;
    new_settings.cc[6] = 0; //VMIN
    new_settings.cc[5] = 1; //VTIME
    new_settings.lflag.ECHOE = false;

    _ = linux.tcsetattr(tty_fd, linux.TCSA.NOW, &new_settings);


    blk: while (true) {
        const c: u8 = reader.takeByte() catch continue: blk;

        if (c == '\n') {
            _ = linux.tcsetattr(tty_fd, linux.TCSA.NOW, &old_settings);
            // try gap_buffer.insertInGap(allocator, c);
            const str = try gap_buffer.outputString(allocator);
            return str;
        } else if (c == '\x7F') {
            gap_buffer.deleteLeft();
        } else if (c == '\x1B') {
            var char: u8 = reader.takeByte() catch |err| switch (err) {
                error.EndOfStream => {
                    try writer.print("Escape button was pressed only.", .{});
                    try writer.flush();
                    continue: blk;
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
                        'A' => try writer.print("\x1B[A", .{}),
                        'B' => try writer.print("\x1B[B", .{}),
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
                        'H' => try writer.print("\x1B[H", .{}),
                        'F' => try writer.print("\x1B[F", .{}),
                        // '5' => continue: esc '~',
                        // '6' => continue: esc '~',
                        // '~' => break: esc,
                        else => try writer.print("failed to handle escape [: {c}", .{char}),
                    }
                    break: esc;
                },
                else => {
                    try writer.print("{c}", .{char});
                    break: esc;
                },
            }
        } else {
            try gap_buffer.insertInGap(allocator, c);
            // try writer.print("{c}", .{c});
        }
        try writer.print("{f}", .{&gap_buffer});
        try writer.flush();
    }

}
