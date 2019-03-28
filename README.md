# NAME

DBIx::Class::Events - Store Events for your DBIC Results

# VERSION

version 0.9.1

# SYNOPSIS

    my $artist
        = $schema->resultset('Artist')->create( { name => 'Dead Salmon' } );
    $artist->events->count;    # is now 1, an 'insert' event

    $artist->change_name('Trout');    # add a name_change event
    $artist->update;    # An update event, last_name_change_id and name

    # Find their previous name
    my $name_change = $artist->last_name_change;
    print $name_change->details->{old}, "\n";

See `change_name` and `last_name_change` example definitions
in ["CONFIGURATION AND ENVIRONMENT"](#configuration-and-environment).

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
        ->single( { artistid => $artist->id, event => 'delete' } )
        ->triggered_on;

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
    $death_event->update

    # And after even more new names and arguments, they split up again
    $artist->delete;

See ["CONFIGURATION AND ENVIRONMENT"](#configuration-and-environment) for how to set up the tables.

# DESCRIPTION

A framework for capturing events that happen to a Result in a table,
["PRECONFIGURED EVENTS"](#preconfigured-events) are triggered automatically to track changes.

This is useful for both being able to see the history of things
in the database as well as logging when events happen that
can be looked up later.

Events can be used to track when things happen.

- when a user on a website clicks a particular button
- when a recipe was prepared
- when a song was played
- anything that doesn't fit in the main table

# CONFIGURATION AND ENVIRONMENT

## event\_defaults

A method that returns an even-sized list of default values that will be used
when creating a new event.

    my %defaults = $object->event_defaults( $event_type, \%col_data );

The `$event_type` is a string defining the "type" of event being created.
The `%col_data` is a reference to the parameters passed in.

No default values, but if your database doesn't set a default for
`triggered_on`, you may want to set it to a `DateTime->now` object.

## events\_relationship

An class accessor that returns the relationship to get from your object
to the relationship.

Default is `events`, but you can override it:

    __PACKAGE__->has_many(
        'cd_events' =>
            ( 'MyApp::Schema::Result::ArtistEvents', 'cdid' ),
        { cascade_delete => 0 },
    );

    __PACKAGE__->events_relationship('cd_events');

## Tables

### Tracked Table

The table with events to be tracked in the ["Tracking Table"](#tracking-table).

It requires the Component and ["events\_relationship"](#events_relationship) in the Result class:

    package MyApp::Schema::Result::Artist;
    use base qw( DBIx::Class::Core );

    ...;

    __PACKAGE__->load_components( qw/ Events / );

    # A different name can be used with the "events_relationship" attribute
    __PACKAGE__->has_many(
        'events' => ( 'MyApp::Schema::Result::ArtistEvent', 'artistid' ),
        { cascade_delete => 0 },
    );

You can also add custom events to track when something happens.  For example,
you can create a method to add events when an artist changes their name:

    __PACKAGE__->add_column(
        last_name_change_id => { data_type => 'integer' } );

    __PACKAGE__->has_one(
        'last_name_change'        => 'MyApp::Schema::Result::ArtistEvent',
        { 'foreign.artisteventid' => 'self.last_name_change_id' },
        { cascade_delete          => 0 },
    );

    sub change_name {
        my ( $self, $new_name ) = @_;

        my $event = $self->event( name_change =>
                { details => { new => $new_name, old => $self->name } } );
        $self->last_name_change( $event );
        # $self->update; # be lazy and make our caller call ->update

        $self->name( $new_name );
    }

### Tracking Table

This table holds the events for the ["Tracked Table"](#tracked-table).

The `triggered_on` column must either provide a `DEFAULT` value
or you should add a default to ["event\_defaults"](#event_defaults).

    package MyApp::Schema::Result::ArtistEvent;

    use warnings;
    use strict;
    use JSON;

    use base qw( DBIx::Class::Core );

    __PACKAGE__->load_components(qw/ InflateColumn::DateTime /);

    __PACKAGE__->table('artist_event');

    __PACKAGE__->add_columns(
        artisteventid => { data_type => 'integer', is_auto_increment => 1 },
        artistid      => { data_type => 'integer' },

        # The type of event
        event         => { data_type => 'varchar' },

        # Any other custom columns you want to store for each event.

        triggered_on => {
            data_type     => 'datetime',
            default_value => \'NOW()',
        },

        # Where we store freeform data about what happened
        details => { data_type => 'longtext' },
    );

    __PACKAGE__->set_primary_key('artisteventid');

    # You should set up automatic inflation/deflation of the details column
    # as it is used this way by "state_at" and the insert/update/delete
    # events.  Does not have to be JSON, just be able to serialize a hashref.
    {
        my $json = JSON->new->utf8;
        __PACKAGE__->inflate_column( 'details' => {
            inflate => sub { $json->decode(shift) },
            deflate => sub { $json->encode(shift) },
        } );
    }

    # A path back to the object that this event is for,
    # not required unlike the has_many "events" relationship above
    __PACKAGE__->belongs_to(
        'artist' => ( 'MyApp::Schema::Result::Artist', 'artistid' ) );

You probably also want an index for searching for events:

    sub sqlt_deploy_hook {
        my ( $self, $sqlt_table ) = @_;
        $sqlt_table->add_index(
            name   => 'artist_event_idx',
            fields => [ "artistid", "triggered_on", "event" ],
        );
    }

# PRECONFIGURED EVENTS

Automatically creates Events for actions that modify a row.

See the ["BUGS AND LIMITATIONS"](#bugs-and-limitations) of bulk modifications on events.

- insert

    Logs all columns to the `details` column, with an `insert` event.

- update

    Logs dirty columns to the `details` column, with an `update` event.

- delete

    Logs all columns to the `details` column, with a `delete` event.

# METHODS

## event

Inserts a new event with ["event\_defaults"](#event_defaults):

    my $new_event = $artist->event( $event => \%params );

First, the ["event\_defaults"](#event_defaults) method is called to build a list of values
to set on the new event.  This method is passed the `$event` and a reference
to `%params`.

Then, the `%params`, filtered for valid ["events\_relationship"](#events_relationship) `columns`,
are added to the `create_related` arguments, overriding the defaults.

## state\_at

Takes a timestamp and returns the state of the thing at that timestamp as a
hash reference.  Can be either a correctly deflated string or a DateTime
object that will be deflated with `format_datetime`.

Returns undef if the object was not `in_storage` at the timestamp.

    my $state = $schema->resultset('Artist')->find( { name => 'David Bowie' } )
        ->state_at('2006-05-29 08:00');

An idea is to use it to recreate an object as it was at that timestamp.
Of course, default values that the database provides will not be included,
unless the ["event\_defaults"](#event_defaults) method accounts for that.

    my $resurrected_object
        = $object->result_source->new( $object->state_at($timestamp) );

See ".. format a DateTime object for searching?" under ["Searching" in DBIx::Class::Manual::FAQ](https://metacpan.org/pod/DBIx::Class::Manual::FAQ#Searching)
for details on formatting the timestamp.

You can pass additional [search](https://metacpan.org/pod/DBIx::Class::ResultSet#search) conditions and
attributes to this method.  This is done in context of searching the events
table:

    my $state = $object->state_at($timestamp, \%search_cond, \%search_attrs);

# BUGS AND LIMITATIONS

There is no attempt to handle bulk updates or deletes.  So, any changes to the
database made by calling
["update"](https://metacpan.org/pod/DBIx::Class::ResultSet#update) or ["delete"](https://metacpan.org/pod/DBIx::Class::ResultSet#delete)
will not create events the same as [single row](https://metacpan.org/pod/DBIx::Class::Row) modifications.  Use the
["update\_all"](https://metacpan.org/pod/DBIx::Class::ResultSet#update_all) or ["delete\_all"](https://metacpan.org/pod/DBIx::Class::ResultSet#delete_all)
methods of the `ResultSet` if you want these triggers.

There are three required columns on the ["events\_relationship"](#events_relationship) table:
`event`, `triggered_on`, and `details`.  We should eventually make those
configurable.

# SEE ALSO

- [DBIx::Class::AuditAny](https://metacpan.org/pod/DBIx::Class::AuditAny)
- [DBIx::Class::AuditLog](https://metacpan.org/pod/DBIx::Class::AuditLog)
- [DBIx::Class::Journal](https://metacpan.org/pod/DBIx::Class::Journal)
- [DBIx::Class::PgLog](https://metacpan.org/pod/DBIx::Class::PgLog)

# AUTHOR

Grant Street Group <developers@grantstreet.com>

# COPYRIGHT AND LICENSE

This software is Copyright (c) 2018 - 2019 by Grant Street Group.

This is free software, licensed under:

    The Artistic License 2.0 (GPL Compatible)

# CONTRIBUTORS

- Andrew Fresh <andrew.fresh@grantstreet.com>
- Brendan Byrd <brendan.byrd@grantstreet.com>
- Justin Wheeler <justin.wheeler@grantstreet.com>
