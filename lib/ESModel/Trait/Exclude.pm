package ESModel::Trait::Exclude;

use Moose::Role;
use Moose::Exporter;
use MooseX::Types::Moose qw(:all);
use namespace::autoclean;

Moose::Exporter->setup_import_methods(
    role_metaroles  => { applied_attribute => ['ESModel::Trait::Exclude'], },
    class_metaroles => { attribute         => ['ESModel::Trait::Exclude'] },
);

has 'exclude' => ( isa => Bool, is => 'ro', default => 1 );

1;
