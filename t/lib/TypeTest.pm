package TypeTest;

use Elastic::Model;

#===================================
has_namespace 'foo', (
#===================================
    types => {
        moose      => 'TypeTest::Moose',
        moosex     => 'TypeTest::MooseX',
        structured => 'TypeTest::Structured',
        object     => 'TypeTest::Object',
        common     => 'TypeTest::Common',
        es         => 'TypeTest::ES',
        user       => 'Foo::User',
    }
);

no Elastic::Model;

1;
