package MyApp::Schema::Result::Artist;

use warnings;
use strict;

use base qw( DBIx::Class::Core );

__PACKAGE__->table('artist');

__PACKAGE__->add_columns(
  artistid => {
    data_type => 'integer',
    is_auto_increment => 1
  },
  name => {
    data_type => 'text',
  },
  last_name_change_id => {
    data_type => 'integer',
  },
  previousid => {
    data_type => 'integer',
  },
);

__PACKAGE__->set_primary_key('artistid');

__PACKAGE__->add_unique_constraint([qw( name )]);

__PACKAGE__->has_many('cds' => 'MyApp::Schema::Result::Cd', 'artistid');

__PACKAGE__->load_components( qw/ Events / );

# A different name can be used with the "events_relationship" attribute
__PACKAGE__->has_many(
    'events' => ( 'MyApp::Schema::Result::ArtistEvent', 'artistid' ),
    { cascade_delete => 0 },
);

__PACKAGE__->events_relationship('events');

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

1;
