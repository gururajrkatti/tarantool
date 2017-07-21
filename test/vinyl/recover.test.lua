test_run = require('test_run').new()

-- Temporary table to restore variables after restart.
var = box.schema.space.create('var')
_ = var:create_index('primary', {parts = {1, 'string'}})

-- Empty space.
s1 = box.schema.space.create('test1', {engine = 'vinyl'})
_ = s1:create_index('pk')

-- Truncated space.
s2 = box.schema.space.create('test2', {engine = 'vinyl'})
_ = s2:create_index('pk')
_ = s2:insert{123}
s2:truncate()

-- Data space.
s3 = box.schema.space.create('test3', {engine='vinyl'})
_ = s3:create_index('primary')
_ = s3:create_index('secondary', {unique = false, parts = {2, 'string'}})
for i = 0, 4 do s3:insert{i, 'test' .. i} end

-- Flush data to disk.
box.snapshot()

-- Write some data to memory.
for i = 5, 9 do s3:insert{i, 'test' .. i} end

-- Remember stats before restarting the server.
_ = var:insert{'vyinfo', s3.index.primary:info()}

test_run:cmd('restart server default')

s1 = box.space.test1
s2 = box.space.test2
s3 = box.space.test3
var = box.space.var

-- Check space contents.
s1:select()
s2:select()
s3.index.primary:select()
s3.index.secondary:select()

-- Check that stats didn't change after recovery.
vyinfo1 = var:get('vyinfo')[2]
vyinfo2 = s3.index.primary:info()

vyinfo1.memory.rows == vyinfo2.memory.rows
vyinfo1.memory.bytes == vyinfo2.memory.bytes
vyinfo1.disk.rows == vyinfo2.disk.rows
vyinfo1.disk.bytes == vyinfo2.disk.bytes
vyinfo1.disk.bytes_compressed == vyinfo2.disk.bytes_compressed
vyinfo1.disk.pages == vyinfo2.disk.pages
vyinfo1.run_count == vyinfo2.run_count
vyinfo1.range_count == vyinfo2.range_count

s1:drop()
s2:drop()
s3:drop()
var:drop()
