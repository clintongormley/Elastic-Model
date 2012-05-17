package Elastic::Model::TypeMap::Common;

use Elastic::Model::TypeMap::Base qw(:all);
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

# ABSTRACT: Type maps for commonly used types

=head1 DESCRIPTION

L<Elastic::Model::TypeMap::Common> provides mapping, inflation and deflation
for commonly used types.

=head1 TYPES

=head2 DateTime

Attributes with an C<< isa => 'DateTime' >> constraint are deflated to
ISO8601 format in UTC, eg C<2012-01-01T01:01:01>, and reinflated via
L<DateTime/"new">.  They are mapped as C<< { type => 'date' } >>.



