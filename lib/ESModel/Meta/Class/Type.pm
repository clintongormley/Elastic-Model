package ESModel::Meta::Class::Type;

use Moose::Role;
use namespace::autoclean;
use ESModel::Type::Mapper qw(build_mapping);
use ESModel::Types qw(DynamicTemplates DynamicMapping);
use Carp;

has 'type_name' => ( isa => 'Str', is => 'ro', writer => '_set_type_name' );

has 'type_settings' =>
    ( isa => 'HashRef', is => 'rw', default => sub { {} } );

has 'analyzer'             => ( isa => 'Str',           is => 'rw' );
has 'index_analyzer'       => ( isa => 'Str',           is => 'rw' );
has 'search_analyzer'      => ( isa => 'Str',           is => 'rw' );
has 'dynamic_date_formats' => ( isa => 'ArrayRef[Str]', is => 'rw' );

has 'dynamic' => ( isa => DynamicMapping, is => 'rw', default => 'strict' );

has 'date_detection'       => ( isa => 'Bool',          is => 'rw', default=>1 );
has 'numeric_detection' => ( isa => 'Bool', is => 'rw', default => 1 );
has 'include_in_all'    => ( isa => 'Bool', is => 'rw', default => 1 );

has 'dynamic_templates' => ( isa => DynamicTemplates, is => 'rw' );

has 'index_id'                   => ( isa => 'Bool', is => 'rw' );
has 'disable_source'             => ( isa => 'Bool', is => 'rw' );
has 'disable_source_compression' => ( isa => 'Bool', is => 'rw' );
has 'disable_all'                => ( isa => 'Bool', is => 'rw' );
has 'routing_required'           => ( isa => 'Bool', is => 'rw' );
has 'index_index'                => ( isa => 'Bool', is => 'rw' );
has 'enable_size'                => ( isa => 'Bool', is => 'rw' );
has 'disable_indexing'           => ( isa => 'Bool', is => 'rw' );

has 'enable_timestamp' => ( isa => 'Bool', is => 'rw', lazy_build => 1 );
has 'enable_ttl'       => ( isa => 'Bool', is => 'rw', lazy_build => 1 );

has 'source_includes'  => ( isa => 'ArrayRef[Str]', is => 'rw' );
has 'source_excludes'  => ( isa => 'ArrayRef[Str]', is => 'rw' );
has 'analyzer_path'    => ( isa => 'Str',           is => 'rw' );
has 'boost_path'       => ( isa => 'Str',           is => 'rw' );
has 'id_path'          => ( isa => 'Str',           is => 'rw' );
has 'parent_type'      => ( isa => 'Str',           is => 'rw' );
has 'routing_path'     => ( isa => 'Str',           is => 'rw' );
has 'timestamp_path'   => ( isa => 'Str',           is => 'rw' );
has 'timestamp_format' => ( isa => 'Str',           is => 'rw' );
has 'ttl'              => ( isa => 'Str',           is => 'rw' );

#===================================
sub _build_enable_timestamp {
#===================================
    my $self = shift;
    return $self->ttl || $self->timestamp_path || $self->timestamp_format;
}

#===================================
sub _build_enable_ttl { shift->ttl }
#===================================

#===================================
sub mapping {
#===================================
    my $self            = shift;
    my $properties_only = $_[0];

    my %properties;
    for my $attr ( $self->get_all_attributes ) {
        next if $attr->exclude;
        my $attr_mapping = build_mapping($attr) or next;
        $properties{ $attr->name } = $attr_mapping;
    }
    return \%properties if $properties_only;

    my $type_settings = $self->_type_settings;
    return { %$type_settings, properties => \%properties };
}

#===================================
sub _type_settings {
#===================================
    my $self    = shift;
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
    $mapping{enabled} = 0 if $self->disable_indexing;

    if ( $self->disable_source ) {
        $mapping{_source}{enabled} = 0;
    }
    else {
        $mapping{_source}{compress} = 1
            unless $self->disable_source_compression;
        $mapping{_source}{includes} = $self->source_includes
            if defined $self->source_includes;
        $mapping{_source}{excludes} = $self->source_excludes
            if defined $self->source_excludes;
    }

    $mapping{_all}{enabled}      = 0 if $self->disable_all;
    $mapping{_routing}{required} = 1 if $self->routing_required;
    $mapping{_index}{enabled}    = 1 if $self->index_index;
    $mapping{_size}{enabled}     = 1 if $self->enable_size;

    if ( $self->enable_timestamp ) {
        $mapping{_timestamp}{enabled} = 1;

        $mapping{_timestamp}{format} = $self->timestamp_format
            if $self->timestamp_format;
        $mapping{_timestamp}{path} = $self->timestamp_path
            if $self->timestamp_path;

        if ( $self->enable_ttl ) {
            $mapping{_ttl}{enabled} = 1;
            $mapping{_ttl}{default} = $self->ttl if $self->ttl;
        }

    }

    $mapping{_analyzer}{path} = $self->analyzer_path if $self->analyzer_path;
    $mapping{_boost}{path}    = $self->boost_path    if $self->boost_path;
    $mapping{_id}{path}    = $self->id_path    if $self->id_path;
    $mapping{_routing}{path}  = $self->routing_path  if $self->routing_path;
    $mapping{_parent}{type}   = $self->parent_type   if $self->parent_type;

    return \%mapping;
}

1;
