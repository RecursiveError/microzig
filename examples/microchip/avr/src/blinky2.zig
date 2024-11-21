//example using style2

const std = @import("std");
const microzig = @import("microzig");
const atmega328p = microzig.hal;

pub fn main() void {
    const led = atmega328p.gpio2.GPIOB.num(5);
    led.set_direction(.output);
    while (true) {
        led.put(1);
        microzig.core.experimental.debug.busy_sleep(50000);
        microzig.core.experimental.debug.busy_sleep(50000);
        microzig.core.experimental.debug.busy_sleep(50000);
        led.put(0);
        microzig.core.experimental.debug.busy_sleep(50000);
        microzig.core.experimental.debug.busy_sleep(50000);
        microzig.core.experimental.debug.busy_sleep(50000);
    }
}
