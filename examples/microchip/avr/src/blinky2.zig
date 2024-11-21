//example using style2

const std = @import("std");
const microzig = @import("microzig");
const atmega328p = microzig.hal;

fn long_delay(limit: comptime_int) void {
    for (0..5) |_| {
        microzig.core.experimental.debug.busy_sleep(limit);
    }
}

pub fn main() void {
    const led = atmega328p.gpio2.GPIOB.num(5);
    led.set_direction(.output);
    while (true) {
        led.put(1);
        long_delay(15000);
        led.put(0);
        long_delay(15000);
    }
}
