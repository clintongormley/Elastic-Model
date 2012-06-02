package Elastic::Model::TypeMap::Objects;

use Elastic::Model::TypeMap::Base qw(:all);
use Scalar::Util qw(reftype);
use Moose::Util qw(does_role);
use namespace::autoclean;

#===================================
has_type 'Moose::Meta::TypeConstraint::Class',
#===================================
    deflate_via { _deflate_class(@_) },
    inflate_via { _inflate_class(@_) },
    map_via { _map_class(@_) };

#TODO: Moose role
# dynamic-off, map known attr
# all attributes
# __CLASS__

#===================================
has_type 'Moose::Meta::TypeConstraint::Role',
#===================================
    deflate_via {undef}, inflate_via {undef};

#===================================
has_type 'Object',
#===================================
    deflate_via {
    sub {
        my $obj = shift;
        my $ref = ref $obj;

        die "$ref does not provide a deflate() method"
            unless $obj->can('deflate');

        my $deflated = $obj->deflate();

        die "${ref}->deflate() should return a HASH ref"
            unless reftype $deflated eq 'HASH';

        $deflated->{__CLASS__} ||= ref $obj;
        return $deflated;
        }
    },

    inflate_via {
    sub {
        my $hash  = shift;
        my $class = delete $hash->{__CLASS__}
            or die "Object missing __CLASS__ key";
        $class->inflate($hash);    ## TODO: bless?
        }
    },

    map_via { type => 'object', enabled => 0 };

#===================================
sub _deflate_class {
#===================================
    my ( $tc, $attr, $map ) = @_;
    return if $tc->is_a_type_of('MooseX::Types::UndefinedType');

    my $class = $tc->name;
    if ( my $handler = $map->deflators->{$class} ) {
        return $handler->(@_);
    }

    my $attrs = _class_attrs( $map, $class, $attr );

    # TODO: make sure ESDocs have UID, and make them a reference

    return $map->class_deflator( $class, $attrs );
}

#===================================
sub _inflate_class {
#===================================
    my ( $tc, $attr, $map ) = @_;
    return if $tc->is_a_type_of('MooseX::Types::UndefinedType');

    my $class = $tc->name;

    my $custom = $map->inflators->{$class};

    my $attr_inflator;

    return sub {
        my ( $hash, $model ) = @_;
        if ( $hash->{uid} && $model->knows_class($class) ) {
            my $uid = Elastic::Model::UID->new( %{ $hash->{uid} },
                from_store => 1 );
            return $model->get_doc($uid);
        }

        return $custom->(@_) if $custom;

        $attr_inflator ||= $map->class_inflator($class);

        my $obj = $class->meta->get_meta_instance->create_instance;
        $attr_inflator->( $obj, $hash, $model );
    };

    # TODO: decide what to do with non-ES classes
    # TODO: inflate objects as references
}

#===================================
sub _map_class {
#===================================
    my ( $tc, $attr, $map ) = @_;
    return if $tc->is_a_type_of('MooseX::Types::UndefinedType');

    my $class = $tc->name;
    if ( my $handler = $map->mappers->{$class} ) {
        return $handler->(@_);
    }

    return ( type => 'object', enabled => 0 )
        if $attr->can('has_enabled') && $attr->has_enabled && !$attr->enabled;

    my $attrs = _class_attrs( $map, $class, $attr );
    return $map->class_mapping( $class, $attrs );
}

#===================================
sub _class_attrs {
#===================================
    my ( $map, $class, $attr ) = @_;

    $class = $map->model->class_for($class) || $class;

    my $meta = Class::MOP::class_of($class);
    die "Class ($class) is not a Moose class\n"
        unless $meta && $meta->isa('Moose::Meta::Class');

    my %attrs;

    my $inc = $attr->can('include_attrs') && $attr->include_attrs;
    my $exc = $attr->can('exclude_attrs') && $attr->exclude_attrs;

    my @inc_attr = $inc
        ? map {
        $meta->find_attribute_by_name($_)
            or die "Unknown attribute ($_) in class $class"
        } @$inc
        : $meta->get_all_attributes;

    %attrs = map { $_->name => $_ }
        grep { !( $_->can('exclude') && $_->exclude ) } @inc_attr;

    delete @attrs{@$exc} if $exc;

    if ( my $uid = $meta->find_attribute_by_name('uid') ) {
        $attrs{uid} = $uid;
    }

    return \%attrs;
}

1;

# ABSTRACT: Type maps for objects and Moose classes

=head1 DESCRIPTION

L<Elastic::Model::TypeMap::Objects> provides mapping, inflation and deflation
for Moose-based classes and objects .
It is loaded automatically byL<Elastic::Model::TypeMap::Default>.

=head1 TYPES

=head2 Class

=head3 Non-Moose classes

Non-Moose classes must provide custom mappings, deflators and inflators.
