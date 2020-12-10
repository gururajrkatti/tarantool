test_run = require('test_run').new()

--
-- gh-5435: make sure the new limbo owner commits everything there is left in
-- the limbo from an old owner.
--

SERVERS = {'election_replica1', 'election_replica2', 'election_replica3'}

test_run:create_cluster(SERVERS, "replication", {args='2 0.4'})
test_run:wait_fullmesh(SERVERS)

-- Force election_replica1 to become leader.
test_run:switch('election_replica2')
box.cfg{election_mode='voter'}
test_run:switch('election_replica3')
box.cfg{election_mode='voter'}

test_run:switch('election_replica1')
box.ctl.wait_rw()

_ = box.schema.space.create('test', {is_sync=true})
_ = box.space.test:create_index('pk')

-- Fill the limbo with pending entries. 3 mustn't receive them yet.
test_run:cmd('stop server election_replica3')
box.cfg{replication_synchro_quorum=3}

lsn = box.info.lsn

for i=1,10 do\
    require('fiber').create(function() box.space.test:insert{i} end)\
end

-- Wait for WAL write and replication.
test_run:wait_cond(function() return box.info.lsn == lsn + 10 end)
test_run:wait_lsn('election_replica2', 'election_replica1')

test_run:cmd('switch election_replica2')

test_run:cmd('stop server election_replica1')
-- Since 2 is not the leader yet, 3 doesn't replicate the rows from it.
-- It will vote for 3, however, since 3 has newer data, and start replication
-- once 3 becomes the leader.
test_run:cmd('start server election_replica3 with wait=False, wait_load=False, args="2 0.4 voter 2"')

box.cfg{election_mode='candidate'}
box.ctl.wait_rw()

-- If 2 decided whether to keep the rows or not right on becoming the leader,
-- it would roll them all back. Make sure 2 waits till the rows are replicated
-- to 3.
box.space.test:select{}

test_run:cmd('switch default')
-- To silence the QA warning. The 1st replica is already stopped.
SERVERS[1] = nil
test_run:cmd('delete server election_replica1')
test_run:drop_cluster(SERVERS)

