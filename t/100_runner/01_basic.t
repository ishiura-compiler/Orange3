use strict;
use warnings;

use Test::More;

use Orange3::Runner;

subtest 'basic' => sub {
    my $runner = Orange3::Runner->new();
    isa_ok $runner, 'Orange3::Runner';

    can_ok $runner, 'run';
    can_ok $runner, 'parse_options';

    subtest 'parse_options' => sub {
        subtest 'option: config' => sub {
            $runner = Orange3::Runner->new();
            subtest 'short option' => sub {
                $runner->parse_options(qw/-c hoge/);
                ok $runner->{config_file};
                is $runner->{config_file}, 'hoge';
            };

            subtest 'long option' => sub {
                $runner->parse_options(qw/--config=hoge/);
                ok $runner->{config_file};
                is $runner->{config_file}, 'hoge';
            };
        }; 

        subtest 'option: count' => sub {
            $runner = Orange3::Runner->new();
            subtest 'short option' => sub {
                $runner->parse_options(qw/-n 100/);
                ok $runner->{count};
                is $runner->{count}, 100, 'option:count is ok';
            };
        }; 

        subtest 'option: seed' => sub {
            $runner = Orange3::Runner->new();
            subtest 'short option' => sub {
                $runner->parse_options(qw/-s 100/);
                ok $runner->{start_seed};
                is $runner->{start_seed}, 100, 'option:seed is ok';
            };

            subtest 'long option' => sub {
                $runner->parse_options(qw/--seed=100/);
                ok $runner->{start_seed};
                is $runner->{start_seed}, 100, 'option:seed is ok';
            };
        }; 

        subtest 'option: time' => sub {
            $runner = Orange3::Runner->new();
            subtest 'short option' => sub {
                $runner->parse_options(qw/-t 100/);
                ok $runner->{time};
                is $runner->{time}, 100, 'option:time is ok'; 
            };

            subtest 'long option' => sub {
                $runner->parse_options(qw/--time=100/);
                ok $runner->{time};
                is $runner->{time}, 100, 'option:time is ok'; 
            };
        }; 

        subtest 'option: help' => sub {
            $runner = Orange3::Runner->new();
            subtest 'short option' => sub {
                eval {
                    $runner->parse_options(qw/-h/);
                };
                like $@, qr/^Usage/, 'show usage';
            };

            subtest 'long option' => sub {
                eval {
                    $runner->parse_options(qw/--help/);
                };
                like $@, qr/^Usage/, 'show usage';
            };
        }; 

        subtest 'die' => sub {
            $runner = Orange3::Runner->new();
            eval {
                $runner->parse_options(qw/-n 100 -t 100/);
            };
            like $@, qr/Cannot enable 'count' and 'time' option/, 'die ok';
        };
    };

    subtest 'validate' => sub {
        $runner = Orange3::Runner->new();
        $runner->parse_options();
        $runner->_validate();
        is $runner->{count}, 1, 'set default value'
    };
};

done_testing;
