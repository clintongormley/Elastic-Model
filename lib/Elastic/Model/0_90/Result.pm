package Elastic::Model::0_90::Result;

use Moose;
extends 'Elastic::Model::Result';

use Carp;
use Elastic::Model::Types qw(UID);
use MooseX::Types::Moose qw(HashRef Maybe Num Bool);

use namespace::autoclean;

around BUILDARGS => sub {
    my $orig   = shift;
    my $class  = shift;
    my $params = ref $_[0] eq 'HASH' ? shift : {@_};
    my $fields = $params->{result}{fields};
    for ( keys %$fields ) {
        next if substr( $_, 0, 1 ) eq '_';
        $fields->{$_} = [ $fields->{$_} ]
            unless ref $fields->{$_} eq 'ARRAY';
    }
    return $class->$orig($params);
};

1;

__END__

# ABSTRACT: A 0.90.x compatibility class for Elastic::Model::Result

=head1 DESCRIPTION

L<Elastic::Model::0_90::Result> converts the values in C<fields>
into arrays, in the same way that they are returned in Elasticsearch
1.x.

See L<Elastic::Manual::Delta> for more information about enabling
the 0.90.x compatibility mode.
