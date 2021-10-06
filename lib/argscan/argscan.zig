const std = @import("std");

pub const Option = struct {
    name: []const u8,
    description: []const u8,
    forms: []const []const u8,
    default: bool = false,
};

pub const Argument = struct {
    name: []const u8,
    description: []const u8,
    parameterHint: []const u8,
    forms: []const []const u8,
    default: []const u8 = "",
};

pub const Format = struct {
    usages: []const []const u8,
    description: []const u8,
    options: []const Option,
    arguments: []const Argument,
};

pub const StandardHints = struct {
    pub const file = "[file]";
    pub const directory = "[dir]";
};

pub const StandardOptions = struct {
    pub const showHelp: Option = .{
        .name = "showHelp",
        .description = "Print this message and exit.",
        .forms = &.{ "-h", "--help" },
    };

    pub const showVersion: Option = .{
        .name = "showVersion",
        .description = "Print the current version and exit.",
        .forms = &.{ "-v", "--version" },
    };
};

pub fn Parser(comptime format: *const Format) type {

    const OptionsType = OptionsConfiguration(format.options);
    const ArgumentsType = ArgumentsConfiguration(format.arguments);

    const Configuration = struct {
        _arena: std.heap.ArenaAllocator,
        result: union(enum) {
            ok: Success,
            fail: union(enum) {
                unexpectedOption: []const u8,
                unexpectedTermination: []const u8,

                const Failure = @This();

                pub fn format(self: *const Failure, writer: anytype) !void {
                    switch (self.*) {
                        .unexpectedOption => |opt| {
                            try writer.print("[Error] Unexpected option: '{s}'.", .{ opt });
                        },
                        .unexpectedTermination => |opt| {
                            try writer.print("[Error] Expected value for option: '{s}''.", .{ opt });
                        },
                    }
                }
            },
        },

        const Self = @This();

        pub const Success = struct {
            options: OptionsType,
            arguments: ArgumentsType,
            unparsedArguments: []const []const u8,
        };

        pub fn deinit(self: *const Self) void {
            self._arena.deinit();
        }
    };

    return struct {

        pub const Parse = Configuration;
        pub const helpText = generateHelpText(format);

        pub fn parse(allocator: *std.mem.Allocator, args: [][:0]const u8) !Configuration {
            var arena = std.heap.ArenaAllocator.init(allocator);
            errdefer { arena.deinit(); }

            var options: OptionsType = .{};
            var arguments: ArgumentsType = .{};

            var unparsed = std.ArrayList([]const u8).init(&arena.allocator);

            var i: usize = 0;
            nextArg: while (i < args.len) {
                const arg = args[i];

                // Check options
                inline for (format.options) |opt| {
                    inline for (opt.forms) |form| {
                        if (std.mem.eql(u8, form, arg)) {
                            @field(options, opt.name) = !opt.default;
                            i += 1;
                            continue :nextArg;
                        }
                    }
                }

                // Check arguments
                var foundArg = false;
                inline for (format.arguments) |argument| {
                    inline for (argument.forms) |form| {
                        if (std.mem.eql(u8, form, arg)) {
                            if (i < args.len - 1) {
                                const valueClone = try arena.allocator.dupe(u8, args[i + 1]);
                                @field(arguments, argument.name) = valueClone;
                                foundArg = true;
                            }

                            if (i >= args.len - 1) { // Another zig compiler bug :(
                                return Configuration {
                                    ._arena = arena,
                                    .result = .{
                                        .fail = .{
                                            .unexpectedTermination = arg,
                                        }
                                    }
                                };
                            }
                        }
                    }
                }

                if (foundArg) {
                    i += 2;
                } else if (arg.len > 1 and arg[0] == '-') {
                    return Configuration {
                        ._arena = arena,
                        .result = .{
                            .fail = .{
                                .unexpectedOption = arg,
                            }
                        }
                    };
                } else {
                    const argClone = try arena.allocator.dupe(u8, arg);
                    try unparsed.append(argClone);
                    i += 1;
                }
            }

            return Configuration {
                ._arena = arena,
                .result = .{
                    .ok = .{
                        .options = options,
                        .arguments = arguments,
                        .unparsedArguments = unparsed.toOwnedSlice(),
                    }
                }
            };
        }
    };
}

fn OptionsConfiguration(comptime options: []const Option) type {
    const num_option_fields = options.len;
    var option_fields: [num_option_fields]std.builtin.TypeInfo.StructField = undefined;
    inline for (options) |option, idx| {
        option_fields[idx] = .{
            .name = option.name,
            .alignment = 0,
            .is_comptime = false,
            .field_type = bool,
            .default_value = option.default,
        };
    }

    return @Type(.{
        .Struct = .{
            .layout = .Auto,
            .fields = &option_fields,
            .decls = &[_]std.builtin.TypeInfo.Declaration{},
            .is_tuple = false,
        }
    });
}

fn ArgumentsConfiguration(comptime arguments: []const Argument) type {
    const num_arg_fields = arguments.len;
    var arg_fields: [num_arg_fields]std.builtin.TypeInfo.StructField = undefined;
    inline for (arguments) |arg, idx| {
        arg_fields[idx] = .{
            .name = arg.name,
            .alignment = 0,
            .is_comptime = false,
            .field_type = []const u8,
            .default_value = arg.default,
        };
    }

    return @Type(.{
        .Struct = .{
            .layout = .Auto,
            .fields = &arg_fields,
            .decls = &[_]std.builtin.TypeInfo.Declaration{},
            .is_tuple = false,
        }
    });
}

fn generateHelpText(comptime format: *const Format) []const u8 {
    var helpText: []const u8 = "Usage:\n";
    inline for (format.usages) |usage| {
        helpText = std.fmt.comptimePrint("{s}  {s}\n", .{ helpText, usage });
    }

    helpText = std.fmt.comptimePrint("{s}\n\nOverview: {s}\n\nOptions:\n\n", .{ helpText, format.description });

    const descriptionOffset = 28; // This could be determined better

    inline for (format.options) |option| {
        const startOffset = helpText.len;
        helpText = std.fmt.comptimePrint("{s}  ", .{ helpText });
        for (option.forms) |form, i| {
            helpText = std.fmt.comptimePrint("{s}{s}", .{ helpText, form });
            if (i < option.forms.len - 1) {
                helpText = std.fmt.comptimePrint("{s},", .{ helpText });
            }
        }

        const endOffset = helpText.len;
        const bufferLen = descriptionOffset - (endOffset - startOffset);
        if (bufferLen > 0) {
            helpText = std.fmt.comptimePrint("{s}{s}", .{ helpText, " " ** bufferLen });
        }

        helpText = std.fmt.comptimePrint("{s}{s}\n", .{ helpText, option.description });
    }

    inline for (format.arguments) |arg| {
        const startOffset = helpText.len;
        helpText = std.fmt.comptimePrint("{s}  ", .{ helpText });
        for (arg.forms) |form, i| {
            helpText = std.fmt.comptimePrint("{s}{s}", .{ helpText, form });
            if (i < arg.forms.len - 1) {
                helpText = std.fmt.comptimePrint("{s},", .{ helpText });
            }
        }

        helpText = std.fmt.comptimePrint("{s} {s}", .{ helpText, arg.parameterHint });

        const endOffset = helpText.len;
        const bufferLen = descriptionOffset - (endOffset - startOffset);
        if (bufferLen > 0) {
            helpText = std.fmt.comptimePrint("{s}{s}", .{ helpText, " " ** bufferLen });
        }

        helpText = std.fmt.comptimePrint("{s}{s}\n", .{ helpText, arg.description });
    }

    return helpText;
}
