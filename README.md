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

test "Filtering even numbers" {
    const input = &[_]u8{1, 2, 3, 4, 5, 6};
    const expected = &[_]u8{ 2, 4, 6 };
    var allocator = std.testing.allocator;

    // Initialize ZodashArray and append elements
    var arr = ZodashArray(u8).init(allocator);
    try arr.list.appendSlice(input);

    // Filter the array and compare with expected output
    var filtered = arr.filter(odd);
    defer filtered.deinit();

    const actual = filtered.list.items;
    try std.testing.expectEqualSlices(u8, actual, expected);
}
```

## Contributing

Contributions to Zodash are welcome! If you have any ideas, bug fixes, or enhancements, feel free to open an issue or submit a pull request.

## License

Zodash is licensed under the GNU Lesser General Public License v2.1 (LGPL-2.1). See the LICENSE file for details.

## Acknowledgments

I thank Jesus Christ that I have a laptop, time and opportunities to work on this project. And also to everyone who supports or is interested in this project.
