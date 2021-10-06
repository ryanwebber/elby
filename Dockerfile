FROM ruby:2.7.4-alpine
ARG ZIG_VERSION=0.9.0-dev.1276+61a53a587
ARG ZIG_URL=https://ziglang.org/builds/zig-linux-x86_64-${ZIG_VERSION}.tar.xz
ARG ZIG_SHA256=c97c435186b1d0934888922826450fcd808525440b550ef40c5f6a4bf7f613e7
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

CMD ["elby-compile --version"]
