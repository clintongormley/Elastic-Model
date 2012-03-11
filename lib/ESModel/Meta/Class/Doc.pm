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

#===================================
sub root_class_mapping {
#===================================
    my $self    = shift;
    my $class   = $self->name;
    my %mapping = %{ $self->type_settings };

    for (
        'analyzer',             'index_analyzer',    'search_analyzer',
        'dynamic_date_formats', 'dynamic_templates', 'date_detection',
        'numeric_detection'
        )
    {
        my $val = $self->$_;
        next unless defined $val;
        $mapping{$_} = $val;
    }

    $mapping{include_in_all} = 0 unless $self->include_in_all;

    $mapping{_id}{index} = 'not_analyzed' if $self->index_id;
    $mapping{enabled} = 0
        if $self->disable_indexing
    ;    ### WHAT TO DO HERE? EXCLUDE ATTRS? WHAT ABOUT UID

    $mapping{_source}{compress} = 1
        unless $self->disable_source_compression;
    $mapping{_source}{includes} = $self->source_includes
        if defined $self->source_includes;
    $mapping{_source}{excludes} = $self->source_excludes
        if defined $self->source_excludes;

    $mapping{_all}{enabled}      = 0 if $self->disable_all;
    $mapping{_routing}{required} = 1 if $self->routing_required;
    $mapping{_index}{enabled}    = 1 if $self->index_index;
    $mapping{_size}{enabled}     = 1 if $self->enable_size;

    if ( my $path = $self->timestamp_path ) {
        $mapping{_timestamp} = { enabled => 1, path => $path };

        if ( my $ttl = $self->ttl ) {
            $mapping{_ttl} = { enabled => 1, default => $ttl };
        }
    }

    $mapping{_analyzer}{path} = $self->analyzer_path if $self->analyzer_path;
    $mapping{_boost}{path}    = $self->boost_path    if $self->boost_path;
    $mapping{_id}{path}       = $self->id_path       if $self->id_path;
    $mapping{_routing}{path}  = $self->routing_path  if $self->routing_path;
    $mapping{_parent}{type}   = $self->parent_type   if $self->parent_type;

    return \%mapping;
}

1;
