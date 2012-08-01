package MyApp::UniqUser;

use Elastic::Doc;

#===================================
has 'name' => (
#===================================
    is  => 'rw',
    isa => 'Str',
);

#===================================
has 'email' => (
#===================================
    is         => 'rw',
    isa        => 'Str',
    required   => 1,
    unique_key => 'email',
    trigger    => sub { shift->clear_compound },
);

#===================================
has 'account_type' => (
#===================================
    is         => 'rw',
    isa        => 'Str',
    required   => 1,
    unique_key => 'account',
    trigger    => sub { shift->clear_compound },
);

#===================================
has 'optional' => (
#===================================
    is         => 'rw',
    isa        => 'Str',
    unique_key => 'optional',
    clearer    => 'clear_optional'
);

#===================================
has 'compound' => (
#===================================
    is         => 'ro',
    init_arg   => undef,
    isa        => 'Str',
    lazy       => 1,
    clearer    => 'clear_compound',
    default    => sub { $_[0]->account_type . ':' . $_[0]->email },
    unique_key => 'compound',
);

no Elastic::Doc;

1;
