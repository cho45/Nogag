
CREATE TABLE tfidf (
	`id` INTEGER PRIMARY KEY,
	`term` TEXT NOT NULL,
	`entry_id` INTEGER NOT NULL,
	`term_count` INTEGER NOT NULL DEFAULT 0,
	`tfidf` FLOAT NOT NULL DEFAULT 0,
	`tfidf_n` FLOAT NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX index_tf_term ON tfidf (`term`, `entry_id`);
CREATE INDEX index_tf_entry_id ON tfidf (`entry_id`);

-- スコアが一定以上の計算結果を保存する
CREATE TABLE related_entries (
	`id` INTEGER PRIMARY KEY,
	`entry_id` INTEGER NOT NULL,
	`related_entry_id` INTEGER NOT NULL,
	`score` FLOAT NOT NULL
);
CREATE INDEX index_related_entries_entry_id_score ON related_entries (`entry_id`, `score`);
CREATE INDEX index_related_entries_related_entry_id ON related_entries (`related_entry_id`);

/*
# エントリ追加時

エントリ本文をtermに分割し、各termに対し

INSERT OR IGNORE INTO term (`term`) VALUES (?);
UPDATE term SET entry_count = entry_count + 1;

を実行。これは document frequency となる。

さらにドキュメントの各termとその出現数に対し

REPLACE INTO tf (`term_id`, `entry_id`, `term_count`) VALUES (?, ?, ?);

を実行。これは term frequency となる。

# tfidf の計算

全文書をとりこんでから tfidf カラムを更新する


# インクリメンタルエントリ追加

「エントリ追加」したあと、含まれたtermを含む他のエントリについて全てtfidf計算をしなおす
(idfが更新されるので、idfに関係するエントリを更新する)

# 類似計算
cos 類似をとる
http://www.slideshare.net/y-uti/document-recommendation


*/

