#!/bin/bash

export MIX_ENV=prod

mix local.hex --force
mix do deps.get, compile
cd assets
npm i
node node_modules/webpack/bin/webpack.js --mode production
cd ..
mix do phx.digest, release --upgrade --env=prod
