test_run = require('test_run').new()
engine = test_run:get_cfg('engine')

box.schema.user.grant('guest', 'replication')

-- Test syntax error
box.cfg{replication_synchro_quorum = "aaa"}

-- Test out of bounds values
box.cfg{replication_synchro_quorum = "N+1"}
box.cfg{replication_synchro_quorum = "N-1"}

-- Use canonical majority formula
box.cfg { replication_synchro_quorum = "N/2+1", replication_synchro_timeout = 1000 }
match = 'set \'replication_synchro_quorum\' configuration option to \"N\\/2%+1'
test_run:grep_log("default", match) ~= nil

-- Create a sync space we will operate on
_ = box.schema.space.create('sync', {is_sync = true, engine = engine})
s = box.space.sync
s:format({{name = 'id', type = 'unsigned'}, {name = 'value', type = 'unsigned'}})
_ = s:create_index('primary', {parts = {'id'}})
s:insert{1, 1}

test_run:cmd('create server replica1 with rpl_master=default,\
              script="replication/replica-quorum-1.lua"')
test_run:cmd('start server replica1 with wait=True, wait_load=True')

-- 1 replica -> replication_synchro_quorum = 2/2 + 1 = 2
match = 'update replication_synchro_quorum = 2'
test_run:grep_log("default", match) ~= nil

test_run:cmd('create server replica2 with rpl_master=default,\
              script="replication/replica-quorum-2.lua"')
test_run:cmd('start server replica2 with wait=True, wait_load=True')

-- 2 replicas -> replication_synchro_quorum = 3/2 + 1 = 2
match = 'update replication_synchro_quorum = 2'
test_run:grep_log("default", match) ~= nil

test_run:cmd('create server replica3 with rpl_master=default,\
              script="replication/replica-quorum-3.lua"')
test_run:cmd('start server replica3 with wait=True, wait_load=True')

-- 3 replicas -> replication_synchro_quorum = 4/2 + 1 = 3
match = 'update replication_synchro_quorum = 3'
test_run:grep_log("default", match) ~= nil

test_run:cmd('create server replica4 with rpl_master=default,\
              script="replication/replica-quorum-4.lua"')
test_run:cmd('start server replica4 with wait=True, wait_load=True')

-- 4 replicas -> replication_synchro_quorum = 5/2 + 1 = 3
match = 'update replication_synchro_quorum = 3'
test_run:grep_log("default", match) ~= nil

test_run:cmd('create server replica5 with rpl_master=default,\
              script="replication/replica-quorum-5.lua"')
test_run:cmd('start server replica5 with wait=True, wait_load=True')

test_run:cmd('create server replica6 with rpl_master=default,\
              script="replication/replica-quorum-6.lua"')
test_run:cmd('start server replica6 with wait=True, wait_load=True')

-- 6 replicas -> replication_synchro_quorum = 7/2 + 1 = 4
match = 'update replication_synchro_quorum = 4'
test_run:grep_log("default", match) ~= nil

-- 5 replicas left, the commit should pass
test_run:cmd('stop server replica1')
test_run:cmd('delete server replica1')
s:insert{2, 2}

-- 4 replicas left,the commit should pass
test_run:cmd('stop server replica2')
test_run:cmd('delete server replica2')
s:insert{3, 3}

-- 3 replicas left, the commit should pass
test_run:cmd('stop server replica3')
test_run:cmd('delete server replica3')
s:insert{4, 4}

-- 2 replicas left, the commit should NOT pass
--
-- The replication_synchro_timeout set to a small value to not wait
-- for very long for the case where we know the commit should
-- not pass since replicas are stopped.
box.cfg { replication_synchro_timeout = 0.5 }
test_run:cmd('stop server replica4')
s:insert{5, 5}
-- restore it back and retry
test_run:cmd('start server replica4 with wait=True, wait_load=True')
box.cfg { replication_synchro_timeout = 1000 }
s:insert{5, 5}
test_run:cmd('stop server replica4')
test_run:cmd('delete server replica4')

-- cleanup leftovers

test_run:cmd('stop server replica5')
test_run:cmd('delete server replica5')

test_run:cmd('stop server replica6')
test_run:cmd('delete server replica6')

box.schema.user.revoke('guest', 'replication')
