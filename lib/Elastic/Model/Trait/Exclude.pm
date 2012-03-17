package Elastic::Model::Trait::Exclude;

use Moose::Role;
use Moose::Exporter;
use MooseX::Types::Moose qw(:all);
use namespace::autoclean;

Moose::Exporter->setup_import_methods(
    role_metaroles =>
        { applied_attribute => ['Elastic::Model::Trait::Exclude'], },
    class_metaroles => { attribute => ['Elastic::Model::Trait::Exclude'] },
);

has 'exclude' => ( isa => Bool, is => 'ro', default => 1 );

1;
