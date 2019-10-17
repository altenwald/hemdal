#!/bin/bash

ERLANG_VSN=22.0
ELIXIR_VSN=1.8.2
PROJECT=hemdal

docker run -it --rm \
           -v $(pwd):/${PROJECT} \
           -w /${PROJECT} \
           altenwald/phoenix:otp${ERLANG_VSN}_ex${ELIXIR_VSN} ./build_package.sh
