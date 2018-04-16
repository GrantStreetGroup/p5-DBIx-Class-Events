use strict;
use warnings;
use Test::More;

use DBIx::Class::Events;

use FindBin qw( $Bin );
use lib "$Bin/lib";
use lib "$Bin/../lib";
use MyApp::Schema;

require DBD::SQLite;    # for verify-cpanfile
my $schema = MyApp::Schema->connect('dbi:SQLite:dbname=:memory:');

{
    my $sql_file = "$Bin/db/example.sql";
    open my $fh, '<', $sql_file or die $!;
    local $/ = ';';
    $schema->storage->dbh_do( sub { $_[1]->do($_) } ) for readline $fh;
}

pass "Nothing to see here";

done_testing;
