use strict;
use warnings;

use Test::More;

use Orange3::Mini;

subtest 'basic' => sub {
    my $mini = Orange3::Mini->new();

    ok $mini, 'constructor';
    isa_ok $mini, 'Orange3::Mini';

    can_ok $mini, 'parse_options';
    can_ok $mini, 'run';
};

subtest 'parse_options' => sub {
    my $mini = Orange3::Mini->new();

    subtest 'argv' => sub {
        eval {
            $mini->parse_options(qw/aaa bbb ccc/);
        };
        is_deeply $mini->{argv}, [qw/aaa bbb ccc/], 'set argv';
    };

    subtest 'option: help' => sub {
        subtest 'short option' => sub {
            eval {
                $mini->parse_options(qw/-h/);
            };
            like $@, qr/^Usage/, 'show usage';
        };

        subtest 'long option' => sub {
            eval {
                $mini->parse_options(qw/--help/);
            };
            like $@, qr/^Usage/, 'show usage';
        };
    };
};

done_testing;
