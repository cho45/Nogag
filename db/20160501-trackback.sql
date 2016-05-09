CREATE TABLE trackbacks (
	`id` INTEGER PRIMARY KEY,
	`entry_id` INTEGER,
	`trackback_entry_id` INTEGER
);
CREATE INDEX index_trackbacks_entry_id ON trackbacks (`entry_id`);
CREATE INDEX index_trackbacks_trackback_entry_id ON trackbacks (`trackback_entry_id`);

