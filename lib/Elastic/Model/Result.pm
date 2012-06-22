package Elastic::Model::Result;

use Moose;

use Carp;
use Elastic::Model::Types qw(UID);
use MooseX::Types::Moose qw(:all);

use namespace::autoclean;

#===================================
has 'result' => (
#===================================
    isa      => HashRef,
    is       => 'ro',
    required => 1,
);

#===================================
has 'uid' => (
#===================================
    isa     => UID,
    is      => 'ro',
    lazy    => 1,
    builder => '_build_uid',
    handles => [ 'index', 'type', 'id', 'routing' ]
);

#===================================
has 'source' => (
#===================================
    is      => 'ro',
    isa     => Maybe[HashRef],
    lazy    => 1,
    builder => '_build_source',
);

#===================================
has 'score' => (
#===================================
    is      => 'ro',
    isa     => Num,
    lazy    => 1,
    builder => '_build_score'
);

#===================================
has 'fields' => (
#===================================
    is      => 'ro',
    isa     => HashRef,
    traits  => ['Hash'],
    lazy    => 1,
    builder => '_build_fields',
    handles => { field => 'get' }
);

#===================================
has 'highlights' => (
#===================================
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_highlights'
);

#===================================
has 'object' => (
#===================================
    is      => 'ro',
    does    => 'Elastic::Model::Role::Doc',
    lazy    => 1,
    builder => '_build_object'
);

no Moose;

#===================================
sub _build_uid    { Elastic::Model::UID->new_from_store( shift()->result ) }
sub _build_source { shift->result->{_source} }
sub _build_score  { shift->result->{_score} }
sub _build_fields { shift->result->{fields} || {} }
sub _build_highlights { shift->result->{highlight} || {} }
#===================================

#===================================
sub _build_object {
#===================================
    my $self = shift;
    $self->model->get_doc( uid => $self->uid, source => $self->source );
}

#===================================
sub highlight {
#===================================
    my $self       = shift;
    my $field      = shift() or croak "Missing (field) name";
    my $highlights = $self->highlights->{$field} or return;
    return @{$highlights};
}

1;

__END__

# ABSTRACT: A wrapper for individual search results

=head1 SYNOPSIS

    $result             = $results->next_result;

    $object             = $result->object;
    $uid                = $result->uid;

    \%all_highlights    = $result->highlights;
    @field_highlights   = $result->highlight('field_name');

    \%all_fields        = $result->fields;
    $field_value        = $result->field('field_name');
    $script_field_value = $result->field('script_field_name');

    $score              = $result->score;
    \%source_field      = $result->source;
    \%raw_result        = $result->result;

=head1 DESCRIPTION

L<Elastic::Model::Result> wraps the individual result returned from
L<Elastic::Model::Results> or L<Elastic::Model::Results::Scrolled>.

=head1 ATTRIBUTES

=head2 object

    $object     = $result->object();

The object associated with the result.  By default, the L</source> field is
returned in search results, meaning that we can inflate the object just from
the search results.  B<Note:> If you set L<Elastic::Model::View/fields> and you
don't include C<'_source'> then you will be unable to inflate your object
without a separate (but automatic) step to retrieve it from ElasticSearch.


=head2 uid

=head2 index, type, id, routing

    $uid        = $result->uid;
    $index      = $result->index   | $result->uid->index;
    $type       = $result->type    | $result->uid->type;
    $id         = $result->id      | $result->uid->id;
    $routing    = $result->routing | $result->uid->routing;

The L<uid|Elastic::Model::UID> of the doc.  L</index>, L</type>, L</id>
and L</routing> are provided for convenience.

=head2 highlights

=head2 highlight

    \%all_highlights  = $result->highlights;
    @field_highlights = $result->highlight('field_name');

The snippets from the L<highlighted fields|Elastic::Model::View/highlight>
in your L<view|Elastic::Model::View>. L</highlights> returns a hash ref
containing snippets from all the highlighted fields, while L</highlight> returns
a list of the snippets for the named field.

=head2 fields

=head2 field

    \%all_fields        = $result->fields;
    $field_value        = $result->field('field_name');
    $script_field_value = $result->field('script_field_name');

The values of any L<fields|Elastic::Model::View/fields> or
L<script_fields|Elastic::Model::View/script_fields> specified in your
L<view|Elastic::Model::View>.

=head2 score

    $score = $result->score;

The relevance score of the result. Note: if you L<sort|Elastic::Model::View/sort>
on any value other than C<_score> then the L</score> will be zero, unless you
also set L<Elastic::Model::View/track_scores> to a true value.

=head2 result

    \%raw_result = $result->result

The raw result as returned by ElasticSearch.

=head2 source

    \%source_field = $result->source

The C<_source> field (ie the hashref which represents your object in
ElasticSearch). This value is returned by default with any search, and is
used to inflate your L</object()> without having to retrieve it in a separate
step. B<Note:> If you set L<Elastic::Model::View/fields> and you don't include
C<'_source'> then you will be unable to inflate your object without a separate
(but automatic) step to retrieve it from ElasticSearch.


=cut
