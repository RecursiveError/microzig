const microzig = @import("microzig");
const GPIO_regs = microzig.chip.types.peripherals.gpio_v1.GPIO;

pub const Input = enum {
    Analog,
    Floating,
    Input_pull,
};

pub const Output = enum {
    push_pull,
    open_drain,
    AFIO_push_pull,
    AFIO_open_drain,
};

pub const Mode = union(enum) {
    input: Input,
    output_10Mhz: Output,
    output_2Mhz: Output,
    output_50Mhz: Output,
};
pub fn GPIO(gp_regs: *volatile GPIO_regs) type {
    return enum(u4) {
        const regs = gp_regs;
        const Self = @This();
        _,

        pub fn set_mode(self: Self, mode: Mode) void {
            const pin = @intFromEnum(self);
            const mode_val: u4 = @intFromEnum(mode);
            const conf_val: u4 = switch (mode) {
                else => |value| @intFromEnum(value),
            };
            const bits: u32 = mode_val | (conf_val << 2);
            if (pin > 7) {
                const pin_offset: u5 = pin - 8;
                const offset = @as(u5, pin_offset) << 2;
                regs.CR[1].raw &= ~(@as(u32, 0b1111) << offset);
                regs.CR[1].raw |= bits << offset;
            } else {
                const offset = @as(u5, pin) << 2;
                regs.CR[0].raw &= ~(@as(u32, 0b1111) << offset);
                regs.CR[0].raw |= bits << offset;
            }
        }

        pub fn put(self: Self, value: u1) void {
            switch (value) {
                0 => regs.ODR.raw &= ~(@as(u32, value) << @intFromEnum(self)),
                1 => regs.ODR.raw |= @as(u32, value) << @intFromEnum(self),
            }
        }

        pub fn read(self: Self) u1 {
            return if ((regs.IDR.raw & (@as(u32, 1) << @intFromEnum(self))) != 0) 1 else 0;
        }

        pub fn read_state(self: Self) u1 {
            return if ((regs.ODR.raw & (@as(u32, 1) << @intFromEnum(self))) != 0) 1 else 0;
        }

        pub fn toggle(self: Self) void {
            regs.ODR.raw ^= @as(u32, 1) << @intFromEnum(self);
        }
        //this can be comtime only
        pub fn num(pin: u4) Self {
            return @enumFromInt(pin);
        }
    };
}
