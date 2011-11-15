CREATE TABLE entries (
	`id` INTEGER PRIMARY KEY,
	`title` TEXT NOT NULL,
	`body` TEXT NOT NULL,
	`formatted_body` TEXT NOT NULL,
	`path` TEXT NOT NULL,
	`format` TEXT NOT NULL,
	`sort_time` DATETIME NOT NULL,
	`created_at` DATETIME NOT NULL,
	`modified_at` DATETIME NOT NULL
);
CREATE INDEX index_sort_time ON entries (sort_time);

CREATE TABLE options (
	`id` INTEGER PRIMARY KEY,
	`key` TEXT,
	`value` BLOB
);
CREATE INDEX index_key ON options (`key`);
