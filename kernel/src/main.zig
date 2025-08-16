const limine = @cImport(@cInclude("limine.h"));

const log = @import("log.zig");

// See LIMINE_BASE_REVISION macro in limine.h
export var limine_base_revision linksection(".limine_requests") = [3]u64{
    0xf9562b2d5c95a6c8,
    0x6a7b384944536bdc,
    3,
};
export var limine_memmap_request linksection(".limine_requests") = limine.limine_memmap_request{
    .id = [4]u64{
        0xc7b1dd30df4c8b88,
        0x0a82e883a194f07b,
        0x67cf3d9d378a806f,
        0xe304acdfc50c3c62,
    },
    .revision = 0,
};
export var limine_hhdm_request linksection(".limine_requests") = limine.limine_hhdm_request{
    .id = [4]u64{
        0xc7b1dd30df4c8b88,
        0x0a82e883a194f07b,
        0x48dcf1cb8ad2b852,
        0x63984e959a98244b,
    },
    .revision = 0,
};
export var framebuffer_request linksection(".limine_requests") = limine.limine_framebuffer_request{
    .id = [4]u64{
        0xc7b1dd30df4c8b88,
        0x0a82e883a194f07b,
        0x9d5827dcd881dd75,
        0xa3148604f6fab11b,
    },
    .revision = 0,
};

export var limine_requests_start_marker linksection(".limine_requests_start") = [4]u64{
    0xf6b8f4b39de7d1ae,
    0xfab91a6940fcb9cf,
    0x785c6ed015d3e316,
    0x181e920a7852b9d9,
};
export var limine_requests_end_marker linksection(".limine_requests_end") = [2]u64{
    0xadc0e0531bb10d03,
    0x9572709f31764c62,
};

fn hcf() void {
    while (true) {
        asm volatile ("hlt");
    }
}

pub export fn kmain() linksection(".text") callconv(.c) void {
    if (framebuffer_request.response == null) {
        hcf();
    }

    const fb = framebuffer_request.response.*.framebuffers[0];
    const fb_address = @as([*]u32, @ptrCast(@alignCast(fb.*.address.?)));
    for (0..100) |i| {
        fb_address[i * (fb.*.pitch / 4) + i] = 0xffffff;
    }

    // log.log_writer.print("Hello world!\n1 + 2 = {d}", .{1 + 2}) catch {};
    log.log_writer.writeAll("Hello wrold!\nLorem ipsum dolor sir amet\n") catch {};
    log.log_writer.flush() catch {};

    while (true) {}
}
