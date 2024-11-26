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
    const led1 = stm32.gpio.gpio_test.GPIOC_t.num(13);
    const led2 = stm32.gpio.gpio_test.GPIOB_t.num(6);
    const led3 = stm32.gpio.gpio_test.GPIOA_t.num(7);
    const mode = stm32.gpio.gpio_test.Mode{ .output_2Mhz = .open_drain };
    inline for (&.{ led1, led2, led3 }) |pin| {
        pin.set_mode(mode);
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
