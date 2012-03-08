package ESModel::Meta::Class::Doc;

use Moose::Role;
use namespace::autoclean;
use MooseX::Types::Moose qw(:all);
use ESModel::Types qw(DynamicTemplates DynamicMapping);
use Carp;

has 'type' => (
    isa    => Str,
    is     => 'ro',
    writer => '_set_type'
);

has 'type_settings' => (
    isa     => HashRef,
    is      => 'rw',
    default => sub { {} }
);

has [
    'analyzer',        'boost_path',   'index_analyzer', 'analyzer_path',
    'search_analyzer', 'routing_path', 'id_path',        'parent_type',
    'ttl'
] => ( isa => Str, is => 'rw' );

has [ 'source_includes', 'source_excludes', 'dynamic_date_formats' ] =>
    ( isa => ArrayRef [Str], is => 'rw' );

has [ 'include_in_all', 'date_detection', 'numeric_detection' ] =>
    ( isa => Bool, is => 'rw', default => 1 );

has [
    'enable_size',      'index_id',
    'disable_all',      'index_index',
    'routing_required', 'disable_indexing',
    'disable_source_compression'
] => ( isa => Bool, is => 'rw' );

has 'dynamic' => (
    isa     => DynamicMapping,
    is      => 'rw',
    default => 'strict'
);

has 'dynamic_templates' => (
    isa => DynamicTemplates,
    is  => 'rw'
);

has 'timestamp_path' => (
    isa => Maybe [Str],
    is => 'rw',
    default => 'timestamp'
);

has 'required_attrs' => (
    isa     => 'HashRef',
    is      => 'ro',
    default => sub { {} },
);

1;
