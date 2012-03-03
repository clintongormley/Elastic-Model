package ESModel::Doc::Deflator;

use Moose;
use Moose::Exporter;
use Moose::Util qw(does_role);
use Moose::Util::TypeConstraints;
use Carp;
use Data::Dump qw(pp);
use List::MoreUtils qw(uniq zip);
use Class::Load qw(load_class);
use Scalar::Util qw(reftype refaddr);

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
    'ESModel::Types::ESDoc'                      => \&_deflate_esdoc,
    'ESModel::Types::GeoPoint'                   => \&_deflate_no,
    'ESModel::Types::Binary'                     => \&_deflate_binary,
    'ESModel::Types::Timestamp'                  => \&_deflate_timestamp,
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
    'ESModel::Types::GeoPoint'                   => \&_inflate_no,
    'ESModel::Types::Binary'                     => \&_inflate_binary,
    'ESModel::Types::Timestamp'                  => \&_inflate_timestamp,
);

our %Inline = (

);

#===================================
sub find_deflator {
#===================================
    my $tc = shift || find_type_constraint('Any');
    my $attr = shift;

    my $name = $tc->name;
    if ( my $handler = $Deflators{$name} || $Deflators{ ref $tc } ) {
        return $handler->( $tc, $attr );
    }
    my $parent = $tc->parent or return;
    return find_deflator( $parent, $attr );
}

#===================================
sub find_inflator {
#===================================
    my $tc = shift || find_type_constraint('Any');

    my $name = $tc->name;
    if ( my $handler = $Inflators{$name} || $Inflators{ ref $tc } ) {
        return $handler->($tc);
    }
    my $parent = $tc->parent or return;
    return find_inflator($parent);
}

#===================================
sub _deflate_cant { die "No deflator found\n" }
sub _inflate_cant { die "No inflator found\n" }
#===================================

#===================================
sub _deflate_no {
#===================================
    sub { $_[0] }
}

#===================================
sub _inflate_no {
#===================================
    sub { $_[0] }
}

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
    my ( $tc, $attr ) = @_;
    return _deflate_no() unless $tc->can('type_parameter');
    my $content = find_deflator( $tc->type_parameter, $attr );

    sub {
        my ( $array, $seen ) = @_;
        my @deflated;
        for (@$array) {
            if ( ref $_ ) {
                my %seen = %$seen;
                die "Cannot deflate recursive structures"
                    if $seen{ refaddr $_};
                push @deflated, $content->( $_, \%seen );
                next;
            }
            push @deflated, $content->($_);
        }
        return \@deflated;
    };
}

#===================================
sub _inflate_array {
#===================================
    my $tc = shift;
    return _inflate_no unless $tc->can('type_parameter');
    my $content = find_inflator( $tc->type_parameter );

    sub {
        [ map { $content->($_) } @{ $_[0] } ];
    };
}

#===================================
sub _deflate_hash {
#===================================
    my ( $tc, $attr ) = @_;
    return _deflate_no() unless $tc->can('type_parameter');
    my $content = find_deflator( $tc->type_parameter, $attr );

    sub {
        my ( $hash, $seen ) = @_;
        my %deflated;
        while ( my ( $key, $val ) = each %$hash ) {
            if ( ref $val ) {
                my %seen = %$seen;
                die "Cannot deflate recursive structures"
                    if $seen{ refaddr $val}++;
                $deflated{$key} = $content->( $val, \%seen );
            }
            else {
                $deflated{$key} = $content->($val);
            }
        }
        return \%deflated;
    };
}

#===================================
sub _inflate_hash {
#===================================
    my $tc = shift;
    return _inflate_no unless $tc->can('type_parameter');
    my $content = find_inflator( $tc->type_parameter );

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
    my ( $tc, $attr ) = @_;
    return _deflate_no unless $tc->can('type_parameter');
    find_deflator( $tc->type_parameter, $attr );
}

#===================================
sub _inflate_maybe {
#===================================
    my $tc = shift;
    return _inflate_no unless $tc->can('type_parameter');
    find_inflator( $tc->type_parameter );
}

#===================================
sub _deflate_object {
#===================================
    sub {
        my ( $obj, $seen ) = @_;
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
    my ( $tc, $attr ) = @_;
    my $class = $tc->name;
    my $meta  = $class->meta;

    if ( does_role( $class, 'ESModel::Role::Doc' ) ) {
        my $inc = $attr->include_attrs || [ $meta->get_attribute_list ];
        my $exc = $attr->exclude_attrs;
        my %inc;
        for (@$inc) {
            my $attr = $meta->get_attribute($_)
                or die "Class $class does not have attribute $_\n";
            next if $attr->exclude;
            $inc{$_} = 1;
        }
        delete @inc{@$exc} if $exc;
        delete $inc{uid};
        my @attrs = keys %inc;
        return sub {
            my ( $obj, $seen ) = @_;
            my $hash = $obj->deflate( $seen, \@attrs );
            return { %$hash, $obj->uid->as_params };
        };
    }

    sub {
        my ( $obj, $seen ) = @_;
        my $deflated = $obj->deflate($seen);
        die "deflate() should return a HASH ref"
            unless reftype $deflated eq 'HASH';
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
sub _deflate_decorated { find_deflator( shift->__type_constraint, @_ ) }
sub _inflate_decorated { find_inflatorshift->__type_constraint }
#===================================

#===================================
sub _deflate_type_param {
#===================================
    my ( $tc, $attr ) = @_;
    return unless $tc->can('type_parameter');
    find_deflator( $tc->type_parameter, $attr );
}
#===================================
sub _inflate_type_param {
#===================================
    my $tc = shift;
    return unless $tc->can('type_parameter');
    find_inflator $tc->type_parameter;
}

#===================================
sub _deflate_parameterized {
#===================================
    my ( $tc, $attr ) = @_;
    my $parent = $tc->parent;

    if ( my $handler = $Deflators{ $parent->name } ) {
        return $handler->( $tc, $attr );
    }
    return find_deflator( $parent, $attr );
}

#===================================
sub _inflate_parameterized {
#===================================
    my $tc     = shift;
    my $parent = $tc->parent;

    if ( my $handler = $Inflators{ $parent->name } ) {
        return $handler->($tc);
    }
    return find_inflator($parent);
}

#===================================
sub _deflate_dict { _deflate_sub_fields( @{ shift->type_constraints }, @_ ) }
sub _inflate_dict { _inflate__sub_fields( @{ shift->type_constraints } ) }
#===================================

#===================================
sub _deflate_tuple {
#===================================
    my ( $tc, $attr ) = @_;
    my $i   = 0;
    my @tcs = @{ $tc->type_constraints };
    my $deflator
        = _deflate_sub_fields( map { $i++ => $_ } @tcs );    ###### pass $attr
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

    #### attr
    for my $key ( keys %dict ) {
        my $tc = find_type_constraint $dict{$key};
        $deflators{$key} = find_deflator $tc ;
    }
    sub {
        my ( $hash, $seen ) = @_;
        my %new;
        while ( my ( $k, $v ) = each %$hash ) {
            next unless defined $v;
            if ( my $deflator = $deflators{$k} ) {
                my %seen = %$seen;
                die "Cannot deflate recursive structures"
                    if $seen{ refaddr $v}++;
                $v = $deflator->( $v, \%seen );
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

    #### attr
    my %inflators;
    for my $key ( keys %dict ) {
        my $tc = find_type_constraint $dict{$key};
        $inflators{$key} = find_inflator $tc;
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
sub _deflate_timestamp {
#===================================
    sub { int( $_[0] * 1000 + 0.0005 ) };
}

#===================================
sub _inflate_timestamp {
#===================================
    sub { $_[0] / 1000 };
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
