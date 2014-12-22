use strict;
use warnings;

use Test::More;

use Orange3::Config;
use t::Util qw/create_configfile/;

my $test_config = {
    e_size_num  => 3001,
    options     => ["-O3"],
    source_file => 'test.c',
    exec_file   => 'a.out',
    macro_ok    => 'printf("@OK@\n")',
    macro_ng    => 'printf("@NG@ (test = " fmt ")\n",val)',
};

my $config_file = create_configfile($test_config);

subtest 'basic' => sub {
    my $config = Orange3::Config->new($config_file->filename);

    isa_ok $config, 'Orange3::Config';
    can_ok $config, 'get';

    subtest 'load config' => sub {
        for my  $key ( keys %{$test_config}) {
            my $got      = $config->get($key);
            my $expected = $test_config->{$key};
            if (ref $got) {
                is_deeply $got, $expected, "set param $key";
            }
            else {
                is $got, $expected, "set param $key";
            }
        }
    };
};

done_testing;
