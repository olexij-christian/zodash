const std = @import("std");

pub fn ZodashArrayList(comptime T: type) type {
    return struct {
        arraylist: std.ArrayList(T),
        allocator: std.mem.Allocator,

        const ZAType = @This();

        pub fn init(alloc: std.mem.Allocator) @This() {
            return @This(){
                .allocator = alloc,
                .arraylist = std.ArrayList(T).init(alloc),
            };
        }

        pub fn deinit(arr: *@This()) void {
            arr.arraylist.deinit();
        }

        pub fn clone(this: @This()) !@This() {
            const res = @This(){
                .allocator = this.allocator,
                .arraylist = try this.arraylist.clone(),
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
                    return @This(){ .index = 0, .arr = zarr.arraylist.items };
                }
            };
        }

        // NOTE: IT - InputType, OT - OutputType
        pub fn MapIterator(comptime IT: type, comptime OT: type, comptime changer: fn (IT) OT) type {
            return struct {
                index: usize,
                arr: []const IT,

                fn next(this: *@This()) ?OT {
                    while (this.index < this.arr.len) {
                        defer this.index += 1;
                        return changer(this.arr[this.index]);
                    }
                    return null;
                }

                fn init(zarr: ZAType) @This() {
                    return @This(){ .index = 0, .arr = zarr.arraylist.items };
                }
            };
        }

        pub fn cloneMap(zarr: @This(), comptime changer: anytype) !ZodashArrayList(@typeInfo(@TypeOf(changer)).Fn.return_type orelse void) {
            const ResultType = @typeInfo(@TypeOf(changer)).Fn.return_type orelse void;
            var new_zarr = ZodashArrayList(ResultType).init(zarr.allocator);
            var iterator = MapIterator(T, ResultType, changer).init(zarr);

            while (iterator.next()) |item|
                try new_zarr.arraylist.append(item);

            return new_zarr;
        }

        pub fn map(zarr: *@This(), comptime changer: fn (T) T) !void {
            var new_arr = std.ArrayList(T).init(zarr.allocator);
            var iterator = MapIterator(T, T, changer).init(zarr.*);

            while (iterator.next()) |item|
                try new_arr.append(item);

            zarr.arraylist.deinit();
            zarr.arraylist = new_arr;
        }

        pub fn filter(zarr: *@This(), comptime condition: fn (T) ?T) !void {
            var new_arr = std.ArrayList(T).init(zarr.allocator);
            var iterator = FilterIterator(condition).init(zarr.*);

            while (iterator.next()) |item|
                try new_arr.append(item);

            zarr.arraylist.deinit();
            zarr.arraylist = new_arr;
        }

        const DefaultStages = union(enum) {
            filter: fn (T) ?T,
            map: fn (T) T,
        };

        pub fn exec(this: *@This(), comptime stages: anytype) !void {
            inline for (stages) |stg| {
                const switchable = @as(DefaultStages, stg);
                switch (switchable) {
                    .filter => |func| try this.filter(func),
                    .map => |func| try this.map(func),
                }
            }
        }

        pub fn ExecIterator(comptime stages: anytype) type {
            return struct {
                index: usize,
                arr: []const T,

                const last_stage = stages[stages.len - 1];
                const unpacked_last_stage = switch (@as(DefaultStages, last_stage)) {
                    .filter => |func| func,
                    .map => |func| func,
                };
                const last_stage_return_type = @typeInfo(@TypeOf(unpacked_last_stage)).Fn.return_type orelse void;

                const ResultType = switch (@typeInfo(last_stage_return_type)) {
                    .Optional => |opt| opt.child,
                    else => last_stage_return_type,
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
                        .map => |fnc| fnc,
                    };
                    const is_last_iteration = index + 1 == stages.len;
                    const new_value = func(value);
                    if (is_last_iteration)
                        return new_value
                    else if (new_value == null)
                        return null
                    else
                        return nextFunc(new_value.?, index + 1);
                }

                fn init(zarr: ZAType) @This() {
                    return @This(){ .index = 0, .arr = zarr.arraylist.items };
                }
            };
        }
    };
}

fn is_even(num: u8) ?u8 {
    if (num % 2 == 0)
        return num
    else
        return null;
}

fn is_odd(num: u8) ?u8 {
    if (num % 2 != 0)
        return num
    else
        return null;
}

test "Filter" {
    var arr = ZodashArrayList(u8).init(std.testing.allocator);
    defer arr.deinit();

    try arr.arraylist.appendSlice(&[_]u8{ 1, 2, 3, 4, 5, 6 });

    try arr.filter(is_even);

    try std.testing.expectEqualSlices(u8, arr.arraylist.items, &[_]u8{ 2, 4, 6 });
}

test "FilterIterator" {
    var arr = ZodashArrayList(u8).init(std.testing.allocator);
    defer arr.deinit();

    try arr.arraylist.appendSlice(&[_]u8{ 1, 2, 3, 4, 5, 6 });

    var iterator = ZodashArrayList(u8).FilterIterator(is_even).init(arr);

    try std.testing.expectEqual(iterator.next().?, 2);
    try std.testing.expectEqual(iterator.next().?, 4);
    try std.testing.expectEqual(iterator.next().?, 6);
    try std.testing.expectEqual(iterator.next(), null);
    try std.testing.expectEqual(iterator.next(), null);
}

fn addOne(num: u8) u8 {
    return num + 1;
}

test "Map" {
    var arr = ZodashArrayList(u8).init(std.testing.allocator);
    defer arr.deinit();

    try arr.arraylist.appendSlice(&[_]u8{ 1, 2, 3, 4, 5, 6 });

    try arr.map(addOne);

    try std.testing.expectEqualSlices(u8, arr.arraylist.items, &[_]u8{ 2, 3, 4, 5, 6, 7 });
}

test "MapIterator 1" {
    var arr = ZodashArrayList(u8).init(std.testing.allocator);
    defer arr.deinit();

    try arr.arraylist.appendSlice(&[_]u8{ 1, 2, 3 });

    var iterator = ZodashArrayList(u8).MapIterator(u8, u8, addOne).init(arr);

    try std.testing.expectEqual(iterator.next().?, 2);
    try std.testing.expectEqual(iterator.next().?, 3);
    try std.testing.expectEqual(iterator.next().?, 4);
    try std.testing.expectEqual(iterator.next(), null);
    try std.testing.expectEqual(iterator.next(), null);
}

fn asU16(num: u8) u16 {
    return @as(u16, num);
}

test "CloneMap" {
    var arr = ZodashArrayList(u8).init(std.testing.allocator);
    defer arr.deinit();

    try arr.arraylist.appendSlice(&[_]u8{ 1, 2, 3, 4, 5, 6 });

    var new_arr = try arr.cloneMap(asU16);
    defer new_arr.deinit();

    try std.testing.expectEqualSlices(u16, new_arr.arraylist.items, &[_]u16{ 1, 2, 3, 4, 5, 6 });
}

test "MapIterator 2" {
    var arr = ZodashArrayList(u8).init(std.testing.allocator);
    defer arr.deinit();

    try arr.arraylist.appendSlice(&[_]u8{ 1, 2, 3 });

    var iterator = ZodashArrayList(u8).MapIterator(u8, u16, asU16).init(arr);

    try std.testing.expectEqual(iterator.next().?, @as(u16, 1));
    try std.testing.expectEqual(iterator.next().?, @as(u16, 2));
    try std.testing.expectEqual(iterator.next().?, @as(u16, 3));
    try std.testing.expectEqual(iterator.next(), @as(?u16, null));
    try std.testing.expectEqual(iterator.next(), null);
}

test "Clone" {
    var arr = ZodashArrayList(u8).init(std.testing.allocator);
    defer arr.deinit();

    try arr.arraylist.appendSlice(&[_]u8{ 1, 2, 3, 4, 5, 6 });

    var clone = try arr.clone();
    defer clone.deinit();

    try clone.filter(is_even);

    try std.testing.expect(!std.mem.eql(u8, clone.arraylist.items, arr.arraylist.items));
}

test "Exec" {
    var arr = ZodashArrayList(u8).init(std.testing.allocator);
    defer arr.deinit();

    try arr.arraylist.appendSlice(&[_]u8{ 1, 2, 3, 4, 5, 6 });

    try arr.exec(.{
        .{ .filter = is_even },
        .{ .filter = is_odd },
    });

    try std.testing.expect(arr.arraylist.items.len == 0);
}

test "ExecIterator 1 Filter" {
    var arr = ZodashArrayList(u8).init(std.testing.allocator);
    defer arr.deinit();

    try arr.arraylist.appendSlice(&[_]u8{ 1, 2, 3, 4, 5, 6 });

    var iterator = ZodashArrayList(u8).ExecIterator(.{
        .{ .filter = is_even },
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
    var arr = ZodashArrayList(u8).init(std.testing.allocator);
    defer arr.deinit();

    try arr.arraylist.appendSlice(&[_]u8{ 1, 2, 3, 4, 5, 6 });

    var iterator = ZodashArrayList(u8).ExecIterator(.{
        .{ .filter = is_even },
        .{ .filter = filter_four },
    }).init(arr);

    try std.testing.expectEqual(iterator.next(), 2);
    try std.testing.expectEqual(iterator.next(), 6);
    try std.testing.expectEqual(iterator.next(), null);
    try std.testing.expectEqual(iterator.next(), null);
}