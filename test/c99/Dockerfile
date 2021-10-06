ARG BASE=elby/base

FROM ${BASE}
COPY Gemfile .
ENV GEM_HOME="/usr/local/bundle"
ENV PATH $GEM_HOME/bin:$GEM_HOME/gems/bin:$PATH
RUN gem install bundler
RUN bundle install
RUN which ruby

FROM ${BASE}
RUN apk add --update --no-cache make
WORKDIR /test
COPY Makefile .
COPY tests tests
COPY utils utils
CMD make test
