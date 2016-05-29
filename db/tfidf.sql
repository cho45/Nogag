
CREATE TABLE tfidf (
	`id` INTEGER PRIMARY KEY,
	`term` TEXT NOT NULL,
	`entry_id` INTEGER NOT NULL,
	`term_count` INTEGER NOT NULL DEFAULT 0, -- エントリ内でのターム出現回数
	`tfidf` FLOAT NOT NULL DEFAULT 0, -- 正規化前の TF-IDF
	`tfidf_n` FLOAT NOT NULL DEFAULT 0 -- ベクトル正規化した TF-IDF
);
CREATE UNIQUE INDEX index_tf_term ON tfidf (`term`, `entry_id`);
CREATE INDEX index_tf_entry_id_tfidf_n ON tfidf (`entry_id`, `tfidf_n`);

-- スコアが一定以上の計算結果を保存する
CREATE TABLE related_entries (
	`id` INTEGER PRIMARY KEY,
	`entry_id` INTEGER NOT NULL,
	`related_entry_id` INTEGER NOT NULL,
	`score` FLOAT NOT NULL
);
CREATE INDEX index_related_entries_entry_id_score ON related_entries (`entry_id`, `score`);
CREATE INDEX index_related_entries_related_entry_id ON related_entries (`related_entry_id`);

