const std = @import("std");
const microzig = @import("microzig");
const atmega328p = microzig.hal;

fn long_delay(limit: comptime_int) void {
    for (0..5) |_| {
        microzig.core.experimental.debug.busy_sleep(limit);
    }
}

const config = atmega328p.usart.Config{
    .cpu_clock = 16_000_000,
    .baud_rate = 9600,
};
const UART0 = atmega328p.usart.UART0;

const msg = "hello uart!0$!\n";

pub fn main() void {
    const led = atmega328p.gpio.GPIOB.num(5);
    led.set_direction(.output);

    UART0.apply(config) catch {
        while (true) {
            led.toggle();
            long_delay(15000);
        }
    };
    while (true) {
        for (msg) |ch| {
            UART0.write_byte(ch);
        }
        long_delay(60000);
    }
}
