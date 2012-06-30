#!/usr/bin/perl

use strict;
use warnings;
use Test::More 0.96;
use Test::Exception;
use Test::Deep;
use Scalar::Util qw(refaddr);

use lib 't/lib';

our $es;
do 'es.pl';

use_ok 'MyApp' || print 'Bail out';

my $model = new_ok( 'MyApp', [ es => $es ], 'Model' );
ok my $ns = $model->namespace('myapp'), 'Got ns';

ok $ns->index('myapp')->create, 'Create index myapp';

isa_ok my $domain = $model->domain('myapp'), 'Elastic::Model::Domain',
    'Got domain myapp';

isa_ok my $u1 = $domain->create(user=>{id=>1, name => 'Clint', email =>'clint@foo'}),'MyApp::User' ,'Create U1';
isa_ok my $u2 = $domain->get(user=>1), 'MyApp::User', 'Get U2';
ok refaddr $u1 ne refaddr $u2, 'U1 and U2 are separate objects';

is $u1->name('John'),'John', 'Set U1.name to John';
ok $u1->save, 'U1 updated';
is $u2->name(),'Clint', 'U2.name is Clint';
is $u1->uid->version,2, 'U1 has version 2';
is $u2->uid->version,1, 'U2 has version 1';

is $u2->email('john@foo'),'john@foo', 'Set U2.email to john@foo';
throws_ok sub { $u2->save}, qr/ElasticSearch::Error::Conflict/, 'Save U2 throws conflict error';
ok $u2->save(on_conflict=>\&on_conflict);

#===================================
sub on_conflict {
#===================================
    my ($old,$new) = @_;
    is $old->has_changed, 1, 'Old has changed';
    is $old->has_changed('email'),1, 'Old email has changed';
    is $old->has_changed('name'),'', 'Old name has not changed';
    cmp_deeply [keys %{$old->old_values}],['email','timestamp'], 'Old values keys';
    is $old->old_value('email'), 'clint@foo', 'Old value email';
    is $old->old_value('name'), undef, 'Old value name';
    is $new->has_changed(), '', 'New not changed';
    cmp_deeply $new->old_values, {}, 'New old values';

    is $old->uid->version, 1, 'Old is v1';
    is $new->uid->version, 2, 'New is v2';
    ok $old->overwrite, 'Overwrite';
    is $old->uid->version, 3, 'Old is v3';

}

## DONE ##

done_testing;

sub test_uid {
    my ( $uid, $name, $vals ) = @_;
    isa_ok $uid , 'Elastic::Model::UID', $name;
    for my $t (qw(index type id routing version from_store cache_key)) {
        is $uid->$t, $vals->{$t}, "$name $t";
    }
}

__END__
