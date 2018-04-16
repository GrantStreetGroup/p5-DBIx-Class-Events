#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use Test::Mock::Time ();

use FindBin qw( $Bin );
use lib "$Bin/lib";
use MyApp::Schema;

# for verify-cpanfile
require DBD::SQLite;
require DateTime::Format::SQLite;

my $schema = MyApp::Schema->connect('dbi:SQLite:dbname=:memory:');

{
    my $sql_file = "$Bin/db/example.sql";
    open my $fh, '<', $sql_file or die $!;
    local $/ = ';';
    $schema->storage->dbh_do( sub { $_[1]->do($_) } ) for readline $fh;
}

$schema->txn_do( sub {
    note "Insert";

    my $artist = $schema->resultset('Artist')->create( { name => 'foo' } );

    my @events = $artist->events->search( {},
        { order_by => 'artisteventid' } );

    is @events, 1, 'One event';
    is $events[0]->event, 'insert', 'Insert event';
    is $events[0]->artistid, $artist->id, 'Insert event has correct artist';
    is $events[0]->triggered_on, DateTime->now,
        "Triggered when we expected";

    is_deeply $events[0]->details, {
        artistid => $artist->id,
        name     => "foo"
    }, 'Correct insert details';

    $schema->txn_rollback;
} );

$schema->txn_do( sub {
    note "Update";

    my $artist = $schema->resultset('Artist')->create( { name => 'bar' } );

    $artist->update;    # Should be an ignored noop
    sleep 1;

    $artist->name('baz');
    $artist->update;
    my $event_1_ts = DateTime->now;

    sleep 1;
    $artist->update;    # Should be an ignored noop

    sleep 1;
    $artist->name('bar');
    $artist->update( { name => 'qux' } );
    my $event_2_ts = DateTime->now;

    sleep 1;
    $artist->update;    # Should be an ignored noop

    my @events = $artist->events->search( {},
        { order_by => 'artisteventid' } );

    is @events, 3, 'Three events';
    is $events[0]->event, 'insert', 'Insert event';
    is $events[1]->event, 'update', 'Update event';
    is $events[1]->artistid, $artist->id, 'Update event has correct artist';
    is $events[1]->triggered_on, $event_1_ts,
        "Triggered event 1 when we expected";
    is $events[2]->event, 'update', 'Update event';
    is $events[2]->artistid, $artist->id, 'Update event has correct artist';
    is $events[2]->triggered_on, $event_2_ts,
        "Triggered event 2 when we expected";

    is_deeply $events[1]->details, { name => "baz" },
        'Correct update details';

    is_deeply $events[2]->details, { name => "qux" },
        'Correct update details';

    $schema->txn_rollback;
});

$schema->txn_do( sub {
    note "Delete";

    my $artist = $schema->resultset('Artist')->create( { name => 'bar' } );

    my $artist_id = $artist->id;
    my $events_rs = $artist->events;

    $artist->delete;

    my @events
        = $events_rs->search( {}, { order_by => 'artisteventid' } );

    is @events, 2, 'Two events';
    is $events[0]->event, 'insert', 'Insert event';
    is $events[1]->event, 'delete', 'Delete event';
    is $events[1]->artistid, $artist_id, 'Delete event has correct artist';
    is $events[1]->triggered_on, DateTime->now,
        "Triggered event when we expected";

    is_deeply $events[1]->details, {
        artistid => $artist_id,
        name     => "bar"
    }, 'Correct delete details';

    $schema->txn_rollback;
} );

$schema->txn_do( sub {
    note "Something custom event";

    my $artist
        = $schema->resultset('Artist')->create( { name => 'Dead Salmon' } );

    ok !$artist->last_name_change_id, "No rename yet";

    my @events = $artist->events->search( {},
        { order_by => 'artisteventid' } );

    is @events, 1, 'No events triggered by looking for a last name change';
    is $events[0]->event, 'insert', 'Insert event';

    my @names = (
        'Trout',
        'Fried Trout',
        'Poached Trout In A White Wine Sauce',
        'Herring',
        'Red Herring',
        'Dead Herring',
        'Dead Loss',
        'Heads Together',
        'Dead Together',
        'Dead Gear',
        'Dead Donkeys',
        'Lead Donkeys',
        'Sole Manier',
        'Dead Sole',
        'Rock Cod',
        'Turbot',
        'Haddock',
        'White Baith',
        'The Places',
        'Fish',
        'Bream',
        'Mackerel',
        'Salmon',
        'Poached Salmon',
        'Poached Salmon In A White Wine Sauce',
        'Salmon-monia',
        'Helen Shapiro',
        'Dead Monkeys',
    );

    $artist->change_name( $_ ) for @names;
    $artist->update;

    is $artist->last_name_change->details->{old}, 'Helen Shapiro',
        "Last name change lists the old name";

    is $artist->events->search({ event => 'name_change' })->count,
        scalar @names, "Same number of name change events as names";
    @events = $artist->events->search( {},
        { order_by => 'artisteventid' } );

    is @events, @names + 2 , 'Number of name changes, plus insert and update';
    is $events[0]->event, 'insert', 'Insert event';

    is $events[1]->event, 'name_change',    'Name Change event';
    is $events[1]->triggered_on, DateTime->now,
        "Triggered name change event when we expected";

    is $events[-1]->event, 'update', 'Update event';
    is $events[-1]->triggered_on, DateTime->now,
        "Triggered update event when we expected";

    is $events[1]->artistid, $artist->id, 'Foo event has correct artist';

    is_deeply $events[1]->details, {
        old => 'Dead Salmon',
        new => 'Trout'
    }, 'First name change event has our details';

    is_deeply $events[-1]->details, {
        last_name_change_id => $events[-2]->id,
        name                => 'Dead Monkeys'
    }, 'Update event has updated details';

    is $artist->last_name_change_id, $events[-2]->id,
        'Correct event attached';

    $schema->txn_rollback;
} );

$schema->txn_do( sub {
    note "Bar event without details";

    my $artist
        = $schema->resultset('Artist')->create( { name => 'artist_foo' } );

    $artist->event('bar');

    my @events = $artist->events->search( {},
        { order_by => 'artisteventid' } );

    is @events, 2, 'three events';
    is $events[0]->event, 'insert', 'Insert event';
    is $events[1]->event, 'bar',    'Bar event';

    is $events[1]->artistid, $artist->id, 'Foo event has correct artist';
    is_deeply $events[1]->details, undef, 'Bar event has no details';

    $schema->txn_rollback;
} );

$schema->txn_do( sub {
    note "Custom event relationship";

    my $artist
        = $schema->resultset('Artist')->create( { name => 'An Artist' } );
    my $cd = $schema->resultset('Cd')
        ->create( { title => 'A CD', artist => $artist } );

    my $insert_ts = DateTime->now;
    sleep 5;

    $cd->year(1999);
    $cd->update;

    my $update_ts = DateTime->now;
    sleep 5;

    $cd->delete;

    my $delete_ts = DateTime->now;
    sleep 5;

    my @events = $cd->cd_events->search( {},
        { order_by => 'cdeventid' } );

    is @events, 3, 'Three events';
    is $events[0]->event, 'insert', 'Insert event';

    is $events[1]->event, 'update', 'Update event';
    is $events[1]->cdid, $cd->id, 'Update event has correct cd';
    is $events[1]->triggered_on, $update_ts,
        "Triggered event when we expected";
    is_deeply $events[1]->details, { year => 1999 }, 'Correct update details';

    is $events[2]->event, 'delete', 'Delete event';
    is $events[2]->cdid, $cd->id, 'Delete event has correct cd';
    is $events[2]->triggered_on, $delete_ts,
        "Triggered event when we expected";
    is_deeply $events[2]->details, {
        cdid     => $cd->id,
        title    => 'A CD',
        year     => 1999,
        artistid => $artist->id,
    }, 'Correct delete details';

    is_deeply $cd->state_at(
        $insert_ts->clone->subtract( seconds => 2 ) ),
        undef, "State two seconds before insert is as expected";

    is_deeply $cd->state_at( $insert_ts ), {
        cdid     => $cd->id,
        title    => 'A CD',
        artistid => $artist->id,
    }, "State at insert is as expected";

    # This is a format that DBD::SQLite likes
    is_deeply $cd->state_at( $update_ts->datetime(q{ }) ), {
        cdid     => $cd->id,
        title    => 'A CD',
        year     => 1999,
        artistid => $artist->id,
    }, "State at update is as expected";

    my $dtf = $schema->storage->datetime_parser;
    is_deeply $cd->state_at( $dtf->format_datetime($update_ts) ), {
        cdid     => $cd->id,
        title    => 'A CD',
        year     => 1999,
        artistid => $artist->id,
    }, "State at update is as expected";

    is_deeply $cd->state_at( $delete_ts ), undef,
        "State at delete is as expected";

    $schema->txn_rollback;
} );

$schema->txn_do( sub {
    note "Custom event fields";

    my $artist
        = $schema->resultset('Artist')->create( { name => 'An Artist' } );
    my $cd = $schema->resultset('Cd')
        ->create( { title => 'A CD', artist => $artist } );
    my $track = $schema->resultset('Track')
        ->create( { title => 'A Track', cd => $cd } );

    $track->title('Modified Title');
    $track->update;
    $track->delete;

    my @events = $track->events->search( {}, { order_by => 'trackeventid' } );

    is @events, 3, 'Three events';
    is $events[0]->event, 'insert', 'Insert event';
    is $events[0]->title, 'A Track', 'Insert set custom field';
    is $events[1]->event, 'update', 'Update event';
    is $events[1]->title, 'Modified Title', 'Update set custom field';
    is $events[2]->event, 'delete', 'Delete event';
    is $events[2]->title, 'Modified Title', 'Delete set custom field';

    $schema->txn_rollback;
} );

$schema->txn_do( sub {
    note "Custom event defaults";

    my $artist
        = $schema->resultset('Artist')->create( { name => 'An Artist' } );
    my $cd = $schema->resultset('Cd')
        ->create( { title => 'A CD', artist => $artist } );
    my $track = $schema->resultset('Track')
        ->create( { title => 'A Track', cd => $cd } );

    $track->title('Modified Title');
    $track->event('none');
    $track->event( custom => { title => 'Custom Value' } );

    my @events = $track->events->search( {}, { order_by => 'trackeventid' } );

    is @events, 3, 'Three events';
    is $events[0]->event, 'insert', 'Insert event';
    is $events[0]->title, 'A Track', 'Insert set custom field';
    is $events[1]->event, 'none', 'None event';
    is $events[1]->title, 'N/A', 'None event set default field';
    is $events[2]->event, 'custom', 'Custom value event';
    is $events[2]->title, 'Custom Value', 'Custom field set custom field';

    $schema->txn_rollback;
} );

$schema->txn_do( sub {
    note "State At";

    $schema->resultset($_)->search->delete for qw( Artist ArtistEvent );

    my $dtf = $schema->storage->datetime_parser;
    my $now = sub { $dtf->format_datetime( DateTime->now ) };

    my %expect = ( $now->() => {} );
    sleep 2;

    my $foo = $schema->resultset('Artist')->create( { name => 'foo' } );
    my %foo_state = ( artistid => $foo->id, name => 'foo' );
    $expect{ $now->() } = { $foo->id => {%foo_state} };

    # Before the insert, it should be undef
    $expect{ $dtf->format_datetime( DateTime->now->subtract( seconds => 1 ) ) }
        = { $foo->id => undef };
    sleep 1;

    my $event_foo = $foo->change_name('Qux');
    $foo->update;
    $foo_state{name} = 'Qux';
    $foo->discard_changes;
    $foo_state{last_name_change_id} = $foo->last_name_change->id;

    $expect{ $now->() } = { $foo->id => {%foo_state} };
    sleep 1;

    my $bar = $schema->resultset('Artist')->create( { name => 'bar' } );
    my %bar_state = ( artistid => $bar->id, name => 'bar' );

    $expect{ $now->() }
        = { $foo->id => {%foo_state}, $bar->id => {%bar_state} };
    sleep 1;

    $bar->name('baz');
    $bar_state{name} = 'baz';
    $bar->update;

    $expect{ $now->() }
        = { $foo->id => {%foo_state}, $bar->id => {%bar_state} };
    sleep 1;

    $foo->delete;
    $expect{ $now->() } = { $foo->id => undef, $bar->id => {%bar_state} };
    sleep 30;

    my $i = 0;
    foreach my $ts ( sort keys %expect ) {
        $i++;

        is_deeply(
            $foo->state_at($ts),
            $expect{$ts}{ $foo->id },
            "[$i][$ts] Expected Row structure"
        ) or diag explain [ $foo->id, $foo->state_at($ts), $expect{$ts} ];

        # TODO: Add state_at as a resultset method
        #is_deeply $schema->resultset('Artist')->state_at($ts), $expect{$ts},
        #    "[$i][$ts] Expected Class structure";
        #
        # is_deeply $schema->resultset('Artist')
        #    ->state_at( $ts, { artistid => $bar } ), $expect{$ts}{$bar->id},
        #    "[$i][$ts] Expected Search structure";
        #
        #is_deeply $schema->resultset('Artist')->state_at(
        #    $ts,
        #    { "artistid.firsa_name" => "Baz" },
        #    { join                 => "artistid" }
        #), $expect{$ts}{$bar->id}, "[$i][$ts] Expected Joined Search structure";
    }

    $schema->txn_rollback;
} );

done_testing();
