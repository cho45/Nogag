
CREATE TABLE cache (
	`cache_key` TEXT NOT NULL PRIMARY KEY,
	`content` BLOB NOT NULL
);

CREATE TABLE cache_relation (
	`id` INTEGER PRIMARY KEY,
	`cache_key` TEXT NOT NULL,
	`source_id` TEXT NOT NULL
);
CREATE INDEX cache_relation_index_cache_key ON cache_relation (`cache_key`);
CREATE INDEX cache_relation_index_source_id ON cache_relation (`source_id`);

CREATE TRIGGER on_cache_deleted AFTER DELETE ON cache BEGIN
	DELETE FROM cache_relation WHERE cache_key = old.cache_key;
END;

CREATE TRIGGER on_cache_related_deleted AFTER DELETE ON cache_relation BEGIN
	DELETE FROM cache WHERE cache_key = old.cache_key;
END;

/*
-- set cache with source_ids
BEGIN;
DELETE FROM cache WHERE cache_key = ?;

INSERT INTO cache (cache_key, content) VALUES (?, ?);
INSERT INTO cache_relation (cache_key, source_id)
	VALUES
		(?, ?, ?, ?),
		(?, ?, ?, ?);

COMMIT;

-- remove cache
BEGIN;
DELETE FROM cache WHERE cache_key = ?;
COMMIT;

-- invalidate_related 
BEGIN;
DELETE FROM cache_relation WHERE source_id = ?;
COMMIT;
*/
