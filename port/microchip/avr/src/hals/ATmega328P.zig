const std = @import("std");
const micro = @import("microzig");
const generic_hal = @import("Generic_hal/hal.zig");
const peripherals = micro.chip.peripherals;
const USART0 = peripherals.USART0;

const GPIOB_regs: *volatile generic_hal.gpio.GPIORegs = @ptrCast(micro.chip.peripherals.PORTB);
const GPIOC_regs: *volatile generic_hal.gpio.GPIORegs = @ptrCast(micro.chip.peripherals.PORTC);
const GPIOD_regs: *volatile generic_hal.gpio.GPIORegs = @ptrCast(micro.chip.peripherals.PORTD);

pub const gpio = struct {
    pub const GPIOB = generic_hal.gpio.GPIO(GPIOB_regs);
    pub const GPIOC = generic_hal.gpio.GPIO(GPIOC_regs);
    pub const GPIOD = generic_hal.gpio.GPIO(GPIOD_regs);
};

pub const gpio2 = struct {
    pub const GPIOB = generic_hal.gpio.GPIO2{ .regs = GPIOB_regs };
    pub const GPIOC = generic_hal.gpio.GPIO2{ .regs = GPIOC_regs };
    pub const GPIOD = generic_hal.gpio.GPIO2{ .regs = GPIOD_regs };
};

pub const uart = struct {
    pub const DataBits = enum {
        five,
        six,
        seven,
        eight,
        nine,
    };

    pub const StopBits = enum {
        one,
        two,
    };

    pub const Parity = enum {
        odd,
        even,
    };
};

pub fn Uart(comptime index: usize, comptime pins: micro.uart.Pins) type {
    if (index != 0) @compileError("Atmega328p only has a single uart!");
    if (pins.tx != null or pins.rx != null)
        @compileError("Atmega328p has fixed pins for uart!");

    return struct {
        const Self = @This();

        fn computeDivider(baud_rate: u32) !u12 {
            const pclk = micro.clock.get().cpu;
            const divider = ((pclk + (8 * baud_rate)) / (16 * baud_rate)) - 1;

            return std.math.cast(u12, divider) orelse return error.UnsupportedBaudRate;
        }

        fn computeBaudRate(divider: u12) u32 {
            return micro.clock.get().cpu / (16 * @as(u32, divider) + 1);
        }

        pub fn init(config: micro.uart.Config) !Self {
            const ucsz: u3 = switch (config.data_bits) {
                .five => 0b000,
                .six => 0b001,
                .seven => 0b010,
                .eight => 0b011,
                .nine => return error.UnsupportedWordSize, // 0b111
            };

            const upm: u2 = if (config.parity) |parity| switch (parity) {
                .even => @as(u2, 0b10), // even
                .odd => @as(u2, 0b11), // odd
            } else 0b00; // parity disabled

            const usbs: u1 = switch (config.stop_bits) {
                .one => 0b0,
                .two => 0b1,
            };

            const umsel: u2 = 0b00; // Asynchronous USART

            // baud is computed like this:
            //             f(osc)
            // BAUD = ----------------
            //        16 * (UBRRn + 1)

            const ubrr_val = try computeDivider(config.baud_rate);

            USART0.UCSR0A.modify(.{
                .MPCM0 = 0,
                .U2X0 = 0,
            });
            USART0.UCSR0B.write(.{
                .TXB80 = 0, // we don't care about these btw
                .RXB80 = 0, // we don't care about these btw
                .UCSZ02 = @as(u1, @truncate((ucsz & 0x04) >> 2)),
                .TXEN0 = 1,
                .RXEN0 = 1,
                .UDRIE0 = 0, // no interrupts
                .TXCIE0 = 0, // no interrupts
                .RXCIE0 = 0, // no interrupts
            });
            USART0.UCSR0C.write(.{
                .UCPOL0 = 0, // async mode
                .UCSZ0 = @as(u2, @truncate((ucsz & 0x03) >> 0)),
                .USBS0 = usbs,
                .UPM0 = upm,
                .UMSEL0 = umsel,
            });

            USART0.UBRR0.modify(ubrr_val);

            return Self{};
        }

        pub fn canWrite(self: Self) bool {
            _ = self;
            return (USART0.UCSR0A.read().UDRE0 == 1);
        }

        pub fn tx(self: Self, ch: u8) void {
            while (!self.canWrite()) {} // Wait for Previous transmission
            USART0.UDR0.* = ch; // Load the data to be transmitted
        }

        pub fn canRead(self: Self) bool {
            _ = self;
            return (USART0.UCSR0A.read().RXC0 == 1);
        }

        pub fn rx(self: Self) u8 {
            while (!self.canRead()) {} // Wait till the data is received
            return USART0.UDR0.*; // Read received data
        }
    };
}
