#ifndef ELBY_RUNTIME_H
#define ELBY_RUNTIME_H

struct elby_runtime;

enum elby_error {
    ELBY_ERROR_UNKNOWN = 1,
    ELBY_ERROR_SYNTAX
};

typedef struct Runtime elby_runtime;
typedef enum elby_error elby_error;

elby_runtime *elby_new();
void elby_close(elby_runtime *runtime);

void elby_load(elby_runtime *runtime, const char *source);
elby_error elby_call(elby_runtime *runtime, size_t nargs);

#endif //ELBY_RUNTIME_H
