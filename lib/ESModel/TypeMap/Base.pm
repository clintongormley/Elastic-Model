package ESModel::TypeMap::Base;

use strict;
use warnings;

use Sub::Exporter qw(build_exporter);
use Class::MOP();
use List::MoreUtils qw(uniq);
use Moose::Util qw(does_role);
use Scalar::Util qw(blessed);
use namespace::autoclean;

sub deflate_via (&) { deflator => $_[0] }
sub inflate_via (&) { inflator => $_[0] }
sub map_via (&)     { mapper   => $_[0] }

#===================================
sub import {
#===================================
    my ( $class, @args ) = @_;
    my $callee = caller;
    return if $callee->isa(__PACKAGE__) || @args == 0;

    {
        no strict 'refs';
        unshift @{ $callee . '::ISA' }, __PACKAGE__;
    }

    build_exporter( {
            into    => $callee,
            exports => [
                qw(deflate_via inflate_via map_via),
                has_type => sub {
                    sub { $callee->_has_type(@_) }
                },
            ]
        }
    )->( $class, ':all' );

    for (@args) {
        next if /^[:-]/;
        Class::MOP::load_class($_);
        $callee->import_types( $_->type_map );
    }
}

#===================================
sub find_deflator {
#===================================
    my ( $map, $attr ) = @_;
    my $deflator = $attr->deflator if $attr->can('deflator');
    return
           $deflator
        || eval { $map->find( 'deflator', $attr->type_constraint, $attr ) }
        || die _type_error( 'deflator', $attr, $@ );
}

#===================================
sub find_inflator {
#===================================
    my ( $map, $attr ) = @_;
    my $inflator = $attr->inflator if $attr->can('inflator');
    return
           $inflator
        || eval { $map->find( 'inflator', $attr->type_constraint, $attr ) }
        || die _type_error( 'inflator', $attr, $@ );
}

#===================================
sub find_mapper {
#===================================
    my ( $map, $attr ) = @_;
    my $mapping = $attr->mapping if $attr->can('mapping');
    return $mapping if $mapping && %$mapping;
    my %mapping
        = eval { $map->find( 'mapper', $attr->type_constraint, $attr ); };
    die _type_error( 'mapper', $_[1], $@ )
        unless %mapping;
    return %mapping;
}

#===================================
sub _type_error {
#===================================
    my ( $type, $attr, $error ) = @_;
    my $name  = $attr->name;
    my $class = $attr->associated_class->name;
    return $error
        ? "Error finding $type for attribute ($name) in class $class:\n$error"
        : "No $type found for attribute ($name) in class $class";
}

#===================================
sub find {
#===================================
    my ( $map, $type, $tc, $attr ) = @_;

    die "No type constraint found"
        unless $tc;

    my $types    = $type . 's';
    my $handlers = $map->$types;
    my $name     = $tc->name;

    if ( my $handler = $handlers->{$name} || $handlers->{ ref $tc } ) {
        return $handler->( $tc, $attr, $map );
    }
    my $parent = $tc->parent or return;
    $map->find( $type, $parent, $attr );
}

#===================================
sub class_deflator {
#===================================
    my ( $map, $class, $attrs ) = @_;

    if ( my $handler = $map->deflators->{$class} ) {
        return $handler->(@_);
    }

    $attrs ||= $map->indexable_attrs($class);
    my %deflators = map { $_ => $map->find_deflator( $attrs->{$_} ) }
        keys %$attrs;

    my $has_uid = $class->can('uid');
    return sub {
        my ( $obj, $model ) = @_;
        my %hash;
        my $meta = $obj->meta;
        for ( keys %deflators ) {
            my $attr = $attrs->{$_};
            unless ( $attr->has_value($obj) ) {
                next unless $attr->has_builder;
                my $reader = $attr->get_read_method_ref;
                $obj->$reader;
            }
            my $val = $attr->get_raw_value($obj);
            eval { $hash{$_} = $deflators{$_}->( $val, $model ); 1 } and next;
            die "Error deflating attribute ($_) in class "
                . blessed($obj) . ":\n  "
                . ( $@ || 'Unknown error' );
        }
        return \%hash;
    };
}

#===================================
sub class_inflator {
#===================================
    my ( $map, $class, $attrs ) = @_;

    if ( my $handler = $map->inflators->{$class} ) {
        return $handler->(@_);
    }

    $attrs ||= $map->indexable_attrs($class);
    my %inflators = map { $_ => $map->find_inflator( $attrs->{$_} ) }
        keys %$attrs;

    return sub {
        my ( $obj, $hash, $model ) = @_;
        for ( keys %$hash ) {
            my $attr = $attrs->{$_} or next;
            my $val = $inflators{$_}->( $hash->{$_}, $model );
            $attr->set_raw_value( $obj, $val );
            $attr->_weaken_value($obj) if $attr->is_weak_ref;
            # TODO: what about non ES objects?
        }
        return $obj;
    };
}

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

    # TODO:   attachment => {}
);

our @All_Keys = uniq map { keys %$_ } values %Allowed_Attrs;

$Allowed_Attrs{$_} = $Allowed_Attrs{integer}
    for qw(long float double short byte);

# TODO handle custom mapping, deflator,inflator per class

#===================================
sub class_mapping {
#===================================
    my ( $map, $class, $attrs ) = @_;

    #    if ( my $handler = $map->mappers->{$class} ) {
    #        return $handler->(@_);
    #    }

    my ($wrapper);
    if ( does_role( $class, 'ESModel::Role::Doc' ) ) {
        $wrapper = $class;
        $class   = $wrapper->meta->original_class;
    }
    else {
        $wrapper = $map->model->class_wrapper($class);
    }
    $attrs ||= $map->indexable_attrs( $wrapper || $class );

    my %props = map { $_ => $map->attribute_mapping( $attrs->{$_} ) }
        keys %$attrs;

    my $meta = $class->meta;
    my $dynamic = $meta->can('dynamic') && $meta->dynamic || 'strict';
    return (
        type       => 'object',
        dynamic    => $dynamic,
        properties => \%props
    );
}

#===================================
sub attribute_mapping {
#===================================
    my ( $map, $attr ) = @_;

    my $mapping = $attr->can('mapping') && $attr->mapping
        || { $map->find_mapper($attr) };

    my $type    = $mapping->{type}      or die "Missing field type";
    my $allowed = $Allowed_Attrs{$type} or die "Unknown field type ($type)";

    return $mapping unless does_role( $attr, 'ESModel::Trait::Field' );

    for my $key (@All_Keys) {
        my $val = $attr->$key;
        next unless defined $val;
        die "Attribute has type '$type', which doesn't "
            . "understand '$key'\n"
            unless $allowed->{$key};
        $mapping->{$key} = $val;
    }

    delete $mapping->{analyzer}
        if $mapping->{index_analyzer} && $mapping->{search_analyzer};

    my $multi = delete $mapping->{multi}
        or return $mapping;

    my $main = $attr->name;
    my %new = ( type => 'multi_field', fields => { $main => $mapping } );
    for my $name ( keys %$multi ) {
        die "Multi-field name '$name' clashes with the attribute name\n"
            if $name eq $main;
        my $defn = $multi->{$name};
        $defn->{type} ||= $type;
        $new{fields}{$name} = $defn;
    }
    return \%new;
}

#===================================
sub deflators { shift->type_map->{deflator} }
sub inflators { shift->type_map->{inflator} }
sub mappers   { shift->type_map->{mapper} }
#===================================

#===================================
sub _has_type {
#===================================
    my ( $class, $type, %params ) = @_;
    my $map = $class->type_map();
    for ( keys %params ) {
        $map->{$_}{$type} = $params{$_};
    }
}

#===================================
sub indexable_attrs {
#===================================
    my $self  = shift;
    my $class = shift;
    my $meta  = $class->meta;
    return {
        map { $_->name => $_ }
        grep { !$_->exclude } $meta->get_all_attributes
    };
}

#===================================
sub type_map {
#===================================
    my $class = shift;
    $class = $class->meta->original_class
        if $class->can('meta') && $class->meta->can('original_class');

    # return a reference to the storage in ourself
    {
        no strict 'refs';
        return \%{ $class . '::__ES_TYPE_MAP' };
    }
}

#===================================
sub import_types {
#===================================
    my $class  = shift;
    my $import = shift;
    my $map    = $class->type_map;
    for (qw(deflator inflator mapper)) {
        my $types = $import->{$_} or next;
        @{ $map->{$_} }{ keys %$types } = values %$types;
    }
}

1;

