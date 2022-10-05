FROM ruby:2.7.4-alpine
ARG ZIG_URL=https://ziglang.org/download/0.9.1/zig-linux-x86_64-0.9.1.tar.xz
ARG ZIG_SHA256=be8da632c1d3273f766b69244d80669fe4f5e27798654681d77c992f17c237d7
WORKDIR /tmp
RUN wget -q $ZIG_URL -O zig.tar.xz \
    && echo "$ZIG_SHA256  zig.tar.xz" | sha256sum -c \
    && mkdir /zig && tar -C /zig -xvf zig.tar.xz --strip 1
ENV PATH="/zig:${PATH}"
WORKDIR /elby-root
COPY src src
COPY lib lib
COPY build.zig .
RUN zig build test
RUN zig build install --prefix-exe-dir /usr/local/bin
ENV PATH="/usr/local/bin:${PATH}"

CMD ["elby-compile", "--version"]
