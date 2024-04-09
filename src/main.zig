const std = @import("std");

pub fn ZodashArray(comptime T: type) type {
    return struct {
        list: std.ArrayList(T),
        allocator: std.mem.Allocator,

        pub fn init(alloc: std.mem.Allocator) @This() {
            return @This(){
                .allocator = alloc,
                .list = std.ArrayList(T).init(alloc),
            };
        }

        pub fn deinit(arr: *@This()) void {
            arr.list.deinit();
        }

        pub fn filter(zarr: *@This(), comptime condition: fn (T) bool) *@This() {
            var new_arr = std.ArrayList(T).init(zarr.allocator);

            for (zarr.list.items) |item| {
                if (condition(item))
                    new_arr.append(item) catch unreachable;
            }

            zarr.list.deinit();
            zarr.list = new_arr;
            return zarr;
        }
    };
}

fn odd(num: u8) bool {
    return num % 2 == 0;
}

test "main test" {
    var arr = ZodashArray(u8).init(std.testing.allocator);
    try arr.list.appendSlice(&[_]u8{ 1, 2, 3, 4, 5, 6 });

    // after executing filter() arr is deinited, and me should deinit res
    var res = arr.filter(odd);
    defer arr.deinit();

    try std.testing.expectEqualSlices(u8, res.list.items, &[_]u8{ 2, 4, 6 });
}
