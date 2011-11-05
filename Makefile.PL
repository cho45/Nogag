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

requires 'Router::Simple';

requires 'Text::Xslate';
requires 'Text::Xslate::Bridge::TT2Like';

test_requires 'Test::WWW::Mechanize::PSGI';

build_requires 'Test::Most';

WriteAll;
