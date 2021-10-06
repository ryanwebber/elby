const std = @import("std");
const errors = @import("error.zig");

const maxModuleSize: usize = 1024 * 1024 * 1024; //1gb

pub const ModuleLoadError = error {
    InvalidModuleName,
};

pub const Module = struct {
    identifier: Identifier,
    source: []const u8,

    const Identifier = union(enum) {
        anonymous,
        named: []const u8,
    };

    pub fn name(self: *const Module) []const u8 {
        return switch (self.identifier) {
            .anonymous => "[anonymous module]",
            .named => |name| name,
        };
    }
};

pub const ModuleResolver = struct {
    allocator: *std.mem.Allocator,
    modules: std.StringHashMap(Module),
    dirs: std.StringHashMap([]const u8),

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .modules = std.StringHashMap(Module).init(allocator),
            .dirs = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        var iterator = self.modules.iterator();
        while (iterator.next()) |kvp| {
            self.allocator.free(kvp.value_ptr.source);

            // Key is also the _name_ module identifier
            self.allocator.free(kvp.key_ptr.*);
        }

        var dirIterator = self.dirs.valueIterator();
        while (dirIterator.next()) |dir| {
            self.allocator.free(dir.*);
        }

        self.modules.deinit();
        self.dirs.deinit();
    }

    pub fn resolveRelative(_: *Self, name: []const u8, _: *const Module) !*const Module {
        // TODO:
        //   1. Get relative module dir
        //   2. Append the filename to that dir to create path
        // --
        //   3. Create module name for module
        //   4. Check if module is in cache and return
        //   5. Load off file system
        //   6. Insert new module into cache
        //   7. Insert new module name into dir lookup
        return errors.fatal("Module resolver not implemented (resolving '{s}')", .{ name });
    }

    pub fn resolveAbsolute(self: *Self, name: []const u8) !*const Module {
        const dirname = std.fs.path.dirname(name) orelse {
            return ModuleLoadError.InvalidModuleName;
        };

        const basename = std.fs.path.basename(name);

        return self.resolveInDir(basename, dirname);
    }

    fn resolveInDir(self: *Self, name: []const u8, dir: []const u8) !*const Module {
        const moduleName = try self.toOwnedModuleName(name, dir);
        if (self.modules.getPtr(moduleName)) |mod| {
            return mod;
        }
        const moduleEntry = try self.modules.getOrPut(moduleName);
        if (moduleEntry.found_existing) {
            return moduleEntry.value_ptr;
        }

        const modulePath = try std.fs.path.join(self.allocator, &.{ dir, name });
        defer { self.allocator.free(modulePath); }

        const flags = std.fs.File.OpenFlags {};
        const file = try std.fs.openFileAbsolute(modulePath, flags);
        defer { file.close(); }

        var contents = std.ArrayList(u8).init(self.allocator);
        defer { contents.deinit(); }

        try file.reader().readAllArrayList(&contents, maxModuleSize);
        moduleEntry.value_ptr.* = Module {
            .identifier = .{
                .named = moduleName,
            },
            .source = contents.toOwnedSlice(),
        };

        try self.dirs.put(moduleName, try self.allocator.dupe(u8, dir));
        return moduleEntry.value_ptr;
    }

    fn toOwnedModuleName(self: *Self, name: []const u8, dir: []const u8) ![]const u8 {
        var buffer = std.ArrayList(u8).init(self.allocator);
        defer { buffer.deinit(); }

        try buffer.writer().print("{s}_{s}", .{ dir, name });

        return buffer.toOwnedSlice();
    }

    fn resolveCached(self: *Self, name: []const u8) ?*const Module {
        return self.modules.getPtr(name);
    }
};
