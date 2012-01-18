package ESModel::Meta::Class::Model;

use Moose::Role;
use List::Util ();
use Carp;

my %attr = (
    index       => 'indices',
    type        => 'types',
    char_filter => 'char_filters',
    analyzer    => 'analyzers',
    filter      => 'filters',
    tokenizer   => 'tokenizers',
);

while ( my ( $singular, $plural ) = each %attr ) {
    has $plural => (
        is      => 'ro',
        traits  => ['Hash'],
        isa     => 'HashRef',
        builder => "_build_$plural",
        handles => {
            "get_$singular"      => 'get',
            "add_${singular}"    => 'set',
            "remove_${singular}" => 'delete',
            "has_${singular}"    => 'exists'
        }
    );
}

#===================================
sub _build_indices { {} }
sub _build_types   { {} }
#===================================

#===================================
sub _build_char_filters {
#===================================
    +{ map { $_ => 0 } qw(html_strip char_filter) };
}

#===================================
sub _build_filters {
#===================================
    +{  map { $_ => 0 }
            qw(
            standard asciifolding length lowercase nGram edgeNGram
            porterStem shingle stop word_delimiter snowball kstem phonetic
            synonym dictionary_decompounder hyphenation_decompounder
            reverse elision truncate unique
            )
    };
}

#===================================
sub _build_tokenizers {
#===================================
    +{  map { $_ => 0 }
            qw(
            edgeNGram keyword letter lowercase nGram standard
            whitespace pattern uax_url_email path_hierarchy
            )
    };
}

#===================================
sub _build_analyzers {
#===================================
    +{  map { $_ => 0 }
            qw(
            standard simple whitespace stop keyword pattern language snowball
            arabic armenian basque brazilian bulgarian catalan chinese
            cjk czech danish dutch english finnish french galician german
            greek hindi hungarian indonesian italian norwegian persian
            portuguese romanian russian spanish swedish turkish thai
            )
    };
}
1;
