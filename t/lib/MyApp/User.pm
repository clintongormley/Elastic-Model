package MyApp::User;

use Elastic::Doc;

#===================================
has 'name' => (
#===================================
    is  => 'rw',
    isa => 'Str',
    multi => {
        ngrams => {analyzer=>'edge_ngrams'}
    }
);

#===================================
has 'email' => (
#===================================
    is  => 'rw',
    isa => 'Str',
);

no Elastic::Doc;

1;
