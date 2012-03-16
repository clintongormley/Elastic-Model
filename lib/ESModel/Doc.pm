package ESModel::Doc;

use Moose();
use Moose::Exporter;
use namespace::autoclean;

Moose::Exporter->build_import_methods(
    install          => [qw(import unimport init_meta)],
    base_class_roles => ['ESModel::Role::Doc'],
    class_metaroles  => {
        instance  => ['ESModel::Meta::Instance'],
        attribute => ['ESModel::Trait::Field'],
    }
);

1;
