use GSG::Gitc::CPANfile $_environment;

requires 'DBIx::Class';
requires 'DateTime';

test_requires 'DBD::SQLite';
test_requires 'DBIx::Class::Core';
test_requires 'DBIx::Class::Schema';

test_requires 'JSON::PP';
test_requires 'Test::Mock::Time';
test_requires 'DateTime::Format::SQLite';

1;
