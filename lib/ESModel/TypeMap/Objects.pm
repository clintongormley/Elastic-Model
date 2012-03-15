package ESModel::TypeMap::Objects;

use ESModel::TypeMap::Base qw(:all);
use Scalar::Util qw(reftype);
use Moose::Util qw(does_role);
use namespace::autoclean;

#===================================
has_type 'Moose::Meta::TypeConstraint::Class',
#===================================
    deflate_via { _deflate_class(@_) },
    inflate_via { _inflate_class(@_) },
    map_via { _map_class(@_) };

#===================================
has_type 'Moose::Meta::TypeConstraint::Role',
#===================================
    deflate_via {undef}, inflate_via {undef};

#===================================
has_type 'Object',    ### TODO: Completely broken, needs rewriting
#===================================
    deflate_via {     ## TODO: Object deflator/inflator
    sub {             ## Moose class?
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

    map_via {
    (   type       => 'object',
        dynamic    => 1,
        properties => { __CLASS__ => { type => 'string', index => 'no' } }
    );
    };

#===================================
sub _deflate_class {
#===================================
    my ( $tc, $attr, $map ) = @_;
    my $class = $tc->name;
    if ( my $handler = $map->deflators->{$class} ) {
        return $handler->(@_);
    }

    die "Class $class is not a Moose class and no deflator is defined."
        unless $class->isa('Moose::Object');

    my $attrs = _class_attrs( $map, $class, $attr );

    # TODO: make sure ESDocs have UID, and make them a reference

    return $map->class_deflator( $class, $attrs );
}

#===================================
sub _inflate_class {
#===================================
    my ( $tc, $attr, $map ) = @_;
    my $class = $tc->name;

    my $custom = $map->inflators->{$class};

    die "Class $class is not a Moose class and no inflator is defined."
        unless $custom || $class->isa('Moose::Object');

    my $attr_inflator;

    return sub {
        my ( $hash, $model ) = @_;
        if ( $hash->{uid} && $model->knows_class($class) ) {
            my $uid = ESModel::UID->new( %{ $hash->{uid} }, from_store => 1 );
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

    my $class = $tc->name;
    if ( my $handler = $map->mappers->{$class} ) {
        return $handler->(@_);
    }

    die "Class $class is not a Moose class and no mapper is defined."
        unless $class->isa('Moose::Object');

    return ( type => 'object', enabled => 0 )
        if $attr->has_enabled && !$attr->enabled;

    my $attrs = _class_attrs( $map, $class, $attr );
    return $map->class_mapping( $class, $attrs );
}

#===================================
sub _class_attrs {
#===================================
    my ( $map, $class, $attr ) = @_;
    my $meta = $class->meta;

    return { map { $_->name => $_ } $meta->get_all_attributes }
        unless does_role( $meta, 'ESModel::Meta::Class::DocType' );

    my %attrs;

    my $wrapper = $map->model->class_for($class);
    my $wrapper_meta = $wrapper ? $wrapper->meta : $meta;

    my $inc = $attr->include_attrs;
    my $exc = $attr->exclude_attrs;

    my @inc_attr = $inc
        ? map {
        $wrapper_meta->find_attribute_by_name($_)
            or die "Unknown attribute ($_) in class $class"
        } @$inc
        : $meta->get_all_attributes;

    %attrs = map { $_->name => $_ } grep { !$_->exclude } @inc_attr;
    delete @attrs{@$exc} if $exc;

    $attrs{uid} = $wrapper_meta->find_attribute_by_name('uid')
        if $wrapper;

    return \%attrs;
}

1;
