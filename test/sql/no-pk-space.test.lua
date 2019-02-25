test_run = require('test_run').new()
engine = test_run:get_cfg('engine')
box.sql.execute('pragma sql_default_engine=\''..engine..'\'')

format = {}
format[1] = {'id', 'integer'}
s = box.schema.create_space('test', {format = format})
box.sql.execute("SELECT * FROM \"test\";")
box.sql.execute("INSERT INTO \"test\" VALUES (1);")
box.sql.execute("DELETE FROM \"test\";")
box.sql.execute("UPDATE \"test\" SET id = 3;")

s:drop()

-- Notorious artefact: check of view referencing counter occurs
-- after drop of indexes. So, if space:drop() fails due to being
-- referenced by a view, space becomes unusable in SQL terms.
--
box.sql.execute("CREATE TABLE t1 (id INT PRIMARY KEY);")
box.sql.execute("CREATE VIEW v1 AS SELECT * FROM t1;")
box.space.T1:drop()
box.sql.execute("SELECT * FROM v1;")
box.space.V1:drop()
box.space.T1:drop()