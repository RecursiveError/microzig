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

//maybe create a output_pin and input_pin struct
pub const Pin = struct {
    regs: *volatile GPIO_regs,
    pin: u4,

    pub fn set_mode(self: *const Pin, mode: Mode) void {
        const pin = self.pin;
        const mode_val: u4 = @intFromEnum(mode);
        const conf_val: u4 = switch (mode) {
            else => |value| @intFromEnum(value),
        };
        const bits: u32 = mode_val | (conf_val << 2);
        if (pin > 7) {
            const pin_offset: u5 = pin - 8;
            const offset = @as(u5, pin_offset) << 2;
            self.regs.CR[1] &= ~(@as(u32, 0b1111) << offset);
            self.regs.CR[1] |= bits << offset;
        } else {
            const offset = @as(u5, pin) << 2;
            self.regs.CR[0] &= ~(@as(u32, 0b1111) << offset);
            self.regs.CR[0] |= bits << offset;
        }
    }

    pub fn put(self: *const Pin, value: u1) void {
        switch (value) {
            0 => self.regs.ODR &= ~(@as(u32, value) << self.pin),
            1 => self.regs.ODR |= @as(u32, value) << self.pin,
        }
    }

    pub fn read(self: *const Pin) u1 {
        return if ((self.regs.IDR & (@as(u32, 1) << self.pin)) != 0) 1 else 0;
    }

    pub fn read_state(self: *const Pin) u1 {
        return if ((self.regs.ODR & (@as(u32, 1) << self.pin)) != 0) 1 else 0;
    }

    pub fn toggle(self: *const Pin) void {
        self.regs.ODR ^= @as(u32, 1) << self.pin;
    }
};

pub const GPIO = struct {
    regs: *volatile GPIO_regs,
    pin_mask: u16 = 0xFFFF, //just for test

    pub fn init(comptime regs: *volatile GPIO_regs) GPIO {
        return GPIO{
            .regs = regs,
        };
    }
    //this can be comtime only
    pub fn num(self: *const GPIO, pin: u4) !Pin {
        const mask: u16 = @as(u16, 1) << pin;
        if ((self.pin_mask & mask) != 0) {
            return Pin{
                .pin = pin,
                .regs = self.regs,
            };
        }
        return error.InvalidPin;
    }
};
