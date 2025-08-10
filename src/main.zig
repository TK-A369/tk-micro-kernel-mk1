const std = @import("std");
const limine = @cImport(@cInclude("limine.h"));

// See LIMINE_BASE_REVISION macro in limine.h
const limine_base_revision linksection(".limine_requests") = [3]u64{
    0xf9562b2d5c95a6c8,
    0x6a7b384944536bdc,
    3,
};
const limine_requests_start_marker linksection(".limine_requests_start") = [4]u64{
    0xf6b8f4b39de7d1ae,
    0xfab91a6940fcb9cf,
    0x785c6ed015d3e316,
    0x181e920a7852b9d9,
};
const limine_requests_end_marker linksection(".limine_requests_end") = [2]u64{
    0xadc0e0531bb10d03,
    0x9572709f31764c62,
};

pub fn kmain() linksection(".text") callconv(.c) !void {}
