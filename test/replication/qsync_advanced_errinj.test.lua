env = require('test_run')
test_run = env.new()
engine = test_run:get_cfg('engine')
fiber = require('fiber')

orig_synchro_quorum = box.cfg.replication_synchro_quorum
orig_synchro_timeout = box.cfg.replication_synchro_timeout
orig_replication_timeout = box.cfg.replication_timeout

NUM_INSTANCES = 2
BROKEN_QUORUM = NUM_INSTANCES + 1

test_run:cmd("setopt delimiter ';'")
disable_sync_mode = function()
    local s = box.space._space:get(box.space.sync.id)
    local new_s = s:update({{'=', 6, {is_sync=false}}})
    box.space._space:replace(new_s)
end;
test_run:cmd("setopt delimiter ''");

box.schema.user.grant('guest', 'replication')

-- Setup an cluster with two instances.
test_run:cmd('create server replica with rpl_master=default,\
                                         script="replication/replica.lua"')
test_run:cmd('start server replica with wait=True, wait_load=True')

-- Check behaviour with failed write to WAL on master.
-- Testcase setup.
test_run:switch('default')
box.cfg{replication_synchro_quorum=NUM_INSTANCES, replication_synchro_timeout=0.1}
_ = box.schema.space.create('sync', {is_sync=true, engine=engine})
_ = box.space.sync:create_index('pk')
-- Testcase body.
box.space.sync:insert{1}
box.space.sync:select{} -- 1
box.error.injection.set('ERRINJ_WAL_IO', true)
box.space.sync:insert{2}
box.error.injection.set('ERRINJ_WAL_IO', false)
box.space.sync:select{} -- 1
test_run:switch('replica')
box.space.sync:select{} -- 1
-- Testcase cleanup.
test_run:switch('default')
box.space.sync:drop()

-- (WIP) [RFC, connection liveness] When Leader has no response for another heartbeat
-- interval, it should consider the replica is lost.
test_run:switch('default')
box.cfg{replication_synchro_quorum=NUM_INSTANCES, replication_synchro_timeout=1}
_ = box.schema.space.create('sync', {is_sync=true, engine=engine})
_ = box.space.sync:create_index('pk')
-- Testcase body.
box.space.sync:insert{1}
box.space.sync:select{} -- 1
-- Disable heartbeat messages on the replica.
test_run:cmd('switch replica')
box.error.injection.set("ERRINJ_RELAY_REPORT_INTERVAL", 2)
-- Leader should consider the replica is lost.
test_run:cmd("switch default")
box.cfg{replication_timeout = 0.05}
test_run:wait_cond(function() return box.info.replication[2].downstream.status == 'stopped' end, 10)
-- Testcase cleanup.
test_run:cmd("switch replica")
box.error.injection.set("ERRINJ_RELAY_REPORT_INTERVAL", 0)
test_run:switch('default')
box.cfg{replication_timeout = orig_replication_timeout}
box.space.sync:drop()

-- [RFC, quorum commit] check behaviour with failure answer from a replica
-- during write, expected disconnect from the replication
-- (gh-5123, set replication_synchro_quorum to 1).
-- Testcase setup.
test_run:switch('default')
box.cfg{replication_synchro_quorum=NUM_INSTANCES, replication_synchro_timeout=0.1}
_ = box.schema.space.create('sync', {is_sync=true, engine=engine})
_ = box.space.sync:create_index('pk')
-- Testcase body.
box.space.sync:insert{1}
box.space.sync:select{} -- 1
test_run:switch('replica')
box.error.injection.set('ERRINJ_WAL_IO', true)
test_run:switch('default')
box.space.sync:insert{2}
test_run:switch('replica')
box.error.injection.set('ERRINJ_WAL_IO', false)
box.space.sync:select{} -- 1
-- Testcase cleanup.
test_run:switch('default')
box.space.sync:drop()

-- Teardown.
test_run:cmd('switch default')
test_run:cmd('stop server replica')
test_run:cmd('delete server replica')
test_run:cleanup_cluster()
box.schema.user.revoke('guest', 'replication')
box.cfg{                                                                        \
    replication_synchro_quorum = orig_synchro_quorum,                           \
    replication_synchro_timeout = orig_synchro_timeout,                         \
}
