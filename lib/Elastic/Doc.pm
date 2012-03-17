package Elastic::Doc;

use Moose();
use Moose::Exporter;
use namespace::autoclean;

Moose::Exporter->build_import_methods(
    install          => [qw(import unimport init_meta)],
    base_class_roles => ['Elastic::Model::Role::Doc'],
    class_metaroles  => {
        instance  => ['Elastic::Model::Meta::Instance'],
        attribute => ['Elastic::Model::Trait::Field'],
    }
);

1;
