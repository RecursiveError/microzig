const std = @import("std");
const micro = @import("microzig");
const generic_hal = @import("Generic_hal/hal.zig");
const peripherals = micro.chip.peripherals;
const USART0 = peripherals.USART0;

const GPIOB_regs: *volatile generic_hal.gpio.GPIORegs = @ptrCast(micro.chip.peripherals.PORTB);
const GPIOC_regs: *volatile generic_hal.gpio.GPIORegs = @ptrCast(micro.chip.peripherals.PORTC);
const GPIOD_regs: *volatile generic_hal.gpio.GPIORegs = @ptrCast(micro.chip.peripherals.PORTD);

pub const gpio = struct {
    pub const GPIOB = generic_hal.gpio.GPIO(GPIOB_regs);
    pub const GPIOC = generic_hal.gpio.GPIO(GPIOC_regs);
    pub const GPIOD = generic_hal.gpio.GPIO(GPIOD_regs);
};

pub const gpio2 = struct {
    pub const GPIOB = generic_hal.gpio.GPIO2{ .regs = GPIOB_regs };
    pub const GPIOC = generic_hal.gpio.GPIO2{ .regs = GPIOC_regs };
    pub const GPIOD = generic_hal.gpio.GPIO2{ .regs = GPIOD_regs };
};

const USART0_regs = generic_hal.usart.USART_regs{
    .UCSRA = @ptrCast(&USART0.UCSR0A),
    .UCSRB = @ptrCast(&USART0.UCSR0B),
    .UCSRC = @ptrCast(&USART0.UCSR0C),
    .UCSRD = null,
    .UBRR = @ptrCast(&USART0.UBRR0),
    .UDR = @ptrCast(&USART0.UDR0),
};

pub const usart = struct {
    pub const Config = generic_hal.usart.Config;
    pub const UART0 = generic_hal.usart.USART.init(USART0_regs);
};

const clock = struct {};
