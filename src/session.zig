const std = @import("std");
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
    
    fn append_to_stack(self: *Session, val: f64) !void {
        try self.stack.append(val);
    }
    
    fn pop_from_stack(self: *Session) f64 {
        return self.stack.pop().?;
    }
    
    fn append_to_history(self: *Session, str: []const u8) !void {
        return self.history.append(str);
    }
    
    fn op_binary(self: *Session, bin_closure: *const fn(num1: f64, num2: f64) f64) !void {
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
    
    fn op_unary(self: *Session, un_closure: *const fn(num: f64) f64) !void {
        if (self.stack.items.len >= 1) {
            const x = self.pop_from_stack();
            try self.append_to_stack(un_closure(x));
        } else {
            std.debug.print("You need at least one number in ", .{});
            std.debug.print("the stack to perform unary operations.\n", .{});
        }
        // self.update_states();
    }

    fn swap(self: *Session) !void {
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

    fn cyclic_permutation(self: *Session, num: i32) !void {
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

    fn del(self: *Session, num: u32) void {
        if (self.stack.items.len >= num) {
            for (0..num) |_| {
                _ = self.pop_from_stack();
            }
        }
    }

    fn clear_stack(self: *Session) void {
        self.stack.clearAndFree();
    }

    fn copy(self: *Session, num: u32) !void {
        const last = self.stack.getLast();
        for (0..num) |_| {
            try self.append_to_stack(last);
        }
    }

    fn get(self: *Session, num: usize) !void {
        if (num < self.stack.items.len) {
            const item = self.stack.orderedRemove(num);
            try self.append_to_stack(item);
        } else {
            std.debug.print("Index exceeds stack length.\n", .{});
        }
    }

    fn insert(self: *Session, num: usize, val: f64) !void {
        try self.stack.insert(num, val);
    }

    pub fn process_input(self: *Session, cmd_input: []u8) !bool {
        var running = true;
        var iter = std.mem.splitAny(u8, cmd_input, " \t\r\n");

        while (iter.next()) |tk| {
            if (!std.mem.eql(u8, tk[0..], "")) {
                // self.push_to_history(tk);
                const token = Tokenizer(tk[0..]);
                std.debug.print("{!}\n", .{token});
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
            .Quit => running = false,
            .Copy => |num| self.copy(num) catch unreachable,
            else => {std.debug.print("Skip\n", .{});},
        }
        return running;
    }

    pub fn print_stack(self: *Session) void {
        std.debug.print("{any}\n", .{self.stack.items});
    }

};

pub const TokenType = enum {
    Number,
    OpBinary,
    OpUnary,
    Del,
    ClearStack,
    Swap,
    CyclicPermutation,
    Get,
    // Insert,
    Invalid,
    NewSession,
    RemoveSession,
    ChangeSession,
    ResetSession,
    PrintSessions,
    PrintHistory,
    ClearHistory,
    Undo,
    Copy,
    Quit,
};

pub const Token = union(TokenType) {
    Number: f64,
    OpBinary: *const fn (num1: f64, num2: f64) f64,
    OpUnary: *const fn (num: f64) f64,
    Del: u32,
    ClearStack: void,
    Swap: void,
    CyclicPermutation: i32,
    Get: usize,
    // Insert: .{.i32, .f64},
    Invalid: void,
    NewSession: []const u8,
    RemoveSession: []const u8,
    ChangeSession: []const u8,
    ResetSession: void,
    PrintSessions: void,
    PrintHistory: void,
    ClearHistory: void,
    Undo: i32,
    Copy: u32,
    Quit: void,
};

const Case = enum {
    @"+", 
    @"-",
    @"*",
    @"/",
    // @"%",
    @"^",
    pow,
    neg,
    inv,
    abs,
    sq,
    square,
    sqrt,
    cub,
    cube,
    cubrt,
    exp,
    ln,
    log2,
    log10,
    sin,
    asin,
    cos,
    acos,
    sinh,
    asinh,
    cosh,
    acosh,
    tanh,
    atanh,
    pi,
    e,
    c,
    h,
    h_bar,
    quit,
    exit,
    delete,
    del,
    clear,
    swap,
    cyc,
    cycle,
    new,
    change_to,
    go_to,
    goto,
    rm,
    reset,
    sess,
    hist,
    hist_clear,
    undo,
    redo,
    get,
    insert,
    copy,
    cpy,
    invalid,
};

fn isAlpha(char: u8) bool {
    return (char >= 'a' and char <= 'z') or (char >= 'A' and char <= 'Z');
}

fn isDigit(char: u8) bool {
    return (char >= '0' and char <= '9');
}

fn isAlphaNum(char: u8) bool {
    return isDigit(char) and isAlpha(char);
}

pub fn Tokenizer(str: []const u8) Token {
    if (std.fmt.parseFloat(f64, str[0..])) |val| { 
        return Token{ .Number = val}; 
    } else |_| {
        var iter = std.mem.splitSequence(u8, str[0..], ":");
        //std.debug.print("{!}", .{@TypeOf(iter)});
        const case = std.meta.stringToEnum(Case, iter.first()) orelse Case.invalid;
        switch (case) {
            .@"+" => return Token{ .OpBinary = add },
            .@"-" => return Token{ .OpBinary = sub },
            .@"*" => return Token{ .OpBinary = mul },
            // .@"%" => return Token{ .OpBinary = mod },
            .@"/" => return Token{ .OpBinary = div },
            .@"^" => return Token{ .OpBinary = pow },
            .pow => return Token{ .OpBinary = pow },
            .neg => return Token{ .OpUnary = neg },
            .inv => return Token{ .OpUnary = inv },
            .abs => return Token{ .OpUnary = abs },
            .sq => return Token{ .OpUnary = sq },
            .square => return Token{ .OpUnary = sq },
            .sqrt => return Token{ .OpUnary = sqrt },
            .cub => return Token{ .OpUnary = cub },
            .cube => return Token{ .OpUnary = cub },
            .cubrt => return Token{ .OpUnary = cbrt },
            .exp => return Token{ .OpUnary = exp },
            .ln => return Token{ .OpUnary = ln },
            // .log2 => return Token{ .OpUnary = *const fn },
            // .log10 => return Token{ .OpUnary = *const fn },
            // .sin => return Token{ .OpUnary = *const fn },
            // .asin => return Token{ .OpUnary = *const fn },
            // .cos => return Token{ .OpUnary = *const fn },
            // .acos => return Token{ .OpUnary = *const fn },
            // .sinh => return Token{ .OpUnary = *const fn },
            // .asinh => return Token{ .OpUnary = *const fn },
            // .cosh => return Token{ .OpUnary = *const fn },
            // .acosh => return Token{ .OpUnary = *const fn },
            // .tanh => return Token{ .OpUnary = *const fn },
            // .atanh => return Token{ .OpUnary = *const fn },
            .pi => return Token{ .Number = std.math.pi },
            .e => return Token{ .Number = std.math.e },
            .c => return Token{ .Number = 299792458.0 },
            .h => return Token{ .Number = 6.62607015e-34 },
            .h_bar => return Token{ .Number = 6.62607015e-34 / (2 * std.math.pi) },
            .quit => return Token.Quit,
            .exit => return Token.Quit,
            .delete => return handleOneNumber(u32, "Del", &iter),
            .del => return handleOneNumber(u32, "Del", &iter),
            .clear => return Token.ClearStack,
            .swap => return Token.Swap,
            .cyc => return handleOneNumber(i32, "CyclicPermutation", &iter),
            .cycle => return handleOneNumber(i32, "CyclicPermutation", &iter),
            // .new => return Token{ .OpUnary = *const fn },
            // .change_to => return Token{ .OpUnary = *const fn },
            // .go_to => return Token{ .OpUnary = *const fn },
            // .goto => return Token{ .OpUnary = *const fn },
            // .rm => return Token{ .OpUnary = *const fn },
            // .reset => return Token{ .OpUnary = *const fn },
            // .sess => return Token{ .OpUnary = *const fn },
            // .hist => return Token{ .OpUnary = *const fn },
            // .hist_clear => return Token{ .OpUnary = *const fn },
            // .undo => return Token{ .OpUnary = *const fn },
            // .redo => return Token{ .OpUnary = *const fn },
            .get => return handleOneNumber(usize, "Get", &iter),
            // .insert => return Token{ .OpUnary = *const fn },
            .copy => return handleOneNumber(u32, "Copy", &iter),
            .cpy =>  return handleOneNumber(u32, "Copy", &iter),
            .invalid => return Token.Invalid,
            else => return Token.Invalid,
        }
    }
}

fn handleOneNumber(comptime T: type, comptime field_name: []const u8, 
    iter: *std.mem.SplitIterator(u8, .sequence)
) Token {
    const str_opt = iter.next();
    if (str_opt) |val| {
        if (std.fmt.parseInt(T, val, 10)) |num| { 
            return @unionInit(Token, field_name, num);
        } else |_| {
            return Token.Invalid;
        }
    } else {
        return @unionInit(Token, field_name, 1);
    }
}

fn add(num1: f64, num2: f64) f64 { return num1 + num2; }
fn sub(num1: f64, num2: f64) f64 { return num1 - num2; }
fn mul(num1: f64, num2: f64) f64 { return num1 * num2; }
// fn mod(num1: f64, num2: f64) f64 { return num1 % num2; }
fn div(num1: f64, num2: f64) f64 { return num1 / num2; }
fn pow(num1: f64, num2: f64) f64 { return std.math.pow(f64, num1, num2); }
fn neg(num: f64) f64 { return -num; }
fn inv(num: f64) f64 { return 1.0 / num; }
fn abs(num: f64) f64 { if (num >= 0) { return num; } else { return -num; } }
fn sq(num: f64) f64 { return num * num; }
fn sqrt(num: f64) f64 { return std.math.sqrt(num); }
fn cub(num: f64) f64 { return num * num * num; }
fn cbrt(num: f64) f64 {return std.math.cbrt(num); }
fn exp(num: f64) f64 { return std.math.exp(num); }
fn ln(num: f64) f64 { return std.math.log(f64, std.math.e, num); }

