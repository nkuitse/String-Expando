use strict;
use warnings;

use Test::More tests => 5;

use_ok 'String::Expando';

my $exp = String::Expando->new;
ok $exp, 'instantiate';
is $exp->expand('foo'), 'foo', 'foo';
is $exp->expand('%(foo)'), '', '%(foo)';
is $exp->expand('%(foo)', { qw(foo bar) }), 'bar', '%(foo) -> bar';
