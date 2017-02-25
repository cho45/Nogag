CREATE TABLE oauth_client (
	`client_id` VARCHAR PRIMARY KEY,
	`access_token` VARCHAR NOT NULL,
	`refresh_token` VARCHAR NOT NULL,
	`expire` INTEGER NOT NULL
);
