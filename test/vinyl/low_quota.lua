#!/usr/bin/env tarantool

local LIMIT = string.match(arg[0], "%d")

box.cfg{
    vinyl_memory = LIMIT * 1024 * 1024,
}

require('console').listen(os.getenv('ADMIN'))
