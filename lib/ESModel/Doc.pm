package ESModel::Doc;

use Moose();
use Moose::Exporter;

my ( undef, undef, $init_meta ) = Moose::Exporter->build_import_methods(
    install   => [qw(import unimport)],
    with_meta => [ qw(
            analyzer_path                  index_analyzer
            analyzer                       index_id
            boost_path                     index_index
            disable_all                    is_type
            disable_date_detection         parent_type
            disable_indexing               routing_path
            disable_numeric_detection      routing_required
            disable_source_compression     search_analyzer
            dynamic_date_formats           source_excludes
            dynamic                        source_includes
            dynamic_templates              timestamp_path
            enable_size                    ttl
            id_path                        type_settings
            include_in_all
            )
    ],
    class_metaroles => {
        class     => ['ESModel::Meta::Class::Doc'],
        attribute => ['ESModel::Meta::Attribute::Trait::Field'],
    }
);

#===================================
sub init_meta {
#===================================
    my $class = shift;
    my %p     = @_;
    Moose::Util::ensure_all_roles( $p{for_class}, 'ESModel::Role::Doc' );
    $class->$init_meta(%p);
}

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
sub is_type                    { shift->_set_type_name(@_) }
sub parent_type                { shift->parent_type(@_) }
sub routing_path               { shift->routing_path(@_) }
sub routing_required           { shift->routing_required(1) }
sub search_analyzer            { shift->search_analyzer(@_) }
sub source_excludes            { shift->source_excludes(@_) }
sub source_includes            { shift->source_includes(@_) }
sub timestamp_path             { shift->timestamp_path(@_) }
sub ttl                        { shift->ttl(@_) }
sub type_settings              { shift->type_settings(@_) }
#===================================

1;
