const microzig = @import("microzig");

pub const Mode = enum {
    output,
    input,
    input_pullup,
};

pub const GPIORegs = struct {
    PINx: u8,
    DDRx: u8,
    PORTx: u8,
};

//style 1, using enum and comptime, just hold the GPIO regs in a const
pub fn GPIO(comptime gpio_regs: *volatile GPIORegs) type {
    return enum(u8) {
        const regs = gpio_regs;
        const Self = @This();
        _,

        fn mask(gpio: Self) u8 {
            return @as(u8, 1) << @intCast(@intFromEnum(gpio));
        }

        pub fn set_direction(gpio: Self, mode: Mode) void {
            switch (mode) {
                .output => {
                    regs.DDRx |= gpio.mask();
                },
                .input => {
                    regs.DDRx &= ~(gpio.mask());
                    regs.PORTx &= ~(gpio.mask());
                },
                .input_pullup => {
                    regs.DDRx &= ~(gpio.mask());
                    regs.PORTx |= gpio.mask();
                },
            }
        }

        pub fn put(gpio: Self, value: u1) void {
            switch (value) {
                0 => regs.PORTx &= ~(gpio.mask()),
                1 => regs.PORTx |= gpio.mask(),
            }
        }

        pub fn read(gpio: Self) u1 {
            return if ((regs.PINx & gpio.mask()) != 0) 1 else 0;
        }

        pub fn toggle(gpio: Self) void {
            regs.PORTx ^= gpio.mask();
        }

        pub fn num(pin: u8) Self {
            return @enumFromInt(pin);
        }
    };
}

//style 2
//use GPIO2 to verify and create a instance of Pin
pub const Pin = struct {
    pin_mask: u8,
    regs: *volatile GPIORegs,

    pub fn set_direction(pin: *const Pin, mode: Mode) void {
        switch (mode) {
            .output => {
                pin.regs.DDRx |= pin.pin_mask;
            },
            .input => {
                pin.regs.DDRx &= ~pin.pin_mask;
                pin.regs.PORTx &= ~pin.pin_mask;
            },
            .input_pullup => {
                pin.regs.DDRx &= ~pin.pin_mask;
                pin.regs.PORTx |= pin.pin_mask;
            },
        }
    }

    pub fn put(pin: *const Pin, value: u1) void {
        switch (value) {
            0 => pin.regs.PORTx &= ~pin.pin_mask,
            1 => pin.regs.PORTx |= pin.pin_mask,
        }
    }

    pub fn read(pin: *const Pin) u1 {
        return if ((pin.regs.PINx & pin.pin_mask) != 0) 1 else 0;
    }

    pub fn toggle(pin: *const Pin) void {
        pin.regs.PORTx ^= pin.pin_mask;
    }
};

pub const GPIO2 = struct {
    disp_pin_mask: u8 = 255, //uselees now
    regs: *volatile GPIORegs,

    pub fn num(gpio: *const GPIO2, pin: u8) Pin {
        const pin_mask: u8 = @as(u8, 1) << @intCast(pin);
        return Pin{
            .pin_mask = pin_mask,
            .regs = gpio.regs,
        };
    }
};
