package ESModel::Type::Deflator;

use Moose;
use Moose::Exporter;
use Moose::Util qw(does_role);
use Moose::Util::TypeConstraints;
use Carp;
use Data::Dump qw(pp);
use List::MoreUtils qw(uniq zip);
use Class::Load qw(load_class);
use Scalar::Util qw(reftype);

Moose::Exporter->setup_import_methods(
    as_is => [ 'find_deflator', 'find_inflator' ] );

our %Deflators = (
    'Any'                                        => \&_deflate_no,
    'Item'                                       => \&_deflate_no,
    'Object'                                     => \&_deflate_object,
    'ScalarRef'                                  => \&_deflate_scalar,
    'ArrayRef'                                   => \&_deflate_array,
    'HashRef'                                    => \&_deflate_hash,
    'RegexpRef'                                  => \&_deflate_regex,
    'Ref'                                        => \&_deflate_cant,
    'Maybe'                                      => \&_deflate_maybe,
    'DateTime'                                   => \&_deflate_datetime,
    'Moose::Meta::TypeConstraint::Class'         => \&_deflate_class,
    'Moose::Meta::TypeConstraint::Enum'          => \&_deflate_no,
    'Moose::Meta::TypeConstraint::Parameterized' => \&_deflate_parameterized,
    'MooseX::Meta::TypeConstraint::Structured'   => \&_deflate_parameterized,
    'MooseX::Types::TypeDecorator'               => \&_deflate_decorated,
    'MooseX::Types::Structured::Optional'        => \&_deflate_type_param,
    'MooseX::Types::Structured::Tuple'           => \&_deflate_tuple,
    'MooseX::Types::Structured::Dict'            => \&_deflate_dict,
    'MooseX::Types::Structured::Map'             => \&_deflate_hashref,
    'ESModel::Types::GeoPoint'                   => \&_deflate_geopoint,
    'ESModel::Types::Binary'                     => \&_deflate_binary,
);

our %Inflators = (
    'Any'                                        => \&_inflate_no,
    'Item'                                       => \&_inflate_no,
    'Object'                                     => \&_inflate_object,
    'ScalarRef'                                  => \&_inflate_scalar,
    'ArrayRef'                                   => \&_inflate_array,
    'HashRef'                                    => \&_inflate_hash,
    'RegexpRef'                                  => \&_inflate_regex,
    'Ref'                                        => \&_inflate_cant,
    'Maybe'                                      => \&_inflate_maybe,
    'DateTime'                                   => \&_inflate_datetime,
    'Moose::Meta::TypeConstraint::Class'         => \&_inflate_class,
    'Moose::Meta::TypeConstraint::Enum'          => \&_inflate_no,
    'Moose::Meta::TypeConstraint::Parameterized' => \&_inflate_parameterized,
    'MooseX::Meta::TypeConstraint::Structured'   => \&_inflate_parameterized,
    'MooseX::Types::TypeDecorator'               => \&_inflate_decorated,
    'MooseX::Types::Structured::Optional'        => \&_inflate_type_param,
    'MooseX::Types::Structured::Tuple'           => \&_inflate_tuple,
    'MooseX::Types::Structured::Dict'            => \&_inflate_dict,
    'MooseX::Types::Structured::Map'             => \&_inflate_hashref,
    'ESModel::Types::GeoPoint'                   => \&_inflate_geopoint,
    'ESModel::Types::Binary'                     => \&_inflate_binary,
);

our %Inline = (

);

#===================================
sub find_deflator {
#===================================
    my $attr = shift;
    my $deflator;
    eval { $deflator = _find_deflator( $attr->type_constraint ); 1 }
        or croak "No deflator found for attribute '"
        . $attr->name
        . '" in class '
        . $attr->associated_class->name;
    return $deflator;
}

#===================================
sub _find_deflator {
#===================================
    my $tc = shift || find_type_constraint('Any');

    my $name = $tc->name;

    if ( my $handler = $Deflators{$name} || $Deflators{ ref $tc } ) {
        return $handler->($tc);
    }
    my $parent = $tc->parent or return;
    return _find_deflator($parent);
}

#===================================
sub find_inflator {
#===================================
    my $attr = shift;
    my $inflator;
    eval { $inflator = _find_inflator( $attr->type_constraint ); 1 }
        or croak "No inflator found for attribute '"
        . $attr->name
        . '" in class '
        . $attr->associated_class->name;
    return $inflator;
}

#===================================
sub _find_inflator {
#===================================
    my $tc = shift || find_type_constraint('Any');

    my $name = $tc->name;
    if ( my $handler = $Inflators{$name} || $Inflators{ ref $tc } ) {
        return $handler->($tc);
    }
    my $parent = $tc->parent or return;
    return _find_inflator($parent);
}

#===================================
sub _deflate_no   { }
sub _inflate_no   { }
sub _deflate_cant { die "No deflator found" }
sub _inflate_cant { die "No inflator found" }
#===================================

#===================================
sub _deflate_scalar {
#===================================
    sub { $$_[0] };
}

#===================================
sub _inflate_scalar {
#===================================
    sub { \$_[0] };
}

#===================================
sub _deflate_regex {
#===================================
    sub {"$_[0]"}
}

#===================================
sub _inflate_regex {
#===================================
    sub {qr/$_[0]/}
}

#===================================
sub _deflate_array {
#===================================
    my $tc = shift;
    return unless $tc->can('type_parameter');
    my $content = _find_deflator( $tc->type_parameter );

    sub {
        my ( $array, $seen ) = @_;
        die "Cannot deflate recursive structures" if $seen->{"$array"}++;
        [ map { $content->( $_, $seen ) } @$array ];
    };
}

#===================================
sub _inflate_array {
#===================================
    my $tc = shift;
    return unless $tc->can('type_parameter');
    my $content = _find_inflator( $tc->type_parameter );

    sub {
        [ map { $content->($_) } @$_[0] ];
    };
}

#===================================
sub _deflate_hash {
#===================================
    my $tc = shift;
    return unless $tc->can('type_parameter');
    my $content = _find_deflator( $tc->type_parameter );

    sub {
        my ( $hash, $seen ) = @_;
        die "Cannot deflate recursive structures" if $seen->{"$hash"}++;
        {
            map { $_ => $content->( $hash->{ $_, $seen } ) } keys %$hash
        };
    };
}

#===================================
sub _inflate_hash {
#===================================
    my $tc = shift;
    return unless $tc->can('type_parameter');
    my $content = _find_inflator( $tc->type_parameter );

    sub {
        my $h = shift;
        {
            map { $_ => $content->( $h->{$_} ) } keys %$h
        };
    };
}

#===================================
sub _deflate_maybe {
#===================================
    my $tc = shift;
    return unless $tc->can('type_parameter');
    _find_deflator( $tc->type_parameter );
}

#===================================
sub _inflate_maybe {
#===================================
    my $tc = shift;
    return unless $tc->can('type_parameter');
    _find_inflator( $tc->type_parameter );
}

#===================================
sub _deflate_object {
#===================================
    sub {
        my ( $obj, $seen ) = @_;
        die "Cannot deflate recursive structures" if $seen->{"$obj"}++;
        my $deflated = $obj->deflate($seen);
        die "deflate() should return a HASH ref"
            unless reftype $deflated eq 'HASH';
        $deflated->{__CLASS__} ||= ref $obj;
        return $deflated;
    };
}

#===================================
sub _inflate_object {
#===================================
    sub {
        my $hash  = shift;
        my $class = delete $hash->{__CLASS__}
            or die "Object missing __CLASS__ key";
        $class->inflate($hash);
    };
}

#===================================
sub _deflate_class {
#===================================
    my $tc    = shift;
    my $class = $tc->name;

    return sub {
        my ( $obj, $seen ) = @_;
        die "Cannot deflate recursive structures" if $seen->{"$obj"}++;
        $obj->deflate($seen);
        }
        if does_role( $class, 'ESModel::Role::Type' );

    sub {
        my ( $obj, $seen ) = @_;
        die "Cannot deflate recursive structures" if $seen->{"$obj"}++;
        my $deflated = $obj->deflate($seen);
        die "deflate() should return a HASH ref"
            unless reftype $deflated eq 'HASH';
        $deflated->{__CLASS__} ||= ref $obj;
        return $deflated;
    };
}

#===================================
sub _inflate_class {
#===================================
    my $tc    = shift;
    my $class = $tc->name;
    return sub { $class->inflate(@_) };
}

#===================================
sub _deflate_decorated { _find_deflator shift->__type_constraint }
sub _inflate_decorated { _find_inflator shift->__type_constraint }
#===================================

#===================================
sub _deflate_type_param {
#===================================
    my $tc = shift;
    return unless $tc->can('type_parameter');
    _find_deflator $tc->type_parameter;
}
#===================================
sub _inflate_type_param {
#===================================
    my $tc = shift;
    return unless $tc->can('type_parameter');
    _find_inflator $tc->type_parameter;
}

#===================================
sub _deflate_parameterized {
#===================================
    my $tc     = shift;
    my $parent = $tc->parent;

    if ( my $handler = $Deflators{ $parent->name } ) {
        return $handler->($tc);
    }
    return _find_deflator($parent);
}

#===================================
sub _inflate_parameterized {
#===================================
    my $tc     = shift;
    my $parent = $tc->parent;

    if ( my $handler = $Inflators{ $parent->name } ) {
        return $handler->($tc);
    }
    return _find_inflator($parent);
}

#===================================
sub _deflate_dict { _deflate_sub_fields( @{ shift->type_constraints } ) }
sub _inflate_dict { _inflate__sub_fields( @{ shift->type_constraints } ) }
#===================================

#===================================
sub _deflate_tuple {
#===================================
    my $i        = 0;
    my @tcs      = @{ shift->type_constraints };
    my $deflator = _deflate_sub_fields( map { $i++ => $_ } @tcs );
    return sub {
        my ( $array, $seen ) = @_;
        my %hash;
        @hash{ 0 .. $#{$array} } = @$array;
        $deflator->( \%hash, $seen );
    };
}

#===================================
sub _inflate_tuple {
#===================================
    my $i        = 0;
    my @tcs      = @{ shift->type_constraints };
    my $inflator = _inflate_sub_fields( map { $i++ => $_ } @tcs );
    sub {
        my $hash = $inflator->(@_);
        [ @{$hash}{ 0 .. keys(%$hash) - 1 } ];
    };
}

#===================================
sub _deflate_sub_fields {
#===================================
    my %dict = @_;
    my %deflators;

    for my $key ( keys %dict ) {
        my $tc = find_type_constraint $dict{$key};
        $deflators{$key} = _find_deflator $tc ;
    }
    sub {
        my ( $hash, $seen ) = @_;
        die "Cannot deflate recursive structures" if $seen->{"$hash"}++;
        my %new;
        while ( my ( $k, $v ) = each %$hash ) {
            next unless defined $v;
            if ( my $deflator = $deflators{$k} ) {
                $v = $deflator->( $v, $seen );
            }
            $new{$k} = $v;
        }
        return \%new;
    };
}

#===================================
sub _inflate_sub_fields {
#===================================
    my %dict = @_;
    my %inflators;
    for my $key ( keys %dict ) {
        my $tc = find_type_constraint $dict{$key};
        $inflators{$key} = _find_inflator $tc;
    }
    sub {
        my $hash = shift;
        my %new;
        while ( my ( $k, $v ) = each %$hash ) {
            if ( my $inflator = $Inflators{$k} ) {
                $v = $inflator->($k);
            }
            $new{$k} = $v;
        }
        return \%new;
    };
}

#===================================
sub _deflate_datetime {
#===================================
    require DateTime;
    sub { $_[0]->set_time_zone('UTC')->iso8601 };
}

#===================================
sub _inflate_datetime {
#===================================
    sub {
        my %args;
        @args{ (qw(year month day hour minute second)) } = split /\D/, shift;
        DateTime->new(%args);
    };
}

#===================================
sub _deflate_geopoint {
#===================================
    sub {$_[0]}
}

#===================================
sub _inflate_geopoint {
#===================================
    sub {$_[0]}
}

#===================================
sub _deflate_binary {
#===================================
    require MIME::Base64;
    sub { MIME::Base64::encode_base64( $_[0] ) };
}
#===================================
sub _inflate_binary {
#===================================
    require MIME::Base64;
    sub { MIME::Base64::decode_base64( $_[0] ) };
}

1;
