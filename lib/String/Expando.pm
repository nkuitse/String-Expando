package String::Expando;

# ABSTRACT: expand %(xxx) sequences in strings

use strict;
use warnings;

sub new {
    my $cls = shift;
    my $self = bless { @_ }, $cls;
    $self->init;
}

sub init {
    my ($self) = @_;
    if (defined $self->{'expando'}) {
        my $rx = $self->{'expando'};
        $self->{'consume_expando'} = sub {
            m{ \G ($rx) }xgc ? (defined $2 ? $2 : $1) : ()
        }
    }
    else {
        $self->{'consume_expando'} ||= sub {
            m{ \G \% ([^%()]*) \( ([^\s()]+) \) }xgc
                ? ($2, $1)
                : ()
        };
    }
    if (defined $self->{'literal'}) {
        my $rx = $self->{'literal'};
        $self->{'consume_literal'} = sub {
            m{ \G $rx }xgc ? ($1) : ()
        }
    }
    else {
        $self->{'consume_literal'} ||= sub {
            m{ \G (.) }xgc ? ($1) : ()
        }
    }
    if (defined $self->{'escaped_literal'}) {
        my $rx = $self->{'escaped_literal'};
        $self->{'consume_escaped_literal'} = sub {
            m{ \G $rx }xgc ? ($1) : ()
        }
    }
    else {
        $self->{'consume_escaped_literal'} ||= sub {
            m{ \G \\ (.) }xgc ? ($1) : ()
        }
    }
    $self->{'decoder'}   ||= \&decode;
    $self->{'stash'}     ||= {};
    $self->{'functions'} ||= {};
    return $self;
}

sub stash { @_ > 1 ? $_[0]->{'stash'} = $_[1] : $_[0]->{'stash'} }
sub functions { @_ > 1 ? $_[0]->{'functions'} = $_[1] : $_[0]->{'functions'} }

sub expand {
    my ($self, $str, $stash) = @_;
    $stash ||= $self->{'stash'};
    my $mat = $self->{'consume_expando'};
    my $lit = $self->{'consume_literal'};
    my $esc = $self->{'consume_escaped_literal'};
    my $dec = $self->{'decoder'};
    my $out = '';
    local $_ = $str;
    pos($_) = 0;
    while (pos($_) < length($_)) {
        my $res;
        if (my ($code, $fmt) = $mat->()) {
            $res = $dec->($self, $code, $stash);
            $res = '' if !defined $res;
            $res = sprintf($fmt, $res) if defined $fmt && length $fmt;
        }
        elsif (!defined ($res = &$lit)
            && !defined ($res = &$esc)) {
            die "Unparseable: $_";
        }
        $out .= $res;
    }
    return $out;
}

sub decode {
    my ($self, $code, $stash) = @_;
    return $stash->{$code};

    # XXX Not quite working fancy-dancy decoding follows...
    my $val = $stash || $self->stash;
    my $func = $self->functions;
    my $rval = ref($val);
    $code =~ s/^\.?/./ if $rval eq 'HASH';
    $func ||= {};
    while ($code =~ s{
        ^
        (?:
            \[ (-?\d+) (?: \.\. (-?\d+) )? \]
            |
            \. ([^\s.:\[\]\(\)]+)
            |
            :: ([^\s.:\[\]\(\)]+)
        )
    }{}xg) {
        my ($l, $r, $k, $f) = ($1, $2, $3, $4);
        if (defined $f) {
            die "No such function: $f" if !$func->{$f} ;
            $val = $func->{$f}->($val);
        }
        elsif ($rval eq 'HASH') {
            die if defined $l or defined $r;
            $val = $val->{$k};
        }
        elsif ($rval eq 'ARRAY') {
            die if defined $k;
            $val = defined $r ? [ @$val[$l..$r] ] : $val->[$l];
        }
        else {
            die "Can't subval: ref = '$rval'";
        }
        $rval = ref $val;
    }
    die if length $code;
    return join('', @$val) if $rval eq 'ARRAY';
    return join('', values %$val) if $rval eq 'HASH';
    return $val;
}

1;
