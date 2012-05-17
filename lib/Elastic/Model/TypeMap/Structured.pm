package Elastic::Model::TypeMap::Structured;

use Elastic::Model::TypeMap::Base qw(:all);
use namespace::autoclean;

#===================================
has_type 'MooseX::Types::Structured::Optional',
#===================================
    deflate_via { _flate_optional( 'deflator', @_ ) },
    inflate_via { _flate_optional( 'inflator', @_ ) },
    map_via { _content_handler( 'mapper', @_ ) };

#===================================
has_type 'MooseX::Types::Structured::Tuple',
#===================================
    deflate_via { \&_deflate_tuple }, inflate_via { \&_inflate_tuple };

#===================================
has_type 'MooseX::Types::Structured::Dict',
#===================================
    deflate_via {
    sub { _flate_dict( 'deflator', shift->type_constraints, @_ ) }
    },

    inflate_via {
    sub { _flate_dict( 'inflator', shift->type_constraints, @_ ) }
    },

    map_via {
    sub { _map_dict( shift->type_constraints, @_ ) }
    };

#===================================
has_type 'MooseX::Types::Structured::Map',
#===================================
    deflate_via { _flate_map( 'deflator', @_ ) },
    inflate_via { _flate_map( 'inflator', @_ ) },
    map_via {_map_hash};
    ## TODO: _map_map - should be like hashref

#===================================
sub _deflate_tuple {
#===================================
    my $dict = _tuple_to_dict(shift);
    my $deflator = _flate_dict( 'deflator', $dict, @_, );

    return sub {
        my ( $array, $model ) = @_;
        my %hash;
        @hash{ 0 .. $#{$array} } = @$array;
        $deflator->( \%hash, $model );
    };
}

#===================================
sub _inflate_tuple {
#===================================
    my $dict = _tuple_to_dict(shift);
    my $inflator = _flate_dict( 'inflator', $dict, @_ );
    sub {
        my $hash = $inflator->(@_);
        [ @{$hash}{ 0 .. keys(%$hash) - 1 } ];
    };
}

#===================================
sub _map_tuple {
#===================================
    my $dict = _tuple_to_dict(shift);
    return _map_dict( $dict, @_ );
}

#===================================
sub _tuple_to_dict {
#===================================
    my $i = 0;
    return { map { $i++ => $_ } @{ shift->type_constraints } };
}

#===================================
sub _flate_dict {
#===================================
    my ( $type, $dict, $attr, $map ) = @_;
    my %flators;

    for my $key ( keys %$dict ) {
        my $tc = $dict->{$key};
        $flators{$key} = $map->find( $type, $tc, $attr );
    }
    sub {
        my ( $hash, $model ) = @_;
        +{ map { $_ => $flators{$_}->( $hash->{$_}, $model ) } keys %$hash };
    };
}

#===================================
sub _flate_map {
#===================================
    my $content = _content_handler(@_) or return;
    sub {
        my ( $hash, $model ) = @_;
        {
            map { $_ => $content->( $hash->{$_}, $model ) } %$hash
        };
    };
}

#===================================
sub _flate_optional {
#===================================
    my $content = _content_handler(@_) or return;
    # TODO: Check whether a missing optional value eg in a hashref or
    # a map or dict remains missing or is replaced with undef
    sub {
        my ( $val, $model ) = @_;
        return defined $val ? $content->( $val, $model ) : undef;
    };
}

#===================================
sub _map_dict {
#===================================
    my ( $tcs, $attr, $map ) = @_;
    my %properties;
    for ( keys %$tcs ) {
        my $tc = $tcs->{$_};
        $properties{$_} = { $map->mapper( $tc, $attr ) };
    }
    return (
        type       => 'object',
        dynamic    => 'strict',
        properties => \%properties
    );
}

#===================================
sub _content_handler {
#===================================
    my ( $type, $tc, $attr, $map ) = @_;
    return unless $tc->can('type_parameter');
    return $map->find( $type, $tc->type_parameter, $attr );
}
1;

__END__

# ABSTRACT: Type maps for MooseX::Types::Structured

=head1 DESCRIPTION

L<Elastic::Model::TypeMap::Structured> provides mapping, inflation and deflation
for the L<MooseX::Types::Structured> type constraints.
It is loaded automatically byL<Elastic::Model::TypeMap::Default>.

=head1 TYPES

=head2 Optional

An undef value is stored as a JSON C<null>. A missing value is not set.
The mapping depends on the content type, eg C<Optional[Int]>.
An C<Optional> without a content type is not supported.

=head2 Tuple

Because array refs are interpreted by ElasticSearch as multiple values
of the same type, tuples are converted to hash refs whose keys are
the index number.  For instance, a field C<foo> with C<Tuple[Int,Str]>
and value C<[5,'foo']> will be deflated to C<< { 0 => 5, 1 => 'foo' } >>.

A tuple is mapped as an object, with:

    {
        type       => 'object',
        dynamic    => 'strict',
        properties => \%properties
    }

The C<%properties> mapping depends on the content types. A C<Tuple> without
content types is not supported.

=head2 Dict

A C<Dict> is mapped as an object, with:

    {
        type       => 'object',
        dynamic    => 'strict',
        properties => \%properties
    }

The C<%properties> mapping depends on the content types. A C<Dict> without
content types is not supported.

=head2 Map

TODO: This needs to be resolved - do we use dynamic templates for the fields?

