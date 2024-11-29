const microzig = @import("microzig");

//This may change to allow for different memory layouts
//creating a struct that stores the pointers to the registers individually instead of a package
//(maybe it works for other families(?))
pub const GPIO_regs = struct {
    ///  Port configuration register low (GPIOn_CRL)
    CR: [2]u32,
    ///  Port input data register (GPIOn_IDR)
    IDR: u32,
    ///  Port output data register (GPIOn_ODR)
    ODR: u32,
    ///  Port bit set/reset register (GPIOn_BSRR)
    BSRR: u32,
    ///  Port bit reset register (GPIOn_BRR)
    BRR: u32,
    ///  Port configuration lock register
    LCKR: u32,
};

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
pub fn GPIO(gp_regs: *volatile GPIO_regs, gp_pin_mask: u16) type {
    return struct {
        const regs = gp_regs;
        const pin_mask = gp_pin_mask;
        const Pin = enum(u4) {
            _,

            pub fn set_mode(self: Pin, mode: Mode) void {
                const pin = @intFromEnum(self);
                const mode_val: u4 = @intFromEnum(mode);
                const conf_val: u4 = switch (mode) {
                    else => |value| @intFromEnum(value),
                };
                const bits: u32 = mode_val | (conf_val << 2);
                if (pin > 7) {
                    const pin_offset: u5 = pin - 8;
                    const offset = @as(u5, pin_offset) << 2;
                    regs.CR[1] &= ~(@as(u32, 0b1111) << offset);
                    regs.CR[1] |= bits << offset;
                } else {
                    const offset = @as(u5, pin) << 2;
                    regs.CR[0] &= ~(@as(u32, 0b1111) << offset);
                    regs.CR[0] |= bits << offset;
                }
            }

            pub fn put(self: Pin, value: u1) void {
                switch (value) {
                    0 => regs.ODR &= ~(@as(u32, value) << @intFromEnum(self)),
                    1 => regs.ODR |= @as(u32, value) << @intFromEnum(self),
                }
            }

            pub fn read(self: Pin) u1 {
                return if ((regs.IDR & (@as(u32, 1) << @intFromEnum(self))) != 0) 1 else 0;
            }

            pub fn read_state(self: Pin) u1 {
                return if ((regs.ODR & (@as(u32, 1) << @intFromEnum(self))) != 0) 1 else 0;
            }

            pub fn toggle(self: Pin) void {
                regs.ODR ^= @as(u32, 1) << @intFromEnum(self);
            }
        };
        //this can be comtime only
        pub fn num(pin: u4) !Pin {
            if ((pin_mask & @as(u16, 1) << pin) != 0) {
                return @enumFromInt(pin);
            }
            return error.InvalidPin;
        }
    };
}
