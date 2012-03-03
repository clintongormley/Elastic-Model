package ESModel::Meta::Class::Doc;

use Moose::Role;
use namespace::autoclean;
use MooseX::Types::Moose qw(:all);
use ESModel::Doc::Mapper qw(build_mapping);
use ESModel::Types qw(DynamicTemplates DynamicMapping);
use Carp;

has 'type' => ( isa => Str, is => 'ro', writer => '_set_type' );
has 'type_settings' => (
    isa     => HashRef,
    is      => 'rw',
    default => sub { {} }
);

has 'analyzer'        => ( isa => Str, is => 'rw' );
has 'index_analyzer'  => ( isa => Str, is => 'rw' );
has 'search_analyzer' => ( isa => Str, is => 'rw' );
has 'dynamic_date_formats' => ( isa => ArrayRef [Str], is => 'rw' );

has 'dynamic' => ( isa => DynamicMapping, is => 'rw', default => 'strict' );

has 'date_detection'    => ( isa => Bool, is => 'rw', default => 1 );
has 'numeric_detection' => ( isa => Bool, is => 'rw', default => 1 );
has 'include_in_all'    => ( isa => Bool, is => 'rw', default => 1 );

has 'dynamic_templates' => ( isa => DynamicTemplates, is => 'rw' );

has 'index_id'                   => ( isa => Bool, is => 'rw' );
has 'disable_source_compression' => ( isa => Bool, is => 'rw' );
has 'disable_all'                => ( isa => Bool, is => 'rw' );
has 'routing_required'           => ( isa => Bool, is => 'rw' );
has 'index_index'                => ( isa => Bool, is => 'rw' );
has 'enable_size'                => ( isa => Bool, is => 'rw' );
has 'disable_indexing'           => ( isa => Bool, is => 'rw' );

has 'source_includes' => ( isa => ArrayRef [Str], is => 'rw' );
has 'source_excludes' => ( isa => ArrayRef [Str], is => 'rw' );
has 'analyzer_path' => ( isa => Str, is => 'rw' );
has 'boost_path'    => ( isa => Str, is => 'rw' );
has 'id_path'       => ( isa => Str, is => 'rw' );
has 'parent_type'   => ( isa => Str, is => 'rw' );
has 'routing_path'  => ( isa => Str, is => 'rw' );
has 'ttl'           => ( isa => Str, is => 'rw' );
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
around 'add_attribute' => sub {
#===================================
    my $orig = shift;
    my $attr = $orig->(@_);

    my $meta      = $attr->associated_class;
    my $attr_name = $attr->name;

    $meta->required_attrs->{$attr_name} = $attr->init_arg || $attr_name
        if $attr->_is_required && !$attr->has_default && !$attr->has_builder;

    unless ( $attr->exclude ) {
        my %methods;
        for (qw(get_read_method get_write_method  predicate clearer)) {
            my $name = $attr->$_ or next;
            $methods{$name}++;
        }
        for my $method ( @{ $attr->associated_methods } ) {
            my $name = $method->name;
            next unless $methods{$name};
            $meta->add_before_method_modifier( $name,
                sub { $_[0]->_inflated || $_[0]->_load_data } );
        }
    }
    return $attr;
};

sub _inline_has_value {
    return ('$_[0]->_inflated || $_[0]->_load_data;', shift->SUPER::_inline_has_value(@_));
}

#===================================
around '_process_attribute' => sub {
#===================================
    my $orig = shift;
    my ( $self, $name, @args ) = @_;

    @args = %{$args[0]} if scalar @args == 1 && ref($args[0]) eq 'HASH';

    if (($name || '') =~ /^\+(.*)/) {
        return $self->_process_inherited_attribute($1, @args);
    }
    else {
        return $self->_process_new_attribute($name, @args);
    }
       my $attr = $orig->(@_);
    $attr;
};


#===================================
sub property_mapping {
#===================================
    my $self = shift;
    my %inc = map { $_ => 1 } $_[0] ? @{ $_[0] } : $self->get_attribute_list;
    delete @inc{ @{ $_[1] } } if $_[1];

    my %properties;
    %properties = (
        routing => { type => 'string', index => 'no' },
        map {
            $_ => {
                type                         => 'string',
                index                        => 'not_analyzed',
                omit_norms                   => 1,
                omit_term_freq_and_positions => 1
                }
            } qw(index type id)
    ) if $inc{uid};

    for my $name ( keys %inc ) {
        my $attr = $self->get_attribute($name);
        next if $attr->exclude;
        my $attr_mapping = build_mapping($attr) or next;
        $properties{ $attr->name } = $attr_mapping;
    }
    return \%properties;
}

#===================================
sub root_mapping {
#===================================
    my $self    = shift;
    my %mapping = %{ $self->type_settings };
    $mapping{properties} = $self->property_mapping( undef, ['uid'] );

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
