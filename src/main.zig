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

        pub fn clone(this: @This()) @This() {
            var clonned = std.ArrayList(T).init(this.allocator);
            clonned.appendSlice(this.list.items) catch unreachable;
            var res = @This(){
                .allocator = this.allocator,
                .list = clonned,
            };
            return res;
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

test "Clone" {
    var arr = ZodashArray(u8).init(std.testing.allocator);
    defer arr.deinit();
    try arr.list.appendSlice(&[_]u8{ 1, 2, 3, 4, 5, 6 });

    var clone = arr.clone();
    var res = clone.filter(odd);
    defer res.deinit();

    try std.testing.expect(!std.mem.eql(u8, res.list.items, arr.list.items));
}

test "Filter" {
    var arr = ZodashArray(u8).init(std.testing.allocator);
    defer arr.deinit();
    try arr.list.appendSlice(&[_]u8{ 1, 2, 3, 4, 5, 6 });

    var res = arr.filter(odd);

    try std.testing.expectEqualSlices(u8, res.list.items, &[_]u8{ 2, 4, 6 });
}
