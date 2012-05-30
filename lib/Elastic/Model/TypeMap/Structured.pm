package Elastic::Model::TypeMap::Structured;

use Elastic::Model::TypeMap::Base qw(:all);
use namespace::autoclean;

#===================================
has_type 'MooseX::Meta::TypeConstraint::Structured',
#===================================
    deflate_via { _structured( 'deflator', @_ ) },
    inflate_via { _structured( 'inflator', @_ ) },
    map_via { _structured( 'mapper', @_ ) };

#===================================
has_type 'MooseX::Types::Structured::Optional',
#===================================
    deflate_via { _content_handler( 'deflator', @_ ) },
    inflate_via { _content_handler( 'inflator', @_ ) },
    map_via { _content_handler( 'mapper', @_ ) };

#===================================
has_type 'MooseX::Types::Structured::Tuple',
#===================================
    deflate_via { _deflate_tuple(@_) },    #
    inflate_via { _inflate_tuple(@_) },    #
    map_via { _map_dict( _tuple_to_dict(shift), @_ ) };

#===================================
has_type 'MooseX::Types::Structured::Dict',
#===================================
    deflate_via {
    _flate_dict( 'deflator', { @{ shift->type_constraints } }, @_ );
    },

    inflate_via {
    _flate_dict( 'inflator', { @{ shift->type_constraints } }, @_ );
    },

    map_via {
    _map_dict( { @{ shift->type_constraints } }, @_ );
    };

#===================================
has_type 'MooseX::Types::Structured::Map',
#===================================
    deflate_via { _flate_map( 'deflator', @_ ) },
    inflate_via { _flate_map( 'inflator', @_ ) },
    map_via { type => 'object', enabled => 0 };

#===================================
sub _deflate_tuple {
#===================================
    my $dict = _tuple_to_dict(shift);
    return \&_pass_through unless %$dict;
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
    return \&_pass_through unless %$dict;
    my $inflator = _flate_dict( 'inflator', $dict, @_ );
    sub {
        my $hash = $inflator->(@_);
        [ @{$hash}{ 0 .. keys(%$hash) - 1 } ];
    };
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

    return \&_pass_through unless %$dict;

    my %flators;

    for my $key ( keys %$dict ) {
        $flators{$key} = $map->find( $type, $dict->{$key}, $attr )
            || die "No $type found for key ($key)";
    }

    sub {
        my ( $hash, $model ) = @_;
        +{  map { $_ => $flators{$_}->( $hash->{$_}, $model ) }
            grep { exists $flators{$_} } keys %$hash
        };
    };
}

#===================================
sub _map_dict {
#===================================
    my ( $tcs, $attr, $map ) = @_;

    return ( type => 'object', enabled => 0 )
        unless %$tcs;

    my %properties;
    for ( keys %$tcs ) {
        my %key_mapping = $map->find( 'mapper', $tcs->{$_}, $attr );
        die "Couldn't find mapping for key $_"
            unless %key_mapping;
        $properties{$_} = \%key_mapping;
    }
    return (
        type       => 'object',
        dynamic    => 'strict',
        properties => \%properties
    );
}

#===================================
sub _flate_map {
#===================================
    my ( $type, $tc, $attr, $map ) = @_;

    my $tcs = $tc->type_constraints || [];
    my $content_tc = $tcs->[1]
        or return \&_pass_through;

    my $content = $map->find( $type, $content_tc, $attr ) or return;

    sub {
        my ( $hash, $model ) = @_;
        +{ map { $_ => $content->( $hash->{$_}, $model ) } keys %$hash };
    };
}

#===================================
sub _flate_optional {
#===================================
    my $content = _content_handler(@_) or return;
    sub {
        my ( $val, $model ) = @_;
        return defined $val ? $content->( $val, $model ) : undef;
    };
}

#===================================
sub _structured {
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
    return $tc->can('type_parameter')
        ? $map->find( $type, $tc->type_parameter, $attr )
        : $type eq 'mapper' ? ( type => 'object', enabled => 0 )
        :                     \&_pass_through;
}

#===================================
sub _pass_through { $_[0] }
#===================================

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

