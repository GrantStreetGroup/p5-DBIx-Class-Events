package MyApp::Schema::Result::Track;

use warnings;
use strict;

use base qw( DBIx::Class::Core );

__PACKAGE__->load_components(qw/ Events /);

__PACKAGE__->table('track');

__PACKAGE__->add_columns(
  trackid => {
    data_type => 'integer',
    is_auto_increment => 1
  },
  cdid => {
    data_type => 'integer',
  },
  title => {
    data_type => 'text',
  },
);

__PACKAGE__->set_primary_key('trackid');

__PACKAGE__->add_unique_constraint([qw( title cdid )]);

__PACKAGE__->belongs_to('cd' => 'MyApp::Schema::Result::Cd', 'cdid');

__PACKAGE__->has_many(
    'events' => ( 'MyApp::Schema::Result::TrackEvent', 'trackid' ),
    { cascade_delete => 0 },
);

sub event_columns { return ( qw( title ), shift->next::method(@_) ) }

sub event_defaults {
    my $self = shift;
    return ( title => 'N/A', $self->next::method(@_) );
}

1;
