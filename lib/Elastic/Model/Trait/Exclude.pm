package Elastic::Model::Trait::Exclude;

use Moose::Role;
use Moose::Exporter;
use MooseX::Types::Moose qw(Bool);
use namespace::autoclean;

Moose::Exporter->setup_import_methods(
    role_metaroles =>
        { applied_attribute => ['Elastic::Model::Trait::Exclude'], },
    class_metaroles => { attribute => ['Elastic::Model::Trait::Exclude'] },
);

has 'exclude' => ( isa => Bool, is => 'ro', default => 1 );

1;

__END__

# ABSTRACT: An internal use trait

=head1 DESCRIPTION

This trait is used by Elastic::Model doc attributes which shouldn't be
stored in Elasticsearch. It implements just the
L<Elastic::Model::Trait::Field/"exclude"> keyword.
