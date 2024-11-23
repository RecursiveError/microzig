const std = @import("std");
const microzig = @import("microzig");
const mmio = microzig.mmio;

// GENERIC USART MMIO
pub const USART_regs = struct {
    UCSRA: *volatile mmio.Mmio(packed struct(u8) {
        MPCM: u1,
        U2X: u1,
        UPE: u1,
        DOR: u1,
        FE: u1,
        UDRE: u1,
        TXC: u1,
        RXC: u1,
    }),
    UCSRB: *volatile mmio.Mmio(packed struct(u8) {
        TXB8: u1,
        RXB8: u1,
        UCSZ2: u1,
        TXEN: u1,
        RXEN: u1,
        UDRIE: u1,
        TXCIE: u1,
        RXCIE: u1,
    }),
    UCSRC: *volatile mmio.Mmio(packed struct(u8) {
        UCPOL: u1,
        UCSZ: u2,
        USBS: u1,
        UPM: u2,
        UMSEL: u2,
    }),
    UCSRD: ?*volatile mmio.Mmio(packed struct(u8) {
        RTSEN: u1,
        CTSEN: u1,
        _: u6,
    }) = null, //this MMIO is optinal in the megaAVR series
    UBRR: *volatile u16,
    UDR: *volatile u8,
};

//config types
pub const WordBits = enum {
    five,
    six,
    seven,
    eight,
};

pub const StopBits = enum(u1) {
    one = 0,
    two,
};

pub const Parity = enum {
    none,
    odd,
    even,
};

pub const Speed = enum(u1) {
    normal = 0,
    double,
};

pub const FlowControl = enum {
    none,
    CTS,
    RTS,
    CTS_RTS,
};

pub const Config = struct {
    cpu_clock: u32,
    baud_rate: u32,
    word_bits: WordBits = .eight,
    stop_bits: StopBits = .one,
    parity: Parity = .none,
    speed: Speed = .normal,
    flow_control: FlowControl = .none,
};

//error types
pub const ConfigError = error{
    BaudRate,
    FlowControl,
};

pub const ReceiveError = error{
    OverrunError,
    ParityError,
    FramingError,
};

pub const ErrorStates = packed struct(u3) {
    overrun_error: bool = false,
    parity_error: bool = false,
    framing_error: bool = false,
};

pub fn Uart(usart_regs: USART_regs) type {
    return struct {
        const regs = usart_regs;
        const Self = @This();

        fn computeDivider(baud_rate: u32, cpu_clock: u32) ConfigError!u12 {
            const clock_div = std.math.divTrunc(u32, cpu_clock, 16) catch return ConfigError.BaudRate;
            const rate = std.math.divTrunc(u32, clock_div, baud_rate) catch return ConfigError.BaudRate;
            if (rate < 1) return ConfigError.BaudRate;

            return std.math.cast(u12, (rate - 1)) orelse return ConfigError.BaudRate;
        }

        pub fn check_fc_support(fc: FlowControl) !void {
            if ((fc != .none) and (regs.UCSRD == null)) {
                return ConfigError.FlowControl;
            }
        }

        pub fn apply(comptime config: Config) !void {
            comptime check_fc_support(config.flow_control) catch {
                @compileError("this target does not support Hardware Flow Control");
            };
            const ubrr = comptime computeDivider(config.baud_rate, config.cpu_clock) catch {
                @compileError(std.fmt.comptimePrint("this target does not support {} Baudrate speed with {} clock speed", .{ config.baud_rate, config.cpu_clock }));
            };

            apply_internal(config, ubrr);
        }

        pub fn apply_runtime(config: Config) ConfigError!void {
            try check_fc_support(config.flow_control);
            const ubrr = try computeDivider(config.baud_rate, config.cpu_clock);
            apply_internal(config, ubrr);
        }

        pub fn apply_internal(config: Config, ubrr_val: u12) void {
            set_wordbits(config.word_bits);
            set_stopbits(config.stop_bits);
            set_parity(config.parity);
            set_speed(config.speed);
            set_flowcontrol(config.flow_control);
            set_baudrate(ubrr_val);

            regs.UCSRB.modify(.{
                .TXEN = 1,
                .RXEN = 1,
            });

            regs.UCSRC.modify(.{
                .UCSZ = 3,
                .USBS = 1,
            });
        }

        fn set_wordbits(wordbits: WordBits) void {
            const ucsz: u2 = switch (wordbits) {
                .five => 0b00,
                .six => 0b01,
                .seven => 0b10,
                .eight => 0b11,
            };
            regs.UCSRB.modify(.{
                .UCSZ2 = 0, //only for nine bits words
            });
            regs.UCSRC.modify(.{
                .UCSZ = ucsz,
            });
        }

        fn set_stopbits(stopbits: StopBits) void {
            const value: u1 = @intFromEnum(stopbits);
            regs.UCSRC.modify(.{
                .USBS = value,
            });
        }

        fn set_parity(parity: Parity) void {
            const value: u2 = switch (parity) {
                .none => 0,
                .even => 0b10,
                .odd => 0b11,
            };

            regs.UCSRC.modify(.{
                .UPM = value,
            });
        }

        fn set_speed(speed: Speed) void {
            const value: u1 = @intFromEnum(speed);
            regs.UCSRA.modify(.{
                .U2X = value,
            });
        }

        fn set_flowcontrol(flowcontrol: FlowControl) void {
            var cts: u1 = 0;
            var rts: u1 = 0;
            switch (flowcontrol) {
                .CTS => cts = 1,
                .RTS => rts = 1,
                .CTS_RTS => {
                    cts = 1;
                    rts = 1;
                },
                else => {},
            }
            if (regs.UCSRD) |UCSRD| {
                UCSRD.modify(.{
                    .RTSEN = rts,
                    .CTSEN = cts,
                });
            }
        }

        fn set_baudrate(value: u12) void {
            regs.UBRR.* = value;
        }

        //just for tests
        pub fn read_byte() ReceiveError!u8 {
            while (regs.UCSRA.read().RXC != 1) {}
            return regs.UDR.*;
        }
        pub fn write_byte(byte: u8) void {
            while (regs.UCSRA.read().UDRE != 1) {}
            regs.UDR.* = byte;
        }
    };
}
