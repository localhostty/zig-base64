const std = @import("std");
const math = std.math;
var stdout_buffer: [1024]u8 = undefined;
var stdin_buffer: [1024]u8 = undefined;
var stdout_writer = std.fs.file.stdout().writer(&stdout_buffer);
var stdin_reader = std.fs.file.stdin().reader(&stdin_buffer);
const stdout = &stdout_writer.interface;
const stdin = &stdin_reader.interface;

pub fn main() !void {
    const base64 = Base64.init();
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const allocator = gpa.allocator();
    const text = "This is some random sequence";
    const out = try base64.encode(allocator, text);
    std.debug.print("{s}\n", .{out});
    const dec = try base64.decode(allocator, out);
    std.debug.print("{s}\n", .{dec});
    defer allocator.free(out);
    defer allocator.free(dec);
}

const Base64 = struct {
    _table: *const [64]u8,

    pub fn init() Base64 {
        const upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        const lower = "abcdefghijklmnopqrstuvwxyz";
        const numbers_symb = "0123456789+/";
        return Base64{
            ._table = upper ++ lower ++ numbers_symb,
        };
    }

    pub fn _char_at(self: Base64, index: usize) u8 {
        return self._table[index];
    }

    pub fn _char_index(self: Base64, char: u8) u8 {
        if (char == '=')
            return 64;

        var i: u8 = 0;
        var output_index: u8 = 0;

        while (i < 64) : (i += 1) {
            if (self._char_at(i) == char)
                break;
            output_index += 1;
        }

        return output_index;
    }

    // This is out of the book
    pub fn encode(self: Base64, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        if (input.len == 0) {
            return "";
        }

        const n_out = try _calc_encode_length(input);
        var out = try allocator.alloc(u8, n_out);
        var buf = [3]u8{ 0, 0, 0 };
        var count: u8 = 0;
        var iout: u64 = 0;

        for (input, 0..) |_, i| {
            buf[count] = input[i];
            count += 1;
            if (count == 3) {
                out[iout] = self._char_at(buf[0] >> 2);
                out[iout + 1] = self._char_at(((buf[0] & 0x03) << 4) + (buf[1] >> 4));
                out[iout + 2] = self._char_at(((buf[1] & 0x0f) << 2) + (buf[2] >> 6));
                out[iout + 3] = self._char_at(buf[2] & 0x3f);
                iout += 4;
                count = 0;
            }
        }

        if (count == 1) {
            out[iout] = self._char_at(buf[0] >> 2);
            out[iout + 1] = self._char_at((buf[0] & 0x03) << 4);
            out[iout + 2] = '=';
            out[iout + 3] = '=';
        }
        if (count == 2) {
            out[iout] = self._char_at(buf[0] >> 2);
            out[iout + 1] = self._char_at(((buf[0] & 0x03) << 4) + (buf[1] >> 4));
            out[iout + 2] = self._char_at((buf[1] & 0x0f) << 2);
            out[iout + 3] = '=';
        }

        return out;
    }

    pub fn decode(self: Base64, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        if (input.len == 0) {
            return "";
        }
        const len = try _calc_decode_length(input);
        var out = try allocator.alloc(u8, len);
        var buf = [4]u8{ 0, 0, 0, 0 };
        var count: u8 = 0;
        var iout: u64 = 0;

        for (0..input.len) |i| {
            buf[count] = self._char_index(input[i]);
            count += 1;
            if (count == 4) {
                out[iout] = (buf[0] << 2) + (buf[1] >> 4);
                if (buf[2] != 64)
                    out[iout + 1] = (buf[1] << 4) + (buf[2] >> 2);
                if (buf[3] != 64)
                    out[iout + 2] = (buf[2] << 6) + buf[3];
                iout += 3;
                count = 0;
            }
        }

        return out;
    }

    // This is the function I initially did by myself
    pub fn encode_1(self: Base64, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        const len = try _calc_encode_length(input);
        var elements: usize = 0;
        var output = try allocator.alloc(u8, len);
        var i: usize = 0;
        var idx: usize = 0;
        while (input.len > i) : (i += 3) {
            elements = (input.len + 3) - (i + 3);
            var b1: usize = 0;
            var b2: usize = 0;
            var b3: usize = 0;
            var b4: usize = 0;
            if (elements >= 4) {
                b1 = input[i] >> 2;
                b2 = ((input[i] & 0x03) << 4) + (input[i + 1] >> 4);
                b3 = ((input[i + 1] & 0x0f) << 2) + (input[i + 2] >> 6);
                b4 = input[i + 2] & 0x3f;
            } else if (elements == 2) {
                b1 = input[i] >> 2;
                b2 = ((input[i] & 0x03) << 4) + (input[i + 1] >> 4);
                b3 = ((input[i + 1] & 0x0f) << 2);
                b4 = '=';
            } else {
                b1 = input[i] >> 2;
                b2 = ((input[i] & 0x03) << 4);
                b3 = '=';
                b4 = '=';
            }
            output[idx] = self._char_at(b1);
            output[idx + 1] = self._char_at(b2);
            if (b3 != '=') {
                output[idx + 2] = self._char_at(b3);
            } else {
                output[idx + 2] = @intCast(b3);
            }
            if (b4 != '=') {
                output[idx + 3] = self._char_at(b4);
            } else {
                output[idx + 3] = @intCast(b4);
            }
            idx += 4;
        }

        return output;
    }
};

fn _calc_encode_length(input: []const u8) !usize {
    if (input.len < 3) {
        return 4;
    }
    const n_groups = try math.divCeil(usize, input.len, 3);
    return n_groups * 4;
}

fn _calc_decode_length(input: []const u8) !usize {
    if (input.len < 4) {
        return 3;
    }
    const n_groups = try math.divCeil(usize, input.len, 4);
    var multiple_groups = n_groups * 3;
    var i = input.len - 1;
    while (i > 0) : (i -= 1) {
        if (input[i] == '=') {
            multiple_groups -= 1;
        } else {
            break;
        }
    }
    return multiple_groups;
}
