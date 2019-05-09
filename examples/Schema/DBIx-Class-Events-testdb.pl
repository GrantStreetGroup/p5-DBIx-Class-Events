#!/usr/bin/env perl

use warnings;
use strict;

use lib '.';
use MyApp::Schema;

use Path::Class 'file';
my $db_fn = file($INC{'MyApp/Schema.pm'})->dir->parent->file('db/example.db');

# for other DSNs, e.g. MySql, see the perldoc for the relevant dbd
# driver, e.g perldoc L<DBD::mysql>.
my $schema = MyApp::Schema->connect("dbi:SQLite:$db_fn");

my $artist
    = $schema->resultset('Artist')->create( { name => 'Dead Salmon' } );
$artist->events->count;    # is now 1, an 'insert' event
 
$artist->change_name('Trout');    # add a name_change event
$artist->update;    # An update event, last_name_change_id and name
 
# Find their previous name
my $name_change = $artist->last_name_change;
print $name_change->details->{old}, "\n";
# Three more name_change events and one update event
$artist->change_name('Fried Trout');
$artist->change_name('Poached Trout in a White Wine Sauce');
$artist->change_name('Herring');
$artist->update;

# Look up all the band's previous names
print "$_\n"
    for map { $_->details->{old} }
    $artist->events->search( { event => 'name_change' } );

$artist->delete;    # and then they break up.

# We can find out now when they broke up, if we remember their id.
my $deleted_on
    = $schema->resultset('ArtistEvent')
    ->search( { artistid => $artist->id, event => 'delete' },
              { order_by => { -desc => 'triggered_on'},     },
            )->first->triggered_on;
#my $deleted_on
#    = $schema->resultset('ArtistEvent')
#    ->single( { artistid => $artist->id, event => 'delete' } )
#    ->triggered_on;

# Find the state of the band was just before the breakup.
my $state_before_breakup
    = $artist->state_at( $deleted_on->subtract( seconds => 1 ) );

# Maybe this is common,
# so we have a column to link to who they used to be.
my $previous_artist_id = delete $state_before_breakup->{artistid};

# Then we can form a new band, linked to the old,
# with the same values as the old band, but a new name.
$artist = $schema->resultset('Artist')->create( {
    %{$state_before_breakup},
    previousid => $previous_artist_id,
    name       => 'Red Herring',
} );

# After a few more name changes, split-ups, and getting back together,
# we find an event we should have considered, but didn't.
my $death_event
    = $artist->event( death => { details => { who => 'drummer' } } );

# but, we then go back and modify it to note that it was only a rumor
$death_event->details->{only_a_rumour} = 1;
$death_event->make_column_dirty('details'); # changing the hashref doesn't
$death_event->update;

# And after even more new names and arguments, they split up again
$artist->delete;
