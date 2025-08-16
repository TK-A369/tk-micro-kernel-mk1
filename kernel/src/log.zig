const std = @import("std");

const log_ringbuffer_len = 4096;
export var log_ringbuffer = std.mem.zeroes([log_ringbuffer_len]u8);
var log_ringbuffer_curr_idx: usize = 0;

fn log_write_char(ch: u8) void {
    log_ringbuffer[log_ringbuffer_curr_idx] = ch;
    log_ringbuffer_curr_idx += 1;
    log_ringbuffer_curr_idx %= log_ringbuffer_len;
}

fn log_writer_drain(w: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
    for (0..w.end) |i| {
        log_write_char(w.buffer[i]);
    }
    w.end = 0;

    var len_written: usize = 0;
    for (data[0 .. data.len - 1]) |seg| {
        for (seg) |ch| {
            log_write_char(ch);
        }
        len_written += seg.len;
    }

    const pattern = data[data.len - 1];
    for (0..splat) |_| {
        for (pattern) |ch| {
            log_write_char(ch);
        }
        len_written += pattern.len;
    }

    return len_written;
}

var log_buffer = std.mem.zeroes([16]u8);
pub var log_writer = std.Io.Writer{
    .vtable = &.{ .drain = log_writer_drain },
    .buffer = &log_buffer,
};
