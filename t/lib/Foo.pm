package Foo;

use Elastic::Model;

#===================================
has_namespace 'foo', (
#===================================
    types => { user => 'Foo::User' }
);

#===================================
has_namespace 'bar', (
#===================================
    domains => [ 'aaa', 'bbb' ],
    types   => {
        user => 'Foo::User',
        post => 'Foo::Post'
    },
);

no Elastic::Model;

1;