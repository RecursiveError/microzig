const std = @import("std");
const microzig = @import("microzig");
const RCC = microzig.chip.peripherals.RCC;
const stm32 = microzig.hal;

pub fn main() !void {
    RCC.APB2ENR.modify(.{
        .GPIOAEN = 1,
        .GPIOBEN = 1,
        .GPIOCEN = 1,
    });
    const led1 = stm32.gpio.Pin.init(2, 13);
    const led2 = stm32.gpio.Pin.init(1, 6);
    const led3 = stm32.gpio.Pin.init(0, 7);

    inline for (&.{ led1, led2, led3 }) |pin| {
        pin.set_mode(.{ .output = .general_purpose_push_pull });
    }

    while (true) {
        var i: u32 = 0;
        while (i < 800_000) {
            asm volatile ("nop");
            i += 1;
        }
        inline for (&.{ led1, led2, led3 }) |pin| {
            pin.toggle();
        }
    }
}
