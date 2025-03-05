pub const version = @import("config").version;
pub const order = @import("order.zig");
pub const mem = @import("mem.zig");
pub const string = @import("string.zig");

const ordered_list = @import("ordered_list.zig");
pub const OrderedList = ordered_list.OrderedList;

const recycle_list = @import("recycle_list.zig");
pub const RecycleList = recycle_list.RecycleList;

const math = @import("std").math;

pub const RgbColor = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,

    pub fn fromHsl(hsl: HslColor) RgbColor {
        const c = (1 - @abs(2 * hsl.l - 1)) * hsl.s;
        const x = c * (1 - @abs(@mod(hsl.h / 60, 2) - 1));
        const m = hsl.l - c / 2;

        const r, const g, const b = switch (@as(u3, @intFromFloat(@mod(hsl.h, 360) / 60))) {
            0 => .{ c, x, 0 },
            1 => .{ x, c, 0 },
            2 => .{ 0, c, x },
            3 => .{ 0, x, c },
            4 => .{ x, 0, c },
            5 => .{ c, 0, x },
            else => unreachable,
        };

        return RgbColor{
            .r = @intFromFloat((m + r) * 255),
            .g = @intFromFloat((m + g) * 255),
            .b = @intFromFloat((m + b) * 255),
            .a = hsl.a,
        };
    }
};

pub const HslColor = struct {
    h: f32,
    s: f32,
    l: f32,
    a: u8 = 255,

    pub fn fromRbg(rgb: RgbColor) HslColor {
        const r = math.lossyCast(f32, rgb.r) / 255.0;
        const g = math.lossyCast(f32, rgb.g) / 255.0;
        const b = math.lossyCast(f32, rgb.b) / 255.0;

        const c_max = @max(r, g, b);
        const c_min = @min(r, g, b);
        const delta = c_max - c_min;

        const l = (c_max + c_min) / 2;

        return if (delta == 0)
            HslColor{
                .h = 0.0,
                .s = 0.0,
                .l = l,
                .a = rgb.a,
            }
        else
            HslColor{
                .h = (60 * (if (c_max == r)
                    @mod((g - b) / delta, 6)
                else if (c_max == g)
                    (b - r) / delta + 2
                else if (c_max == b)
                    (r - g) / delta + 4
                else
                    unreachable)),
                .s = delta / (1 - @abs(2 * l - 1)),
                .l = l,
                .a = rgb.a,
            };
    }
};
