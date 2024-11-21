//example using style1

const std = @import("std");
const microzig = @import("microzig");
const atmega328p = microzig.hal;

pub fn main() void {
    const led = atmega328p.gpio.GPIOB.num(5);
    led.set_direction(.output);
    while (true) {
        led.put(1);
        microzig.core.experimental.debug.busy_sleep(15000);
        led.put(0);
        microzig.core.experimental.debug.busy_sleep(15000);
    }
}
