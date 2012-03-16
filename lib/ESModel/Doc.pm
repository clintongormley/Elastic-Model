package ESModel::Doc;

use Moose();
use Moose::Exporter;
use namespace::autoclean;

Moose::Exporter->build_import_methods(
    install         => [qw(import unimport init_meta)],
    class_metaroles => { attribute => ['ESModel::Trait::Field'] },
);

1;
