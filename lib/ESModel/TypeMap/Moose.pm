package ESModel::TypeMap::Moose;

use ESModel::TypeMap::Base qw(:all);

#===================================
has_type 'Any',
#===================================
    deflate_via {undef}, inflate_via {undef};

#===================================
has_type 'Item',
#===================================
    deflate_via { \&_pass_through }, inflate_via { \&_pass_through };

#===================================
has_type 'Bool',
#===================================
    map_via { type => 'boolean' };

#===================================
has_type 'Str',
#===================================
    map_via { type => 'string' };

#===================================
has_type 'Num',
#===================================
    map_via { type => 'long' };

#===================================
has_type 'Int',
#===================================
    map_via { type => 'integer' };

#===================================
has_type 'Ref',
#===================================
    deflate_via {undef}, inflate_via {undef};

#===================================
has_type 'ScalarRef',
#===================================
    deflate_via {
    sub { $$_[0] }
    },

    inflate_via {
    sub { \$_[0] }
    },

    map_via { _content_handler( 'mapper', @_ ) };

#===================================
has_type 'RegexpRef',
#===================================
    deflate_via {
    sub {"$_[0]"}
    },

    inflate_via {
    sub {qr/$_[0]/}
    },

    map_via { type => 'string', index => 'no' };

#===================================
has_type 'ArrayRef',
#===================================
    deflate_via { _flate_array( 'deflator', @_ ) },
    inflate_via { _flate_array( 'inflator', @_ ) },
    map_via { _content_handler( 'mapper', @_ ) };

#===================================
has_type 'HashRef',
#===================================
    deflate_via { _flate_hash( 'deflator', @_ ) },
    inflate_via { _flate_hash( 'inflator', @_ ) },
    map_via { type => 'object', enabled => 0 };

#===================================
has_type 'Maybe',
#===================================
    deflate_via { _flate_maybe( 'deflator', @_ ) },
    inflate_via { _flate_maybe( 'inflator', @_ ) },
    map_via { _content_handler( 'mapper', @_ ) };

#===================================
has_type 'Moose::Meta::TypeConstraint::Enum',
#===================================
    deflate_via { \&_pass_through }, inflate_via { \&_pass_through },
    map_via { type => 'string', index => 'not_analyzed' };

#===================================
has_type 'MooseX::Types::TypeDecorator',
#===================================
    deflate_via { _decorated( 'deflator', @_ ) },
    inflate_via { _decorated( 'inflator', @_ ) },
    map_via { _decorated( 'mapper', @_ ) };

#===================================
has_type 'Moose::Meta::TypeConstraint::Parameterized',
#===================================
    deflate_via { _parameterized( 'deflator', @_ ) },
    inflate_via { _parameterized( 'inflator', @_ ) },
    map_via { _parameterized( 'mapper', @_ ) };

#===================================
sub _pass_through { $_[0] }
#===================================

#===================================
sub _flate_array {
#===================================
    my $content = _content_handler(@_) or return;
    sub {
        my ( $array, $model ) = @_;
        [ map { $content->( $_, $model ) } @$array ];
    };
}

#===================================
sub _flate_hash {
#===================================
    my $content = _content_handler(@_) or return;
    sub {
        {
            my ( $hash, $model ) = @_;
            map { $content->( $_, $model ) } %$hash
        };
    };
}

#===================================
sub _flate_maybe {
#===================================
    my $content = _content_handler(@_) or return;
    sub {
        my ( $val, $model ) = @_;
        return defined $val ? $content->( $val, $model ) : undef;
    };
}

#===================================
sub _decorated {
#===================================
    my ( $type, $tc, $attr, $map ) = @_;
    $map->find( $type, $tc->__type_constraint, $attr );
}

#===================================
sub _parameterized {
#===================================
    my ( $type, $tc, $attr, $map ) = @_;
    my $types  = $type . 's';
    my $parent = $tc->parent;
    if ( my $handler = $map->$types->{ $parent->name } ) {
        return $handler->( $tc, $attr, $map );
    }
    $map->find( $type, $parent, $attr );
}

#===================================
sub _content_handler {
#===================================
    my ( $type, $tc, $attr, $map ) = @_;
    return unless $tc->can('type_parameter');
    return $map->find( $type, $tc->type_parameter, $attr );
}

1;
