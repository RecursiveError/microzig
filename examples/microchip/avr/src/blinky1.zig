//example using style1

const std = @import("std");
const microzig = @import("microzig");
const atmega328p = microzig.hal;

fn long_delay(limit: comptime_int) void {
    for (0..5) |_| {
        microzig.core.experimental.debug.busy_sleep(limit);
    }
}

pub fn main() void {
    const led = atmega328p.gpio.GPIOB.num(5);
    led.set_direction(.output);
    while (true) {
        led.toggle();
        long_delay(35000);
    }
}
