const std = @import("std");
const microzig = @import("microzig");
const stm32 = microzig.hal;

const pin_config = stm32.pins.GlobalConfiguration{
    .GPIOC = .{
        .PIN13 = .{ .name = "led1", .mode = .{ .output = .general_purpose_push_pull } },
    },
    .GPIOB = .{
        .PIN6 = .{ .name = "led2", .mode = .{ .output = .general_purpose_push_pull } },
    },
    .GPIOA = .{
        .PIN7 = .{ .name = "led3", .mode = .{ .output = .general_purpose_push_pull } },
    },
};

pub fn main() !void {
    const pins = pin_config.apply();

    while (true) {
        var i: u32 = 0;
        while (i < 800_000) {
            asm volatile ("nop");
            i += 1;
        }
        inline for (&.{ pins.led1, pins.led2, pins.led3 }) |pin| {
            pin.toggle();
        }
    }
}
