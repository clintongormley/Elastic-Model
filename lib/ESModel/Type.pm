package ESModel::Type;

use Moose();
use Moose::Exporter;

Moose::Exporter->setup_import_methods(
    with_meta => [ qw(
            analyzer_path
            analyzer
            boost_path
            disable_all
            disable_date_detection
            disable_indexing
            disable_numeric_detection
            disable_source_compression
            disable_source
            dynamic_date_formats
            dynamic
            dynamic_templates
            enable_size
            enable_timestamp
            enable_ttl
            id_path
            include_in_all
            index_analyzer
            index_id
            index_index
            is_type
            parent_type
            routing_path
            routing_required
            search_analyzer
            source_excludes
            source_includes
            timestamp_format
            timestamp_path
            ttl
            type_settings             )
    ],
    class_metaroles => {
        class     => ['ESModel::Meta::Class::Type'],
        attribute => ['ESModel::Meta::Attribute::Trait::Field'],
    },
    base_class_roles => ['ESModel::Role::Type'],
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
sub disable_source             { shift->disable_source(1) }
sub dynamic_date_formats       { shift->dynamic_date_formats(@_) }
sub dynamic                    { shift->dynamic(@_) }
sub dynamic_templates          { shift->dynamic_templates(@_) }
sub enable_size                { shift->enable_size(1) }
sub enable_timestamp           { shift->enable_timestamp(1) }
sub enable_ttl                 { shift->enable_ttl(1) }
sub id_path                    { shift->id_path(@_) }
sub include_in_all             { shift->include_in_all(@_) }
sub index_analyzer             { shift->index_analyzer(@_) }
sub index_id                   { shift->index_id(1) }
sub index_index                { shift->index_index(1) }
sub is_type                    { shift->_set_type_name(@_) }
sub parent_type                { shift->parent_type(@_) }
sub routing_path               { shift->routing_path(@_) }
sub routing_required           { shift->routing_required(1) }
sub search_analyzer            { shift->search_analyzer(@_) }
sub source_excludes            { shift->source_excludes(@_) }
sub source_includes            { shift->source_includes(@_) }
sub timestamp_format           { shift->timestamp_format(@_) }
sub timestamp_path             { shift->timestamp_path(@_) }
sub ttl                        { shift->ttl(@_) }
sub type_settings              { shift->type_settings(@_) }
#===================================

1;
