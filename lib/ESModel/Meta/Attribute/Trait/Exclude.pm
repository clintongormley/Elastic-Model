package ESModel::Meta::Attribute::Trait::Exclude;

use Moose::Role;
use Moose::Exporter;

Moose::Exporter->setup_import_methods(
    role_metaroles => {
        applied_attribute => ['ESModel::Meta::Attribute::Trait::Exclude'],
    },
    class_metaroles =>
        { attribute => ['ESModel::Meta::Attribute::Trait::Exclude'] },
);

has 'exclude' => ( isa => 'Bool', is => 'ro', default => 1 );

1;
