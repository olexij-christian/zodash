# Zodash

Zodash is a Zig library inspired by Lodash, providing various functionalities for arrays. Please note that this project is currently in development.

## Usage

Here's a simple example demonstrating the usage of Zodash:

```zig
const std = @import("std");
const ZodashArray = @import("zodash").ZodashArray;

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
```

## Contributing

Contributions to Zodash are welcome! If you have any ideas, bug fixes, or enhancements, feel free to open an issue or submit a pull request.

## License

Zodash is licensed under the GNU Lesser General Public License v2.1 (LGPL-2.1). See the LICENSE file for details.

## Acknowledgments

I thank Jesus Christ that I have a laptop, time and opportunities to work on this project. And also to everyone who supports or is interested in this project.
