package Elastic::Model::TypeMap::ES;

use strict;
use warnings;

use Elastic::Model::TypeMap::Base qw(:all);
use namespace::autoclean;

#===================================
has_type 'Elastic::Model::Types::UID',
#===================================
    deflate_via {
    'do {'
        . 'die "Cannot deflate UID as it not saved\n"'
        . 'unless $val->from_store;'
        . '$val->read_params;' . '}';
    },

    inflate_via {
    'Elastic::Model::UID->new( from_store => 1, %$val  )';
    },

    map_via {
    my %props = map {
        $_ => {
            type                         => 'string',
            index                        => 'not_analyzed',
            omit_norms                   => 1,
            omit_term_freq_and_positions => 1,
            }
    } qw(index type id routing);

    $props{routing}{index} = 'no';
    delete $props{routing}{index_name};

    return (
        type       => 'object',
        dynamic    => 'strict',
        properties => \%props,
        path       => 'full'
    );

    };

#===================================
has_type 'Elastic::Model::Types::Keyword',
#===================================
    map_via {
    type                         => 'string',
    index                        => 'not_analyzed',
    omit_norms                   => 1,
    omit_term_freq_and_positions => 1,
    };

#===================================
has_type 'Elastic::Model::Types::GeoPoint',
#===================================
    deflate_via {'$val'},
    inflate_via {'$val'},
    map_via { type => 'geo_point' };

#===================================
has_type 'Elastic::Model::Types::Binary',
#===================================
    deflate_via {
    require MIME::Base64;
    'MIME::Base64::encode_base64( $val )';
    },

    inflate_via {
    'MIME::Base64::decode_base64( $val )';
    },

    map_via { type => 'binary' };

#===================================
has_type 'Elastic::Model::Types::Timestamp',
#===================================
    deflate_via {'int( $val * 1000 + 0.5 )'},
    inflate_via {'sprintf "%.3f", $val / 1000'},
    map_via { type => 'date' };

1;

# ABSTRACT: Type maps for ElasticSearch-specific types

=head1 DESCRIPTION

L<Elastic::Model::TypeMap::ES> provides mapping, inflation and deflation
for ElasticSearch specific types.

=head1 TYPES

=head2 Elastic::Model::Types::Keyword

Attributes of type L<Elastic::Model::Types/Keyword> are in/deflated
via L<Elastic::Model::TypeMap::Moose/Any> and are mapped as:

    {
        type                         => 'string',
        index                        => 'not_analyzed',
        omit_norms                   => 1,
        omit_term_freq_and_positions => 1,
    }

It is a suitable type to use for string attributes which should not
be analyzed, and will not be used for scoring. Rather they are suitable
to use as filters.

=head2 Elastic::Model::Types::UID

An L<Elastic::Model::UID> is deflated into a hash ref and reinflated
via L<Elastic::Model::UID/"new_from_store()">. It is mapped as:

    {
        type        => 'object',
        dynamic     => 'strict',
        path        => 'path',
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

B<Note:> When querying timestamp fields in a View you will need to express the
comparison values as epoch milliseconds or as an RFC3339 datetime:

    { my_timestamp => { '>' => 1351748867 * 1000      }}
    { my_timestamp => { '>' => '2012-11-01T00:00:00Z' }}
