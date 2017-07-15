
CREATE TABLE images (
	`id` INTEGER PRIMARY KEY,
	`uri` TEXT NOT NULL,
	`entry_id` INTEGER NOT NULL,
	`sig` BLOB NOT NULL
);
CREATE UNIQUE INDEX index_images_uri ON images (`uri`, `entry_id`);

CREATE TABLE ngram (
	image_id INTEGER NOT NULL,
	word BLOB NOT NULL,
	PRIMARY KEY (`image_id`, `word`)
) WITHOUT ROWID;
CREATE INDEX index_word_image_id ON ngram (`word`, `image_id`);
