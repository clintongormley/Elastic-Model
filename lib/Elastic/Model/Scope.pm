package Elastic::Model::Scope;

use Moose;
use namespace::autoclean;
use MooseX::Types::Moose qw(:all);
use Scalar::Util qw(refaddr);

#===================================
has '_objects' => (
#===================================
    is      => 'ro',
    isa     => HashRef,
    default => sub { {} },
);

#===================================
has 'parent' => (
#===================================
    is  => 'ro',
    isa => 'Elastic::Model::Scope',
);

# if the object exists in the current scope
#   return the object if its version is the same or higher
#   otherwise return undef
# otherwise, look for the same object in a parent scope
# and, if found, create a clone in the current scope

#===================================
sub get_object {
#===================================
    my ( $self, $ns, $uid ) = @_;
    my $existing = $self->_objects->{$ns}{ $uid->cache_key };

    return $existing
        if $existing && $existing->uid->version >= ( $uid->version || 0 );

    my $parent = $self->parent or return undef;
    $existing = $parent->get_object( $ns, $uid ) or return undef;

    my $new = Class::MOP::class_of($existing)
        ->new_stub( $uid, $existing->_source );
    return $self->store_object( $ns, $new );
}

# if the object exists in the current scope
#   return the same object if the version is the same or higher
#   if the existing object has not already been looked at
#     then update it with current details, and return it
#     else move the old version to 'old'
# store the new version in current scope

#===================================
sub store_object {
#===================================
    my ( $self, $ns, $object ) = @_;
    my $uid     = $object->uid;
    my $objects = $self->_objects;

    if ( my $existing = $objects->{$ns}{ $uid->cache_key } ) {
        return $existing if $existing->uid->version >= $uid->version;

        if ( $existing->_can_inflate ) {
            $existing->_set_source( $object->_source );
            $existing->uid->update_from_uid($uid);
            return $existing;
        }

        $objects->{old}{ $uid->cache_key . refaddr $existing} = $existing;
    }

    $self->_objects->{$ns}{ $uid->cache_key } = $object;
}

#===================================
sub DEMOLISH {
#===================================
    my $self = shift;
    $self->model->detach_scope($self);
}

1;

__END__

# ABSTRACT: Keeps objects alive and connected

=head1 SYNOPSIS

=head1 DESCRIPTION

L<Elastic::Model::Scope> acts as an in-memory cache, and serves three
futher purposes:

=head2 Keep objects alive

If you have a C<post> object which has a C<user> attribute, and a C<user>
object with a C<posts> attribute, then you will want to make eg the C<user>
attribute a weak ref to avoid circular references.

But then you would have a problem:

    sub add_post_to_user {
        my ( $domain, $user_id, $content )= @_;
        my $user = $domain->get( user => $user_id );
        my $post = $domain->create(
            post => {
                content => $content,
                user    => $user;
            }
        );
        $user->add_post($post);
        $user->save;
        return $post;
    }

    my $post = add_post_to_user($domain, 1234, 'my post content');

    print $post->user->name;
    # ERROR - user has disappeared!

Scopes keep all your doc class objects in scope, so that they don't disappear
out from under you. So this would work:

    my $post;
    {
        my $scope = $domain->new_scope;
        $post = add_post_to_user($domain, 1234, 'my post content');

        print $post->user->name;
        # Clint

    }
    # $scope has now disappeared

    print $post->user->name;
    # ERROR - user has disappeared!

=head2 Singleton objects

By default, each object is a singleton.  For instance, if you do:

    my $foo = $domain->get( user => 123 );
    my $bar = $domain->get( user => 123 );

    print $bar->name;
    # Clint

    $foo->name('John');

    print $bar->name;
    # John

    print refaddr($foo) == refaddr($bar) ? 'TRUE' : 'FALSE';
    # TRUE

C<$foo> and C<$bar> are the same object.

=head2 Separate objects

With any database, there are timing issues. Another process may change
have changed C<user 123> between the first call to C<< $domain->get >> and the
second.

Also, because ElasticSearch has "real time get" (ie if you retrieve
a document by ID, you will get the latest version that exists) but "NEAR real
time search" (search docs are refreshed only once every second, so may
contain an older version of a doc), you could find yourself in this situation:

    $user = $domain->get(user => 123);
    print $user->name;
    # Clint

    print $user->uid->version;
    # 1

    $user->name('John');
    $user->save;

    print $user->uid->version;
    # 2

    $results = $domain->view->type('user')->queryb({ name => 'Clint' });
    # results contain user 123, version 1
    # even though version 2 no longer matches the search

Depending on your requirements, you may want the C<user 123> object in
C<$results> to be the same as it was in version 1 (eg so that the search
results that you show the user make sense), or you may want to use
the most up to date version (ie version 2).

This is where it is useful to have multiple scopes.

=head1 ATTRIBUTES

=head2 parent

The parent scope of this scope, or UNDEF.

=head1 METHODS

=head2 get_object()

    $obj = $scope->get_object($domain_name, $uid);

When calling L<Elastic::Model::Domain/"get()"> or L<Elastic::Model::Role::Model/"get_doc()">
to retrieve an object from ElasticSearch, we first check to see if we can
return the object from our in-memory cache by calling L</get_object()>:

If an object with the same C<domain_name/type/id> exists in the CURRENT scope
(and its version is as least as high as the requested version, if any) then
we return the SAME object.

    $scope = $domain->new_scope;
    $one   = $domain->get( user => 123 );
    $two   = $domain->get( user => 123 );

    print $one->name;
    # Clint

    $two->name('John');

    print $one->name;
    # John

    print refaddr($foo) == refaddr($bar) ? 'TRUE' : 'FALSE';
    # TRUE

If an object with the same C<domain_name/type/id> exists in the PARENT scope
(and its version is as least as high as the requested version, if any) then
we return a CLONE of the object. (Note: we clone the original object as it was
when loaded from ElasticSearch. Any unsaved changes are ignored.)

    $scope_1  = $domain->new_scope;
    $one      = $domain->get( user => 123 );

    print $one->name;
    # Clint

    $one->name('John');

    $scope_2  = $domain->new_scope;
    $two      = $domain->get( user => 123 );

    print $two->name;
    # Clint

    print refaddr($foo) == refaddr($bar) ? 'TRUE' : 'FALSE';
    # FALSE

Otherwise the calling method will fetch the document from ElasticSearch itself,
and store it in the current scope.

=head2 store_object()

    $object = $scope->store_object($domain_name, $object);

When we load a document that didn't exist in any live scope, or we create
a new or update an existing document via L<Elastic::Model::Role::Doc/"save()">,
we also store it in the current scope via L<store_object()>.

=head3 Documents from search results

Documents from search results are a bit special.  By default when we do a search
in ElasticSearch, instead of just getting a UID back, we get back
the whole object. Depending on timing, the version returned in search may be
the same, older or newer than the version we have stored in our current scope.
We don't try to retrieve the object from the scope, because we already have
everything we need to create it.  But once we have created it, we do
try to store it in the current scope:

If an object with the same C<domain_name/type/id> DOESN'T exist in the
current scope, then we store the new object in the current scope and return
it.

If an object with the same C<domain_name/type/id> DOES exist in the
current scope, then we compare versions: If the stored version is more recent
than the new version, we return the stored object.

Otherwise, we try to update the stored object (and therefore any instances
of it that already exist in your application)    to the new version, but only
if you haven't already looked at it! (You don't want your objects changing
their values under you.)

If you have looked at the stored version, then we move it to another
cache for safe keeping, and store and return the new version.

B<Note:> "Looking" at an object means calling any accessor on any attribute
that is stored in ElasticSearch. This does not include the
L<Elastic::Model::Role::Doc/"uid"> of the object.

