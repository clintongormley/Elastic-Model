package TypeTest;

use Elastic::Model;

#===================================
has_namespace 'foo' => {
#===================================
    moose      => 'TypeTest::Moose',
    moosex     => 'TypeTest::MooseX',
    structured => 'TypeTest::Structured',
    object     => 'TypeTest::Objects',
    common     => 'TypeTest::Common',
    es         => 'TypeTest::ES',
    user       => 'Foo::User',
};

has_type_map 'TypeTest::TypeMap';

no Elastic::Model;

1;
