# Zodash

Zodash is a Zig library inspired by Lodash, providing various functionalities for arrays. Please note that this project is currently in development.

## Usage

Here's a simple example demonstrating the usage of Zodash:

```zig
const std = @import("std");
const ZodashArrayList = @import("zodash").ZodashArrayList;

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
```

## Contributing

Contributions to Zodash are welcome! If you have any ideas, bug fixes, or enhancements, feel free to open an issue or submit a pull request.

## License

Zodash is licensed under the GNU Lesser General Public License v2.1 (LGPL-2.1). See the LICENSE file for details.

## Acknowledgments

I thank Jesus Christ that I have a laptop, time and opportunities to work on this project. And also to everyone who supports or is interested in this project.
