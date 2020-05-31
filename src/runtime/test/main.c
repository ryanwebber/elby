#include <stdio.h>

#include <elby/runtime/runtime.h>

int main() {

    const char *source = "let a = (add 2 5)";

    elby_runtime *runtime = elby_new();
    elby_load(runtime, source);
    elby_call(runtime, 0);
    elby_close(runtime);
}
