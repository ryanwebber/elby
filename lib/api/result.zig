
pub fn Result(comptime Ok: type, comptime Fail: type) type {
    return union(enum) {
        ok: Ok,
        fail: Fail
    };
}
