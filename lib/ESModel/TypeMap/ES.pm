package ESModel::TypeMap::ES;

use ESModel::TypeMap::Base qw(:all);

#===================================
has_type 'ESModel::Types::UID',
#===================================
    deflate_via {
    sub {
        die "Cannot deflate UID as it not stored\n"
            unless $_[0]->from_store;
        $_[0]->as_params;
        }
    },

    inflate_via {
    sub {
        ESModel::UID->new( from_store => 1, @{ $_[0] } );
        }
    },

    map_via {
    my %props = map {
        $_ => {
            type                         => 'string',
            index                        => 'not_analyzed',
            omit_norms                   => 1,
            omit_term_freq_and_positions => 1
            }
    } qw(index type id routing);

    $props{routing}{index} = 'no';

    return (
        type       => 'object',
        dynamic    => 'strict',
        properties => \%props
    );

    };

#===================================
has_type 'ESModel::Types::GeoPoint',
#===================================
    deflate_via {
    sub { $_[0] }
    },

    inflate_via {
    sub { $_[0] }
    },

    map_via { type => 'geo_point' };

#===================================
has_type 'ESModel::Types::Binary',
#===================================
    deflate_via {
    require MIME::Base64;
    sub { MIME::Base64::encode_base64( $_[0] ) };

    },

    inflate_via {
    sub { MIME::Base64::decode_base64( $_[0] ) }
    },

    map_via { type => 'binary' };

#===================================
has_type 'ESModel::Types::Timestamp',
#===================================
    deflate_via {
    sub { int( $_[0] * 1000 + 0.0005 ) }
    },

    inflate_via {
    sub { $_[0] / 1000 }
    },

    map_via { type => 'date' };

1;
