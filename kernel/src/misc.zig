pub fn hcf() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}
