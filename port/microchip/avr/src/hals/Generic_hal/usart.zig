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

pub const Speed = enum {
    normal,
    double,
};

pub const XCKEdge = enum {
    normal,
    inverted,
};

pub const Mode = union(enum) {
    asynchronous: Speed,
    synchronous: XCKEdge,
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
    flow_control: FlowControl = .none,
    mode: Mode = .{ .asynchronous = .normal },
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

pub const USART = struct {
    regs: USART_regs,

    fn computeDivider(baud_rate: u32, cpu_clock: u32, cpu_div: u32) ConfigError!u12 {
        const clock_div = std.math.divTrunc(u32, cpu_clock, cpu_div) catch return ConfigError.BaudRate;
        const rate = std.math.divTrunc(u32, clock_div, baud_rate) catch return ConfigError.BaudRate;
        if (rate < 1) return ConfigError.BaudRate;

        return std.math.cast(u12, (rate - 1)) orelse return ConfigError.BaudRate;
    }

    fn check_fc_support(self: *const USART, fc: FlowControl) !void {
        if ((fc != .none) and (self.regs.UCSRD == null)) {
            return ConfigError.FlowControl;
        }
    }

    fn get_baudrate_div(mode: Mode) u32 {
        switch (mode) {
            .asynchronous => |value| {
                if (value == .double) {
                    return 8;
                }
            },
            else => {},
        }
        return 16;
    }

    pub fn apply(self: *const USART, comptime config: Config) !void {
        const div = comptime get_baudrate_div(config.mode);
        const ubrr = comptime computeDivider(config.baud_rate, config.cpu_clock, div) catch {
            @compileError(std.fmt.comptimePrint("this target does not support {} Baudrate speed with {} clock speed", .{ config.baud_rate, config.cpu_clock }));
        };

        const wordbits = switch (config.word_bits) {
            .five => 0b00,
            .six => 0b01,
            .seven => 0b10,
            .eight => 0b11,
        };

        const stopbits: u1 = @intFromEnum(config.stop_bits);
        const parity: u2 = switch (config.parity) {
            .none => 0,
            .even => 0b10,
            .odd => 0b11,
        };

        self.clear_regs();
        self.set_wordbits(wordbits);
        self.set_stopbits(stopbits);
        self.set_parity(parity);
        self.set_flowcontrol(config.flow_control);

        switch (config.mode) {
            .asynchronous => |value| {
                self.set_speed(value);
            },
            .synchronous => |value| {
                self.set_edge(value);
            },
        }
        self.set_baudrate(ubrr);

        self.regs.UCSRB.modify(.{
            .TXEN = 1,
            .RXEN = 1,
        });
    }

    fn clear_regs(self: *const USART) void {
        self.regs.UCSRA.raw = 0;
        self.regs.UCSRB.raw = 0;
        self.regs.UCSRC.raw = 0;
        self.regs.UBRR.* = 0;
    }

    fn set_wordbits(self: *const USART, wordbits: u2) void {
        self.regs.UCSRB.modify(.{
            .UCSZ2 = 0, //only for nine bits words
        });
        self.regs.UCSRC.modify(.{ .UCSZ = wordbits });
    }

    fn set_stopbits(self: *const USART, stopbits: u1) void {
        self.regs.UCSRC.modify(.{
            .USBS = stopbits,
        });
    }

    fn set_parity(self: *const USART, parity: u2) void {
        self.regs.UCSRC.modify(.{
            .UPM = parity,
        });
    }

    fn set_speed(self: *const USART, speed: Speed) void {
        const value: u1 = @intFromEnum(speed);
        self.regs.UCSRA.modify(.{ .U2X = value });
    }

    fn set_edge(self: *const USART, edge: XCKEdge) void {
        const value: u1 = @intFromEnum(edge);
        self.regs.UCSRC.modify(.{ .UCPOL = value });
    }

    fn set_flowcontrol(self: *const USART, flowcontrol: FlowControl) void {
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
        if (self.regs.UCSRD) |UCSRD| {
            UCSRD.modify(.{
                .RTSEN = rts,
                .CTSEN = cts,
            });
        }
    }

    fn set_baudrate(self: *const USART, value: u12) void {
        self.regs.UBRR.* = value;
    }

    fn check_errors(self: *const USART) ReceiveError!void {
        if (self.regs.UCSRA.read().FE == 1) return ReceiveError.FramingError;
        if (self.regs.UCSRA.read().DOR == 1) return ReceiveError.OverrunError;
        if (self.regs.UCSRA.read().UPE == 1) return ReceiveError.ParityError;
    }

    pub inline fn is_readable(self: *const USART) bool {
        return (self.regs.UCSRA.read().RXC == 1);
    }

    pub inline fn is_writeable(self: *const USART) bool {
        return (self.regs.UCSRA.read().UDRE == 1);
    }

    //just for tests
    pub fn read_byte(self: *const USART) ReceiveError!u8 {
        while (!self.is_readable()) {}
        try self.check_errors();
        return self.regs.UDR.*;
    }
    pub fn write_byte(self: *const USART, byte: u8) void {
        while (!self.is_writeable()) {}
        self.regs.UDR.* = byte;
    }

    pub fn init(regs: USART_regs) USART {
        return USART{ .regs = regs };
    }
};
