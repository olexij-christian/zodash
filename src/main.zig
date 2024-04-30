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

        pub fn FilterIterator(comptime condition: fn (T) ?T) type {
            return struct {
                index: usize,
                arr: []const T,

                fn next(this: *@This()) ?T {
                    while (this.index < this.arr.len) {
                        defer this.index += 1;
                        const item = this.arr[this.index];
                        if (condition(item)) |item_unpacked|
                            return item_unpacked;
                    }
                    return null;
                }

                fn init(zarr: ZAType) @This() {
                    return @This(){ .index = 0, .arr = zarr.list.items };
                }
            };
        }

        pub fn filter(zarr: *@This(), comptime condition: fn (T) ?T) !void {
            var new_arr = std.ArrayList(T).init(zarr.allocator);
            var iterator = FilterIterator(condition).init(zarr.*);

            while (iterator.next()) |item|
                try new_arr.append(item);

            zarr.list.deinit();
            zarr.list = new_arr;
        }

        const DefaultStages = union(enum) {
            filter: fn (T) ?T,
        };

        pub fn exec(this: *@This(), comptime stages: anytype) !void {
            inline for (stages) |stg| {
                const switchable = @as(DefaultStages, stg);
                switch (switchable) {
                    .filter => |func| try this.filter(func),
                }
            }
        }

        pub fn ExecIterator(comptime stages: anytype) type {
            return struct {
                index: usize,
                arr: []const T,

                const LastStage = stages[stages.len - 1];
                const UnpackedStage = switch (@as(DefaultStages, LastStage)) {
                    .filter => |func| func,
                };
                const LastStageReturnType = @typeInfo(@TypeOf(UnpackedStage)).Fn.return_type orelse void;
                const ResultType = switch (@typeInfo(LastStageReturnType)) {
                    .Optional => |opt| opt.child,
                    else => LastStageReturnType,
                };

                fn next(this: *@This()) ?ResultType {
                    while (this.index < this.arr.len) {
                        defer this.index += 1;
                        const item = this.arr[this.index];
                        const new_item = nextFunc(item, 0);
                        if (new_item != null)
                            return new_item;
                    }
                    return null;
                }

                fn nextFunc(value: anytype, comptime index: comptime_int) ?ResultType {
                    const func = switch (@as(DefaultStages, stages[index])) {
                        .filter => |fnc| fnc,
                    };
                    const is_last_iteration = index + 1 == stages.len;
                    var new_value = func(value);
                    if (is_last_iteration)
                        return new_value
                    else if (new_value == null)
                        return null
                    else
                        return nextFunc(new_value.?, index + 1);
                }

                fn init(zarr: ZAType) @This() {
                    return @This(){ .index = 0, .arr = zarr.list.items };
                }
            };
        }
    };
}

fn odd(num: u8) ?u8 {
    if (num % 2 == 0)
        return num
    else
        return null;
}

fn notodd(num: u8) ?u8 {
    if (num % 2 != 0)
        return num
    else
        return null;
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

test "ExecIterator 1 Filter" {
    var arr = ZodashArray(u8).init(std.testing.allocator);
    defer arr.deinit();

    try arr.list.appendSlice(&[_]u8{ 1, 2, 3, 4, 5, 6 });

    var iterator = ZodashArray(u8).ExecIterator(.{
        .{ .filter = odd },
    }).init(arr);

    try std.testing.expectEqual(iterator.next().?, 2);
    try std.testing.expectEqual(iterator.next().?, 4);
    try std.testing.expectEqual(iterator.next().?, 6);
    try std.testing.expectEqual(iterator.next(), null);
    try std.testing.expectEqual(iterator.next(), null);
}

fn filter_four(num: u8) ?u8 {
    if (num == 4)
        return null
    else
        return num;
}

test "ExecIterator 2 Filters" {
    var arr = ZodashArray(u8).init(std.testing.allocator);
    defer arr.deinit();

    try arr.list.appendSlice(&[_]u8{ 1, 2, 3, 4, 5, 6 });

    var iterator = ZodashArray(u8).ExecIterator(.{
        .{ .filter = odd },
        .{ .filter = filter_four },
    }).init(arr);

    try std.testing.expectEqual(iterator.next(), 2);
    try std.testing.expectEqual(iterator.next(), 6);
    try std.testing.expectEqual(iterator.next(), null);
    try std.testing.expectEqual(iterator.next(), null);
}
