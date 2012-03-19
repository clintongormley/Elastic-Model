package Elastic::Doc;

use Moose();
use Moose::Exporter;
use namespace::autoclean;

Moose::Exporter->build_import_methods(
    install          => [qw(import unimport init_meta)],
    base_class_roles => ['Elastic::Model::Role::Doc'],
    with_meta        => ['type_mapping'],
    class_metaroles  => {
        class     => ['Elastic::Model::Meta::Class::Doc'],
        instance  => ['Elastic::Model::Meta::Instance'],
        attribute => ['Elastic::Model::Trait::Field'],
    }
);

#===================================
sub type_mapping { shift->type_mapping(@_) }
#===================================

1;
