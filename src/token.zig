const std = @import("std");

pub const TokenType = enum {
    Number,
    OpBinary,
    Reduce,
    OpUnary,
    Map,
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
    Reduce: *const fn (num: f64, num: f64) f64,
    OpUnary: *const fn (num: f64) f64,
    Map: *const fn (num: f64) f64,
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
    reduce,
    @"+", 
    @"-",
    @"*",
    @"/",
    // @"%",
    @"^",
    pow,
    map,
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
            .reduce => return switch_binary(&iter),
            .@"+" => return Token{ .OpBinary = add },
            .@"-" => return Token{ .OpBinary = sub },
            .@"*" => return Token{ .OpBinary = mul },
            // .@"%" => return Token{ .OpBinary = mod },
            .@"/" => return Token{ .OpBinary = div },
            .@"^" => return Token{ .OpBinary = pow },
            .pow => return Token{ .OpBinary = pow },
            .map => return switch_unary(&iter), 
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
            .log2 => return Token{ .OpUnary = log2 },
            .log10 => return Token{ .OpUnary = log10 },
            .sin => return Token{ .OpUnary = sin },
            .asin => return Token{ .OpUnary = asin },
            .cos => return Token{ .OpUnary = cos },
            .acos => return Token{ .OpUnary = acos },
            .sinh => return Token{ .OpUnary = sinh },
            .asinh => return Token{ .OpUnary = asinh },
            .cosh => return Token{ .OpUnary = cosh },
            .acosh => return Token{ .OpUnary = acosh },
            .tanh => return Token{ .OpUnary = tanh },
            .atanh => return Token{ .OpUnary = atanh },
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
            .new => return handleOneStr("NewSession", &iter),
            .change_to => return handleOneStr("ChangeSession", &iter), 
            .go_to => return handleOneStr("ChangeSession", &iter),
            .goto => return handleOneStr("ChangeSession", &iter),
            .rm => return handleOneStr("RemoveSession", &iter),
            // .reset => return Token{ .OpUnary = *const fn },
            .sess => return Token.PrintSessions,
            .hist => return Token.PrintHistory,
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

fn handleOneStr(comptime field_name: []const u8, 
    iter: *std.mem.SplitIterator(u8, .sequence)
) Token {
    const str_opt = iter.next();
    if (str_opt) |val| {
        return @unionInit(Token, field_name, val);
    } else {
        return  Token.Invalid;
    }
}

fn switch_binary(iter: *std.mem.SplitIterator(u8, .sequence)) Token {
    const binary_case = std.meta.stringToEnum(
        Case, iter.next() orelse "invalid"
    ) orelse Case.invalid;
    const token_binary = switch (binary_case) {
        .@"+" => Token{ .Reduce = add },
        .@"-" => Token{ .Reduce = sub },
        .@"*" => Token{ .Reduce = mul },
        .@"/" => Token{ .Reduce = div },
        .@"^" => Token{ .Reduce = pow }, // If you reduce with powers may God save your soul, but I will let you commit this sin.
        .pow => Token{ .Reduce = pow },
        else => Token.Invalid,
    };
    return token_binary;
}

fn switch_unary(iter: *std.mem.SplitIterator(u8, .sequence)) Token {
    const unary_case = std.meta.stringToEnum(
        Case, iter.next() orelse "invalid"
    ) orelse Case.invalid;
    const token_unary_fn = switch (unary_case) {
        .neg => Token{ .Map = neg },
        .inv => Token{ .Map = inv },
        .abs => Token{ .Map = abs },
        .sq => Token{ .Map = sq },
        .square => Token{ .Map = sq },
        .sqrt => Token{ .Map = sqrt },
        .cub => Token{ .Map = cub },
        .cube => Token{ .Map = cub },
        .cubrt => Token{ .Map = cbrt },
        .exp => Token{ .Map = exp },
        .ln => Token{ .Map = ln },
        .log2 => Token{ .Map = log2 },
        .log10 => Token{ .Map = log10 },
        .sin => Token{ .Map = sin },
        .asin => Token{ .Map = asin },
        .cos => Token{ .Map = cos },
        .acos => Token{ .Map = acos },
        .sinh => Token{ .Map = sinh },
        .asinh => Token{ .Map = asinh },
        .cosh => Token{ .Map = cosh },
        .acosh => Token{ .Map = acosh },
        .tanh => Token{ .Map = tanh },
        .atanh => Token{ .Map = atanh },
        else => Token.Invalid,
    };
    return token_unary_fn;
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
fn log2(num: f64) f64 { return std.math.log(f64, 2, num); }
fn log10(num: f64) f64 { return std.math.log(f64, 10, num); }
fn sin(num: f64) f64 { return std.math.sin(num); }
fn asin(num: f64) f64 { return std.math.asin(num); }
fn cos(num: f64) f64 { return std.math.cos(num); }
fn acos(num:f64) f64 { return std.math.cos(num); }
fn tan(num: f64) f64 { return std.math.tan(num); }
fn atan(num:f64) f64 { return std.math.tan(num); }
fn sinh(num:f64) f64 { return std.math.sinh(num); }
fn asinh(num: f64) f64 { return std.math.asinh(num); }
fn cosh(num: f64) f64 { return std.math.cosh(num); }
fn acosh(num: f64) f64 { return std.math.acosh(num); }
fn tanh(num: f64) f64 { return std.math.tanh(num); }
fn atanh(num: f64) f64 { return std.math.atanh(num); }
