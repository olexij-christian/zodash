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

        pub fn filter(arr: *@This(), comptime condition: fn (T) bool) @This() {
            var res_arr = @This().init(arr.allocator);
            defer arr.deinit();
            for (arr.list.items) |item| {
                if (condition(item))
                    res_arr.list.append(item) catch unreachable;
            }
            return res_arr;
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
    defer res.deinit();

    try std.testing.expectEqualSlices(u8, res.list.items, &[_]u8{ 2, 4, 6 });
}
