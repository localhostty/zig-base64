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
    defer allocator.free(out);
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

    fn encode(self: Base64, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
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
