package ESModel::TypeMap::Objects;

use ESModel::TypeMap::Base qw(:all);
use Scalar::Util qw(reftype);
use Moose::Util qw(does_role);
use ESModel::Ref();

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
has_type 'Object',
#===================================
    deflate_via {    ## TODO: Object deflator/inflator
    sub {            ## Moose class?
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

    my $attrs = _class_attrs( $class, $attr );

    # TODO: make sure ESDocs have UID, and make them a reference

    return $map->class_deflator( $class, $attrs );
}

#===================================
sub _inflate_class {
#===================================
    my ( $tc, $attr, $map ) = @_;
    my $class = $tc->name;
    if ( $class->does('ESModel::Role::Doc') ) {
        return sub {
            my ( $val, $model ) = @_;
            my %uid_vals = ( %{ $val->{uid} }, from_store => 1 );
            ESModel::Ref->new(
                uid   => ESModel::UID->new(%uid_vals),
                model => $model
            );
        };
    }
    if ( my $handler = $map->inflators->{$class} ) {
        return $handler->(@_);
    }

    die "Class $class is not a Moose class and no inflator is defined."
        unless $class->isa('Moose::Object');

    my $inflator = $map->class_inflator($class);
    return sub {
        my ( $hash, $model ) = @_;
        my $obj = $class->meta->get_meta_instance->create_instance;
        $inflator->( $obj, $hash, $model );
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

    my $attrs = _class_attrs( $class, $attr );
    return $map->class_mapping( $class, $attrs );
}

#===================================
sub _class_attrs {
#===================================
    my ( $class, $attr ) = @_;

    my $meta = $class->meta;
    my %attrs;

    if ( does_role( $class, 'ESModel::Role::Doc' ) ) {
        my $inc = $attr->include_attrs;
        my $exc = $attr->exclude_attrs;

        %attrs = map { $_->name => $_ } grep { !$_->exclude } (
            $inc
            ? map {
                $meta->find_attribute_by_name($_)
                    or die "Unknown attribute ($_) in class $class"
                } @$inc
            : $meta->get_all_attributes
        );

        delete @attrs{@$exc} if $exc;

        if ( my $uid = $meta->find_attribute_by_name('uid') ) {
            $attrs{uid} = $uid;
        }
    }
    else {
        %attrs = map { $_->name => $_ } $meta->get_all_attributes;
    }
    return \%attrs;
}

1;
