use inc::Module::Install;

name 'Nogag';
all_from 'lib/Nogag.pm';

requires 'Encode' => 2.42;

requires 'Plack';
requires 'Plack::Session';
requires 'Plack::Middleware::ReverseProxy';
requires 'Plack::Middleware::StaticShared';
requires 'Plack::Middleware::Auth::Basic';
requires 'Config::ENV' => 0.10;
requires 'HTTP::Server::Simple::PSGI';
requires 'Data::MessagePack';
requires 'DBD::SQLite';
requires 'Cache::LRU';
requires 'Cache::FileCache';
requires 'Digest::MD5';
requires 'Digest::HMAC_SHA1';
requires 'Text::Overflow';
requires 'HTML::Trim';
requires 'Text::TinySegmenter';
requires 'Time::Piece';
requires 'Time::HiRes';
requires 'Time::Seconds';
requires 'List::Util';
requires 'LWP::UserAgent';
requires 'Text::Xatena';
requires 'URI::Amazon::APA';
requires 'XML::LibXML';
requires 'Data::OpenGraph';
requires 'HTML::Microdata';
requires 'Text::Markdown';
requires 'HTML::Entities';
requires 'SQL::NamedPlaceholder';
requires 'DBIx::TransactionManager';
requires 'JSON::XS';
requires 'Scalar::Util';
requires 'Email::MIME';
requires 'Email::Send';
requires 'HTTP::Message::PSGI';
requires 'HTTP::Message::Common';
requires 'Amazon::PAApi5::Signature';

requires 'Starlet';
requires 'Log::Minimal';

requires 'Router::Simple';
requires 'Try::Tiny';

requires 'Text::Xslate';
requires 'Text::Xslate::Bridge::TT2Like';

# worker
requires 'Module::Find';
requires 'TheSchwartz';
requires 'TheSchwartz::Simple';
requires 'DBIx::DisconnectAll';
requires 'Parallel::Prefork';

test_requires 'Test::WWW::Mechanize::PSGI';

build_requires 'Test::Most';

WriteAll;
