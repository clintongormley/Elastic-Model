package ESModel::Types;

use strict;
use warnings;
use ElasticSearch();

use MooseX::Types::Moose qw(:all);
use MooseX::Types::Structured qw (Dict Optional Map);

use MooseX::Types -declare => [ qw(
        Binary
        CoreFieldType
        DynamicMapping
        DynamicTemplate
        DynamicTemplates
        ES
        ESDateTime
        ESDoc
        ESTypeConstraint
        FieldType
        GeoPoint
        IndexMapping
        IndexNames
        Latitude
        Longitude
        MultiField
        MultiFields
        PathMapping
        SearchType
        StoreMapping
        TermVectorMapping
        Timestamp
        TypeNames
        UID
        )
];

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
enum FieldType, (
#===================================
    'string',    'integer', 'long',   'float',
    'double',    'short',   'byte',   'boolean',
    'binary',    'object',  'nested', 'ip',
    'geo_point', 'attachment'
);

#===================================
enum CoreFieldType, (
#===================================
    'string', 'integer', 'long', 'float',
    'double', 'short',   'byte', 'boolean',
);

#===================================
enum IndexMapping, (
#===================================
    'analyzed', 'not_analyzed', 'no'
);

#===================================
enum TermVectorMapping, (
#===================================
    'no',           'yes',
    'with_offsets', 'with_positions',
    'with_positions_offsets'
);

#===================================
enum DynamicMapping, (
#===================================
    'false', 'strict', 'true'
);

#===================================
enum PathMapping, (
#===================================
    'just_name', 'full'
);

#===================================
enum SearchType, (
#===================================
    'query_then_fetch',     'query_and_fetch',
    'dfs_query_then_fetch', 'dfs_query_and_fetch',
    'scan',                 'count'
);

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
    omit_norms                   => Optional [Bool],
    omit_term_freq_and_positions => Optional [Bool],
    term_vector                  => Optional [TermVectorMapping],
    geohash                      => Optional [Bool],
    lat_lon                      => Optional [Bool],
    geohash_precision            => Optional [Int]
];

#===================================
subtype MultiFields,
#===================================
    as HashRef [MultiField];

#===================================
subtype Longitude,
#===================================
    as Num,
    where { $_ >= -180 and $_ <= 180 },
    message {"Longitude must be in the range -180 to 180"};

#===================================
subtype Latitude,
#===================================
    as Num,
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
subtype DynamicTemplate, as Dict [
#===================================
    match              => Optional [Str],
    unmatch            => Optional [Str],
    path_match         => Optional [Str],
    match_mapping_type => Optional [FieldType],
    mapping            => HashRef
];

#===================================
subtype DynamicTemplates, as Map [ Str => DynamicTemplate ];
#===================================

#===================================
subtype IndexNames, as ArrayRef [Str],
#===================================
    where { @{$_} > 0 },    #
    message {"At least one index name is required"};
coerce IndexNames, from Str, via { [$_] };

#===================================
subtype TypeNames, as ArrayRef [Str];
#===================================
coerce TypeNames, from Str, via { [$_] };

#===================================
class_type ESDateTime, { class => 'DateTime' };
#===================================

#===================================
subtype Timestamp, as Num;
#===================================
coerce Timestamp, from ESDateTime,
    via { DateTime->from_epoch( epoch => $_ ) };

#===================================
subtype UID, as 'ESModel::Doc::UID',
#===================================
    where { $_->from_store }, message {"The UID has not been loaded from the store"};
coerce UID, from Str,     via { ESModel::Doc::UID->new_from_string($_) };
coerce UID, from HashRef, via { ESModel::Doc::UID->new($_) };

#===================================
subtype ESDoc, as RoleName,
#===================================
    where { $_->does('ESModel::Role::Doc') };

#===================================
subtype ESTypeConstraint, as 'Moose::Meta::TypeConstraint';
#===================================
coerce ESTypeConstraint, from Str,
    via { Moose::Util::TypeConstraints::find_type_constraint($_) };

1;
