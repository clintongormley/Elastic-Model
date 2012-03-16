package ESModel::Meta::Class::Model;

use Moose::Role;
use List::Util ();
use MooseX::Types::Moose qw(:all);
use Carp;
use Data::Dump qw(pp);
use namespace::autoclean;

my %defaults = (
    analyzer  => {},
    tokenizer => {},
);

for my $k (qw(domain char_filter analyzer filter tokenizer)) {
    my %default = %{ $defaults{$k} || {} };
    has "${k}s" => (
        is      => 'ro',
        traits  => ['Hash'],
        isa     => HashRef,
        default => sub { \%default },
        handles => {
            $k          => 'get',
            "add_${k}"  => 'set',
            "has_${k}"  => 'exists',
            "all_${k}s" => 'keys',
        }
    );
    next if $k eq 'domain';

    before "add_$k" => sub {
        my $class = shift;
        my %params = ref $_[0] ? { shift() } : @_;
        for my $defn ( values %params ) {
            my $type = $defn->{type} || 'custom';
            return if $type eq 'custom' and $k eq 'analyzer';
            croak "Unknown type '$type' in $k:\n" . pp( \%params ) . "\n"
                unless $class->is_default( $k, $type );
        }
    };
}

our %DefaultAnalysis = (
    char_filter => { map { $_ => 1 } qw(html_strip char_filter) },
    filter      => +{
        map { $_ => 1 }
            qw(
            standard asciifolding length lowercase nGram edgeNGram
            porterStem shingle stop word_delimiter snowball kstem phonetic
            synonym dictionary_decompounder hyphenation_decompounder
            reverse elision trim truncate unique
            )
    },
    tokenizer => {
        map { $_ => 1 }
            qw(
            edgeNGram keyword letter lowercase nGram standard
            whitespace pattern uax_url_email path_hierarchy
            )
    },
    analyzer => {
        map { $_ => 1 }
            qw(
            standard simple whitespace stop keyword pattern language snowball
            arabic armenian basque brazilian bulgarian catalan chinese
            cjk czech danish dutch english finnish french galician german
            greek hindi hungarian indonesian italian norwegian persian
            portuguese romanian russian spanish swedish turkish thai
            )
    }
);

#===================================
sub is_default {
#===================================
    my $self = shift;
    my $type = shift || '';
    croak "Unknown type '$type' passed to is_default()"
        unless exists $DefaultAnalysis{$type};
    my $name = shift or croak "No $type name passed to is_default";
    return exists $DefaultAnalysis{$type}{$name};
}

#===================================
sub analysis_for_mappings {
#===================================
    my $self     = shift;
    my $mappings = shift;

    my %analyzers;
    for my $type ( keys %$mappings ) {
        for my $name ( _required_analyzers( $mappings->{$type} ) ) {
            next
                if exists $analyzers{$name}
                    || $self->is_default( 'analyzer', $name );
            $analyzers{$name} = $self->analyzer($name)
                or die
                "Unknown analyzer '$name ' required by type '$type' in class "
                . $self->class_for_type($type);    ## TODO: wrong method
        }
    }
    return unless %analyzers;

    my %analysis = ( analyzer => \%analyzers );
    for my $type (qw(tokenizer filter char_filter )) {
        my %defn;
        for my $analyzer_name ( keys %analyzers ) {
            my $vals = $analyzers{$analyzer_name}{$type} or next;
            for my $name ( ref $vals ? @$vals : $vals ) {
                next
                    if exists $defn{$name}
                        || $self->is_default( $type, $name );
                $defn{$name} = $self->$type($name)
                    or die
                    "Unknown $type '$name' required by analyzer '$analyzer_name'";
            }
        }
        $analysis{$type} = \%defn if %defn;
    }
    return ( analysis => \%analysis );
}

#===================================
sub _required_analyzers {
#===================================
    my @analyzers;
    while (@_) {
        my $mapping = shift or next;
        my @sub = (
            values %{ $mapping->{fields} || {} },
            values %{ $mapping->{properties} || {} }
        );

        push @analyzers, _required_analyzers(@sub),
            map { $mapping->{$_} } grep /analyzer/, keys %$mapping;
    }

    return @analyzers;
}

our $Counter = 1;
#===================================
sub wrapped_class_name {
#===================================
    return 'ESModel::__WRAPPED_' . $Counter++ . '_::' . $_[1];
}

1;
