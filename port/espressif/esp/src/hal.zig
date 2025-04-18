const microzig = @import("microzig");

pub const gpio = @import("hal/gpio.zig");
pub const uart = @import("hal/uart.zig");
pub const compatibility = @import("hal/compatibility.zig");
pub const rom = @import("hal/rom.zig");
pub const clocks = @import("hal/clocks.zig");
pub const usb_serial_jtag = @import("hal/usb_serial_jtag.zig");

/// Clock config applied by the default `init()` function of the hal.
pub const clock_config: clocks.Config = .default;

pub fn init() void {
    init_sequence(clock_config);
}

/// Allows you to easily swap the clock config while using the recommended init sequence. To be used
/// with a custom `init()` function.
pub fn init_sequence(clock_cfg: clocks.Config) void {
    // TODO: disable watchdogs in a more elegant way (with a hal).
    disable_watchdogs();

    clock_cfg.apply();

    // TODO: reset peripherals
    // TODO: disable peripheral clocks
}

// NOTE: might be esp32c3 specific only + temporary until timers hal.
fn disable_watchdogs() void {
    const peripherals = microzig.chip.peripherals;
    const TIMG0 = peripherals.TIMG0;
    const RTC_CNTL = peripherals.RTC_CNTL;

    const dogfood = 0x50D83AA1;
    const super_dogfood = 0x8F1D312A;

    // Feed and disable watchdog 0
    TIMG0.WDTWPROTECT.raw = dogfood;
    TIMG0.WDTCONFIG0.raw = 0;
    TIMG0.WDTWPROTECT.raw = 0;

    // Feed and disable rtc watchdog
    RTC_CNTL.WDTWPROTECT.raw = dogfood;
    RTC_CNTL.WDTCONFIG0.raw = 0;
    RTC_CNTL.WDTWPROTECT.raw = 0;

    // Feed and disable rtc super watchdog
    RTC_CNTL.SWD_WPROTECT.raw = super_dogfood;
    RTC_CNTL.SWD_CONF.modify(.{ .SWD_DISABLE = 1 });
    RTC_CNTL.SWD_WPROTECT.raw = 0;
}
