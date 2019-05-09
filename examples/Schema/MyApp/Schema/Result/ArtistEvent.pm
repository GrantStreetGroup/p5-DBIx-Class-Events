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

# You probably also want an index for searching for events:

sub sqlt_deploy_hook {
    my ( $self, $sqlt_table ) = @_;
    $sqlt_table->add_index(
        name   => 'artist_event_idx',
        fields => [ "artistid", "triggered_on", "event" ],
    );
}
