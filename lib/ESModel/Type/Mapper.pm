package ESModel::Type::Mapper;

use Moose;
use Moose::Exporter;
use Moose::Util qw(does_role);
use Moose::Util::TypeConstraints;
use Carp;
use Data::Dump qw(pp);
use List::MoreUtils qw(uniq);
use Class::Load qw(load_class);

sub via (&);

Moose::Exporter->setup_import_methods(
    as_is => [ 'build_mapping', 'map_constraint', 'add_mapper' ], );

our %Mappers = (
    'Bool'                                       => \&_bool_mapping,
    'Str'                                        => \&_str_mapping,
    'Num'                                        => \&_num_mapping,
    'Int'                                        => \&_int_mapping,
    'ClassName'                                  => \&_keyword_mapping,
    'RoleName'                                   => \&_keyword_mapping,
    'RegexpRef'                                  => \&_keyword_mapping,
    'Maybe'                                      => \&_type_param_mapping,
    'ArrayRef'                                   => \&_type_param_mapping,
    'ScalarRef'                                  => \&_type_param_mapping,
    'HashRef'                                    => \&_hashref_mapping,
    'DateTime'                                   => \&_date_mapping,
    'Moose::Meta::TypeConstraint::Class'         => \&_class_mapping,
    'Moose::Meta::TypeConstraint::Enum'          => \&_keyword_mapping,
    'Moose::Meta::TypeConstraint::Parameterized' => \&_parameterized_mapping,
    'MooseX::Meta::TypeConstraint::Structured'   => \&_parameterized_mapping,
    'MooseX::Types::TypeDecorator'               => \&_decorated_mapping,
    'MooseX::Types::Structured::Optional'        => \&_type_param_mapping,
    'MooseX::Types::Structured::Tuple'           => \&_tuple_mapping,
    'MooseX::Types::Structured::Dict'            => \&_dict_mapping,
    'MooseX::Types::Structured::Map'             => \&_hashref_mapping,
    'ESModel::Types::GeoPoint'                   => \&_geopoint_mapping,
    'ESModel::Types::Binary'                     => \&_binary_mapping,
);

our %Allowed_Attrs = (
    string => {
        'index_name'                   => 1,
        'store'                        => 1,
        'index'                        => 1,
        'term_vector'                  => 1,
        'boost'                        => 1,
        'null_value'                   => 1,
        'omit_norms'                   => 1,
        'omit_term_freq_and_positions' => 1,
        'analyzer'                     => 1,
        'index_analyzer'               => 1,
        'search_analyzer'              => 1,
        'include_in_all'               => 1,
        'multi'                        => 1,
    },
    integer => {
        'type'           => 1,
        'index_name'     => 1,
        'store'          => 1,
        'index'          => 1,
        'precision_step' => 1,
        'boost'          => 1,
        'null_value'     => 1,
        'include_in_all' => 1,
        'multi'          => 1,
    },
    date => {
        'index_name'     => 1,
        'format'         => 1,
        'store'          => 1,
        'index'          => 1,
        'precision_step' => 1,
        'boost'          => 1,
        'null_value'     => 1,
        'include_in_all' => 1,
        'multi'          => 1,
    },
    boolean => {
        'index_name'     => 1,
        'store'          => 1,
        'index'          => 1,
        'boost'          => 1,
        'null_value'     => 1,
        'include_in_all' => 1,
        'multi'          => 1,
    },
    binary => { 'index_name' => 1 },
    object => {
        'dynamic'        => 1,
        'enabled'        => 1,
        'path'           => 1,
        'include_in_all' => 1,
    },
    nested => {
        'include_in_parent' => 1,
        'include_in_root'   => 1,
        'include_in_all'    => 1,
        'dynamic'           => 1,
        'enabled'           => 1,
        'path'              => 1,
    },
    ip => {
        'index_name'     => 1,
        'store'          => 1,
        'index'          => 1,
        'precision_step' => 1,
        'boost'          => 1,
        'null_value'     => 1,
        'include_in_all' => 1,
    },
    geopoint => {
        'lat_lon'           => 1,
        'geohash'           => 1,
        'geohash_precision' => 1,
    },

    #    attachment => {}
);

our @All_Keys = uniq map { keys %$_ } values %Allowed_Attrs;

$Allowed_Attrs{$_} = $Allowed_Attrs{integer}
    for qw(long float double short byte);

#===================================
sub build_mapping {
#===================================
    my $attr = shift;
    my $is_esmodel
        = does_role( $attr, 'ESModel::Meta::Attribute::Trait::Field' );

    my ($type);
    if ($is_esmodel) {
        $type = $attr->type;
        if ( my $mapping = $attr->mapping ) {
            $mapping->{type} ||= $type;
            croak "Attribute '"
                . $attr->name
                . "' has a 'mapping' but no 'type'"
                unless $mapping->{type};
            return $mapping;
        }
    }

    my %mapping = map_constraint( $attr->type_constraint );
    $mapping{type} = $type if $type;
    $type = $mapping{type}
        or croak "Couldn't find a default mapping for attribute: "
        . $attr->name;

    return \%mapping
        unless does_role( $attr, 'ESModel::Meta::Attribute::Trait::Field' );

    my $allowed = $Allowed_Attrs{$type};
    for my $key (@All_Keys) {
        my $val = $attr->$key;
        next unless defined $val;
        croak "Attribute '"
            . $attr->name
            . "' has type '$type', which doesn't "
            . "understand '$key'"
            unless $allowed->{$key};
        $mapping{$key} = $val;
    }

    delete $mapping{analyzer}
        if $mapping{index_analyzer} && $mapping{search_analyzer};

    return $mapping{multi}
        ? _multi_field( $attr, \%mapping )
        : \%mapping;

}

#===================================
sub _multi_field {
#===================================
    my $self      = shift;
    my %main      = %{ shift() };
    my $multi     = delete $main{multi};
    my $main_name = $self->name;
    my $type      = $main{type};
    my %mapping
        = ( type => 'multi_field', fields => { $main_name => \%main } );
    for my $name ( keys %$multi ) {
        croak "Multi-field name '$name' clashes with the attribute name\n"
            if $name eq $main_name;
        my $defn = $multi->{$name};
        $defn->{type} ||= $type;
        $mapping{fields}{$name} = $defn;
    }
    return \%mapping;
}

#===================================
sub add_mapper {
#===================================
    my ($class,$sub) = @_;
    $Mappers{$class} = $sub;
}

#===================================
sub map_constraint {
#===================================
    my $tc = shift || find_type_constraint('Str');

#    print STDERR "TC: " . pp( { name => $tc->name, ref => ref $tc } ) . "\n";
    my $name = $tc->name;

    if ( my $handler = $Mappers{$name} || $Mappers{ ref $tc } ) {
        return $handler->($tc);
    }
    my $parent = $tc->parent or return;
    return map_constraint($parent);
}

#===================================
sub _bool_mapping     { type => 'boolean' }
sub _str_mapping      { type => 'string' }
sub _num_mapping      { type => 'long' }
sub _int_mapping      { type => 'integer' }
sub _keyword_mapping  { type => 'string', index => 'not_analyzed' }
sub _hashref_mapping  { type => 'object', dynamic => 1 }
sub _date_mapping     { type => 'date' }
sub _geopoint_mapping { type => 'geo_point' }
sub _binary_mapping   { type => 'binary' }
#===================================

#===================================
sub _type_param_mapping { map_constraint shift->type_parameter }
sub _decorated_mapping  { map_constraint shift->__type_constraint }
#===================================

#===================================
sub _parameterized_mapping {
#===================================
    my $tc     = shift;
    my $parent = $tc->parent;

#    print STDERR 'PARAM: '. pp( { name => $parent->name, ref => ref $parent } ) . "\n";
    if ( my $handler = $Mappers{ $parent->name } ) {
        return $handler->($tc);
    }
    return map_constraint($parent);
}

#===================================
sub _dict_mapping { _sub_fields( @{ shift->type_constraints } ) }
#===================================

#===================================
sub _tuple_mapping {
#===================================
    my $i = 0;
    _sub_fields( map { $i++ => $_ } @{ shift->type_constraints } );
}
#===================================
sub _sub_fields {
#===================================
    my %dict = @_;
    my %properties;
    for my $key ( keys %dict ) {
        my $tc = find_type_constraint $dict{$key};
        $properties{$key} = { map_constraint $tc };
    }
    return (
        type       => 'object',
        dynamic    => 'strict',
        properties => \%properties
    );
}

#===================================
sub _class_mapping {
#===================================
    my $tc    = shift;
    my $class = $tc->name;
    load_class($class);

    croak "$class is not a Moose class, and no mapper is available"
        unless $class->isa('Moose::Object');

    my $meta = $class->meta;

    return (
        type       => 'object',
        dynamic    => $meta->dynamic,
        properties => $meta->mapping('only_properties'),
    ) if does_role( $class, 'ESModel::Role::Type' );

    my %properties;
    for my $attr ( $meta->get_all_attributes ) {
        my $attr_mapping = build_mapping($attr) or next;
        $properties{ $attr->name } = $attr_mapping;
    }
    return (
        type       => 'object',
        dynamic    => 'strict',
        properties => \%properties,
    );

}
1;
