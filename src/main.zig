const std = @import("std");

pub fn ZodashArray(comptime T: type) type {
    return struct {
        list: std.ArrayList(T),
        allocator: std.mem.Allocator,

        const ZAType = @This();

        pub fn init(alloc: std.mem.Allocator) @This() {
            return @This(){
                .allocator = alloc,
                .list = std.ArrayList(T).init(alloc),
            };
        }

        pub fn deinit(arr: *@This()) void {
            arr.list.deinit();
        }

        pub fn clone(this: @This()) !@This() {
            var res = @This(){
                .allocator = this.allocator,
                .list = try this.list.clone(),
            };
            return res;
        }

        pub fn FilterIterator(comptime condition: fn (T) bool) type {
            return struct {
                index: usize,
                arr: []const T,

                fn next(this: *@This()) ?T {
                    while (this.index < this.arr.len) {
                        defer this.index += 1;
                        const item = this.arr[this.index];
                        if (condition(item))
                            return item;
                    }
                    return null;
                }

                fn init(zarr: ZAType) @This() {
                    return @This(){ .index = 0, .arr = zarr.list.items };
                }
            };
        }

        pub fn filter(zarr: *@This(), comptime condition: fn (T) bool) !void {
            var new_arr = std.ArrayList(T).init(zarr.allocator);
            var iterator = FilterIterator(condition).init(zarr.*);

            while (iterator.next()) |item|
                try new_arr.append(item);

            zarr.list.deinit();
            zarr.list = new_arr;
        }

        const DefaultStages = union(enum) {
            filter: fn (T) bool,
        };

        pub fn exec(this: *@This(), comptime stages: anytype) !void {
            inline for (stages) |stg| {
                const switchable = @as(DefaultStages, stg);
                switch (switchable) {
                    .filter => |func| try this.filter(func),
                }
            }
        }

        // TODO prepare parts for future stage system
        const StageBool = struct {
            conditionFn: fn (T) bool,
            handlerFn: fn (*@This(), fn (T) bool) std.mem.Allocator.Error!*@This(),
        };
        pub fn Filter(comptime func: fn (T) bool) StageBool {
            return StageBool{
                .conditionFn = func,
                .handlerFn = @This().filter,
            };
        }
    };
}

fn odd(num: u8) bool {
    return num % 2 == 0;
}

fn notodd(num: u8) bool {
    return num % 2 != 0;
}

test "Filter" {
    var arr = ZodashArray(u8).init(std.testing.allocator);
    defer arr.deinit();

    try arr.list.appendSlice(&[_]u8{ 1, 2, 3, 4, 5, 6 });

    try arr.filter(odd);

    try std.testing.expectEqualSlices(u8, arr.list.items, &[_]u8{ 2, 4, 6 });
}

test "FilterIterator" {
    var arr = ZodashArray(u8).init(std.testing.allocator);
    defer arr.deinit();

    try arr.list.appendSlice(&[_]u8{ 1, 2, 3, 4, 5, 6 });

    var iterator = ZodashArray(u8).FilterIterator(odd).init(arr);

    try std.testing.expectEqual(iterator.next().?, 2);
    try std.testing.expectEqual(iterator.next().?, 4);
    try std.testing.expectEqual(iterator.next().?, 6);
    try std.testing.expectEqual(iterator.next(), null);
}

test "Clone" {
    var arr = ZodashArray(u8).init(std.testing.allocator);
    defer arr.deinit();

    try arr.list.appendSlice(&[_]u8{ 1, 2, 3, 4, 5, 6 });

    var clone = try arr.clone();
    defer clone.deinit();

    try clone.filter(odd);

    try std.testing.expect(!std.mem.eql(u8, clone.list.items, arr.list.items));
}

test "Exec" {
    var arr = ZodashArray(u8).init(std.testing.allocator);
    defer arr.deinit();

    try arr.list.appendSlice(&[_]u8{ 1, 2, 3, 4, 5, 6 });

    try arr.exec(.{
        .{ .filter = odd },
        .{ .filter = notodd },
    });

    try std.testing.expect(arr.list.items.len == 0);
}
