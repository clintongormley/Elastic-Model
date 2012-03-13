package ESModel::TypeMap::Common;

use ESModel::TypeMap::Base qw(:all);
use namespace::autoclean;

#===================================
has_type 'DateTime',
#===================================
    deflate_via {
    require DateTime;
    sub { $_[0]->set_time_zone('UTC')->iso8601 };
    },

    inflate_via {
    sub {
        my %args;
        @args{ (qw(year month day hour minute second)) } = split /\D/, shift;
        DateTime->new(%args);
    };
    },

    map_via { type => 'date' };
1;
