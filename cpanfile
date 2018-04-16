use GSG::Gitc::CPANfile $_environment;

requires 'DBIx::Class';

test_requires 'DBD::SQLite';
test_requires 'DBIx::Class::Core';
test_requires 'DBIx::Class::Schema';

1;
