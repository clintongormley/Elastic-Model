package Elastic::Model::Types;

use strict;
use warnings;
use ElasticSearch();

use MooseX::Types::Moose qw(:all);
use MooseX::Types::Structured qw (Dict Optional Map);
use namespace::autoclean;

use MooseX::Types -declare => [ qw(
        ArrayRefOfStr
        Binary
        Consistency
        CoreFieldType
        DynamicMapping
        ES
        FieldType
        GeoPoint
        HighlightArgs
        IndexMapping
        IndexNames
        Latitude
        Longitude
        MultiField
        MultiFields
        PathMapping
        Replication
        SortArgs
        StoreMapping
        TermVectorMapping
        Timestamp
        UID
        )
];

my @enums = (
    FieldType,
    [   'string', 'integer',   'long',   'float',
        'double', 'short',     'byte',   'boolean',
        'date',   'binary',    'object', 'nested',
        'ip',     'geo_point', 'attachment'
    ],
    CoreFieldType,
    [   'string', 'integer', 'long', 'float',
        'double', 'short',   'byte', 'boolean',
        'date',   'ip',      'geo_point'
    ],
    TermVectorMapping,
    [   'no',           'yes',
        'with_offsets', 'with_positions',
        'with_positions_offsets'
    ],
    IndexMapping,
    [ 'analyzed', 'not_analyzed', 'no' ],
    DynamicMapping,
    [ 'false', 'strict', 'true' ],
    PathMapping,
    [ 'just_name', 'full' ],
    Replication,
    [ 'sync', 'async' ],
    Consistency,
    [ 'quorum', 'one', 'all' ],
);

while ( my $type = shift @enums ) {
    my $vals = shift @enums;
    subtype(
        $type,
        {   as      => enum($vals),
            message => sub { "Allowed values are: " . join '|', @$vals }
        }
    );
}

#===================================
class_type ES, { class => 'ElasticSearch' };
#===================================
coerce ES, from HashRef, via { ElasticSearch->new($_) };
coerce ES, from Str, via {
    s/^:/127.0.0.1:/;
    ElasticSearch->new( servers => $_ );
};
coerce ES, from ArrayRef, via {
    my @servers = @$_;
    s/^:/127.0.0.1:/ for @servers;
    ElasticSearch->new( servers => \@servers );
};

#===================================
subtype StoreMapping, as enum( [ 'yes', 'no' ] );
#===================================
coerce StoreMapping, from Any, via { $_ ? 'yes' : 'no' };

#===================================
subtype MultiField, as Dict [
#===================================
    type                         => Optional [CoreFieldType],
    index                        => Optional [IndexMapping],
    index_name                   => Optional [Str],
    boost                        => Optional [Num],
    null_value                   => Optional [Str],
    analyzer                     => Optional [Str],
    index_analyzer               => Optional [Str],
    search_analyzer              => Optional [Str],
    search_quote_analyzer        => Optional [Str],
    omit_norms                   => Optional [Bool],
    omit_term_freq_and_positions => Optional [Bool],
    term_vector                  => Optional [TermVectorMapping],
    geohash                      => Optional [Bool],
    lat_lon                      => Optional [Bool],
    geohash_precision            => Optional [Int],
    precision_step               => Optional [Int],
    format                       => Optional [Str],

];

#===================================
subtype MultiFields, as HashRef [MultiField];
#===================================

#===================================
subtype SortArgs, as ArrayRef;
#===================================
coerce SortArgs, from HashRef, via { [$_] };
coerce SortArgs, from Str,     via { [$_] };

#===================================
subtype HighlightArgs, as HashRef;
#===================================
coerce HighlightArgs, from Str, via { return { $_ => {} } };
coerce HighlightArgs, from ArrayRef, via {
    my $args = $_;
    my %fields;

    while ( my $field = shift @$args ) {
        die "Expected a field name but got ($field)"
            if ref $field;
        $fields{$field} = ref $args->[0] eq 'HASH' ? shift @$args : {};
    }
    return \%fields;
};

#===================================
subtype Longitude, as Num,
#===================================
    where { $_ >= -180 and $_ <= 180 },
    message {"Longitude must be in the range -180 to 180"};

#===================================
subtype Latitude, as Num,
#===================================
    where { $_ >= -90 and $_ <= 90 },
    message {"Latitude must be in the range -90 to 90"};

#===================================
subtype GeoPoint, as Dict [ lat => Latitude, lon => Longitude ];
#===================================
coerce GeoPoint, from ArrayRef, via { { lon => $_->[0], lat => $_->[1] } };
coerce GeoPoint, from Str, via {
    my ( $lat, $lon ) = split /,/;
    { lon => $lon, lat => $lat };
};

#===================================
subtype Binary, as Defined;
#===================================

#===================================
subtype IndexNames, as ArrayRef [Str],
#===================================
    where { @{$_} > 0 },    #
    message {"At least one domain name is required"};
coerce IndexNames, from Str, via { [$_] };

#===================================
subtype ArrayRefOfStr, as ArrayRef [Str];
#===================================
coerce ArrayRefOfStr, from Str, via { [$_] };

#===================================
subtype Timestamp, as Num;
#===================================

#===================================
class_type UID, { class => 'Elastic::Model::UID' };
#===================================
coerce UID, from Str,     via { Elastic::Model::UID->new_from_string($_) };
coerce UID, from HashRef, via { Elastic::Model::UID->new($_) };

1;
