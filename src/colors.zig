const std = @import("std");
const Io = std.Io;

pub const Color = struct {
    red: u8,
    green: u8,
    blue: u8,


    pub fn init(red: u8, green: u8, blue: u8) Color {
        return .{
            .red = red,
            .green = green,
            .blue = blue,
        };
    }

    pub fn format(self: *const Color,  writer: *Io.Writer) !void {
        try writer.print("\x1b[38;2;{};{};{}m", .{self.red, self.green, self.blue});
    }
};

pub const NUMERIC_COLOR = Color.init(137, 220, 250);
pub const SESS_NAME_COLOR = Color.init(166, 227, 161);
pub const TEXT_COLOR = Color.init(249, 226, 175);
pub const ALERT_COLOR = Color.init(243, 139, 168);
pub const INDEX_COLOR = Color.init(203, 166, 247);
