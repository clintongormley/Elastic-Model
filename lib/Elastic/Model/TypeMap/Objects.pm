package Elastic::Model::TypeMap::Objects;

use strict;
use warnings;
use Elastic::Model::TypeMap::Base qw(:all);
use Scalar::Util qw(reftype weaken);
use Moose::Util qw(does_role);
use namespace::autoclean;

#===================================
has_type 'Moose::Meta::TypeConstraint::Class',
#===================================
    deflate_via { _deflate_class(@_) },
    inflate_via { _inflate_class(@_) },
    map_via { _map_class(@_) };

# TODO: Moose role

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
        return { $ref => $obj->deflate };
    };
    },

    inflate_via {
    sub {
        my ( $class, $data ) = %{ shift() };
        my $inflated = $class->inflate($data);
        return bless $inflated, $class;
        }
    },

    map_via { type => 'object', enabled => 0 };

#===================================
sub _deflate_class {
#===================================
    my ( $tc, $attr, $map ) = @_;

    my $class = $tc->name;
    my $attrs = _class_attrs( $map, $class, $attr )
        or return;

    return $map->class_deflator( $class, $attrs );
}

#===================================
sub _inflate_class {
#===================================
    my ( $tc, $attr, $map ) = @_;

    my $class = $tc->name;
    if ( $map->model->knows_class($class) ) {
        my $model = $map->model;
        weaken $model;
        return sub {
            my $hash = shift;
            die "Missing UID\n" unless $hash->{uid};
            my $uid = Elastic::Model::UID->new( %{ $hash->{uid} },
                from_store => 1 );
            return $model->get_doc( uid => $uid );
        };
    }

    my $attrs = _class_attrs( $map, $class, $attr )
        or return;

    my $attr_inflator = $map->class_inflator( $class, $attrs );

    return sub {
        my $hash = shift;
        my $obj  = Class::MOP::class_of($class)
            ->get_meta_instance->create_instance;
        $attr_inflator->( $obj, $hash );
    };
}

#===================================
sub _map_class {
#===================================
    my ( $tc, $attr, $map ) = @_;

    return ( type => 'object', enabled => 0 )
        if $attr->can('has_enabled')
            && $attr->has_enabled
            && !$attr->enabled;

    my $class = $tc->name;
    my $attrs = _class_attrs( $map, $class, $attr )
        or return;

    return $map->class_mapping( $class, $attrs );
}

#===================================
sub _class_attrs {
#===================================
    my ( $map, $class, $attr ) = @_;

    $class = $map->model->class_for($class) || $class;

    my $meta = Class::MOP::class_of($class);
    return unless $meta && $meta->isa('Moose::Meta::Class');

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
