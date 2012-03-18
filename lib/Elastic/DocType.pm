package Elastic::DocType;

use Moose();
use Moose::Exporter;
use namespace::autoclean;

Moose::Exporter->build_import_methods(
    install          => [qw(import unimport init_meta)],
    base_class_roles => ['Elastic::Model::Role::Doc'],
    class_metaroles  => {
        class     => ['Elastic::Model::Meta::Class::DocType'],
        instance  => ['Elastic::Model::Meta::Instance'],
        attribute => ['Elastic::Model::Trait::Field'],
    },
    with_meta => [ qw(
            analyzer_path                  include_in_all
            analyzer                       index_analyzer
            boost_path                     index_id
            disable_all                    index_index
            disable_date_detection         parent_type
            disable_indexing               routing_path
            disable_numeric_detection      routing_required
            disable_source_compression     search_analyzer
            dynamic_date_formats           source_excludes
            dynamic                        source_includes
            dynamic_templates              ttl
            enable_size                    type_settings
            id_path
            )
    ],
);

#===================================
sub analyzer_path              { shift->analyzer_path(@_) }
sub analyzer                   { shift->analyzer(@_) }
sub boost_path                 { shift->boost_path(@_) }
sub disable_all                { shift->disable_all(1) }
sub disable_date_detection     { shift->date_detection(0) }
sub disable_indexing           { shift->disable_indexing(1) }
sub disable_numeric_detection  { shift->numeric_detection(0) }
sub disable_source_compression { shift->disable_source_compression(1) }
sub dynamic_date_formats       { shift->dynamic_date_formats(@_) }
sub dynamic                    { shift->dynamic(@_) }
sub dynamic_templates          { shift->dynamic_templates(@_) }
sub enable_size                { shift->enable_size(1) }
sub id_path                    { shift->id_path(@_) }
sub include_in_all             { shift->include_in_all(@_) }
sub index_analyzer             { shift->index_analyzer(@_) }
sub index_id                   { shift->index_id(1) }
sub index_index                { shift->index_index(1) }
sub parent_type                { shift->parent_type(@_) }
sub routing_path               { shift->routing_path(@_) }
sub routing_required           { shift->routing_required(1) }
sub search_analyzer            { shift->search_analyzer(@_) }
sub source_excludes            { shift->source_excludes(@_) }
sub source_includes            { shift->source_includes(@_) }
sub ttl                        { shift->ttl(@_) }
sub type_settings              { shift->type_settings(@_) }
#===================================

1;
