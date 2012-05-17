package Elastic::Model::TypeMap::ES;

use Elastic::Model::TypeMap::Base qw(:all);
use namespace::autoclean;

#===================================
has_type 'Elastic::Model::Types::UID',
#===================================
    deflate_via {
    sub {
        die "Cannot deflate UID as it not saved\n"
            unless $_[0]->from_store;
        $_[0]->read_params;
        }
    },

    inflate_via {
    sub {
        Elastic::Model::UID->new( from_store => 1, @{ $_[0] } );
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
has_type 'Elastic::Model::Types::GeoPoint',
#===================================
    deflate_via {
    sub { $_[0] }
    },

    inflate_via {
    sub { $_[0] }
    },

    map_via { type => 'geo_point' };

#===================================
has_type 'Elastic::Model::Types::Binary',
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
has_type 'Elastic::Model::Types::Timestamp',
#===================================
    deflate_via {
    sub { int( $_[0] * 1000 + 0.0005 ) }
    },

    inflate_via {
    sub { $_[0] / 1000 }
    },

    map_via { type => 'date' };

1;

# ABSTRACT: Type maps for ElasticSearch-specific types

=head1 DESCRIPTION

L<Elastic::Model::TypeMap::ES> provides mapping, inflation and deflation
for ElasticSearch specific types.

=head1 TYPES

=head2 Elastic::Model::Types::UID

A L<Elastic::Model::UID> is deflated into a hash ref and reinflated
via L<Elastic::Model::UID/"new_from_store()">. It is mapped as:

    {
        type        => 'object',
        dynamic     => 'strict',
        properties  => {
            index   => {
                type                         => 'string',
                index                        => 'not_analyzed',
                omit_norms                   => 1,
                omit_term_freq_and_positions => 1,
            },
            type => {
                type                         => 'string',
                index                        => 'not_analyzed',
                omit_norms                   => 1,
                omit_term_freq_and_positions => 1,
            },
            id   => {
                type                         => 'string',
                index                        => 'not_analyzed',
                omit_norms                   => 1,
                omit_term_freq_and_positions => 1,
            },
            routing   => {
                type                         => 'string',
                index                        => 'no',
                omit_norms                   => 1,
                omit_term_freq_and_positions => 1,
            },
        }
    }

=head2 Elastic::Model::Types::GeoPoint

Attributes of type L<Elastic::Model::Types/"GeoPoint"> are mapped as
C<< { type => 'geo_point' } >>.

=head2 Elastic::Model::Types::Binary

Attributes of type L<Elastic::Model::Types/"Binary"> are deflated via
L<MIME::Base64/"encode_base64"> and inflated via L<MIME::Base64/"decode_base_64">.
They are mapped as C<< { type => 'binary' } >>.

=head2 Elastic::Model::Types::Timestamp

Attributes of type L<Elastic::Model::Types/"Timestamp"> are deflated
to epoch milliseconds, and inflated to epoch seconds (with floating-point
milliseconds). It is mapped as C<< { type => 'date' } >>.

