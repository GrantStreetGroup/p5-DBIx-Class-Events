package MyApp::Schema::Result::TrackEvent;

use warnings;
use strict;
use JSON ();

use base qw( DBIx::Class::Core );

__PACKAGE__->load_components(qw/ InflateColumn::DateTime /);

__PACKAGE__->table('track_event');

__PACKAGE__->add_columns(
  trackeventid => {
    data_type => 'integer',
    is_auto_increment => 1
  },
  trackid => {
    data_type => 'integer',
  },
  event => {
    data_type => 'varchar',
  },
  triggered_on => {
    data_type => 'datetime',
  },
  details => {
    data_type => 'longtext',
  },
  title => {
    data_type => 'text',
  },
);

__PACKAGE__->set_primary_key('trackeventid');

{
    my $json = JSON->new->utf8;
    __PACKAGE__->inflate_column( 'details' => {
        inflate => sub { $json->decode(shift) },
        deflate => sub { $json->encode(shift) },
    } );
}

#__PACKAGE__->add_unique_constraint([qw( )]);

__PACKAGE__->belongs_to('track' => 'MyApp::Schema::Result::Track', 'trackid');

1;
