use strict;
use warnings;

use Test::More;
use List::MoreUtils qw/any/; #TODO recommend

use Orange3::Config;
use Orange3::Generator;
use t::Util qw/create_configfile/;

my $test_config = {
    debug_mode  => 1,
    e_size_num  => 3001,
    classes     => ['static', ''],
    modifiers   => ['const', 'volatile', 'const volatile', ''],
    tmodifiers  => ['volatile', ''],
    types       => [
        'signed char',
        'unsigned char',
        'signed short',
        'unsigned short',
        'signed int',
        'unsigned int',
        'signed long',
        'unsigned long',
        'signed long long',
        'unsigned long long',
        'float',
        'double',
        'long double',
    ],
    scopes    => ['LOCAL', 'GLOBAL'],
    operators => [qw(+ + + - - - * * * * * * / / / / / / % % % % % % << << << << << << >> >> >> >> >> >> == != < > <= >= && || | | | & & & ^ ^ ^)],
    type => {
        "signed char" => {
            bits => 8,
        },
        "unsigned char" => {
            bits => 8,
        },
        "signed short" => {
            bits => 16,
        },
        "unsigned short" => {
            bits => 16,
        },
        "signed int" => {
            bits => 32,
        },
        "unsigned int" => {
            bits => 32,
        },
        "signed long" => {
            bits => 32,
        },
        "unsigned long" => {
            bits => 32,
        },
        "signed long long" => {
            bits => 64,
        },
        "unsigned long long" => {
            bits => 64,
        },
        "float" => {
            bits => 24,
        },
        "double" => {
            bits => 53,
        },
        "long double" => {
            bits => 65,
        },
    }
};

my $config_file = create_configfile($test_config);

subtest 'basic' => sub {
    my $generator = Orange3::Generator->new(
        config => Orange3::Config->new($config_file->filename)
    );

    isa_ok $generator, 'Orange3::Generator';
    isa_ok $generator->{config}, 'Orange3::Config';

    can_ok $generator, 'run';

    $generator->_init();

    subtest '_generate_random_var' => sub {
        my $number = 0;
        my $var = $generator->_generate_random_var($number);

        is $var->{name_type}, 'x', "name_type: $var->{name_type}";
        is $var->{name_num}, $number, "name_num: $var->{name_num}";
        ok !defined $var->{ival};
        ok !defined $var->{val};
        ok any { $_ eq $var->{type} } @{$test_config->{types}}, "type: $var->{type}";
        ok any { $_ eq $var->{class} } @{$test_config->{classes}}, "class: $var->{class}";
        ok any { $_ eq $var->{modifier} } @{$test_config->{modifiers}}, "modifier: $var->{modifier}";
        ok any { $_ eq $var->{scope} } @{$test_config->{scopes}}, "scope: $var->{scope}";
        is $var->{used}, 1, "used: $var->{used}";
    };

    subtest 'generate_t_var' => sub {
        my $type  = 'signed int';
        my $value = 0;
        my $count = 0;
        my $var   = $generator->generate_t_var(
            $type, $value, $count
        );

        is $var->{name_type}, 't', "name_type: $var->{name_type}";
        is $var->{name_num}, $count, "name_num: $var->{name_num}";
        is $var->{val}, $value;
        is $var->{type}, $type, "type: $var->{type}";
        ok any { $_ eq $var->{class} } @{$test_config->{classes}}, "class: $var->{class}";
        ok any { $_ eq $var->{modifier} } @{$test_config->{tmodifiers}}, "modifier: $var->{modifier}";
        is $var->{scope}, 'GLOBAL', "scope: $var->{scope}";
        is $var->{used}, 1, "used: $var->{used}";
    };

    subtest 'generate_expression' => sub {
        subtest 'minimal expression' => sub {
           my $node  = 0;
           my $depth = 0;
           $generator->{var_max} = 4;
           $generator->generate_random_vars();
           my $expression = $generator->generate_expression($node, $depth, undef);

           ok $expression;
           is $expression->{ntype}, 'op', 'ok expression type';
           ok any { $_ eq $expression->{otype} } @{$test_config->{operators}}, "ok operator";
        };

        subtest 'deeply expression' => sub {
           my $node  = 10;
           my $depth = 10;
           $generator->{var_max} = 4;
           $generator->generate_random_vars();
           my $expression = $generator->generate_expression($node, $depth, undef);

           ok $expression;
        };
    };

    subtest '_generate_value' => sub {
        subtest 'bit is 0' => sub {
            isa_ok Orange3::Generator::_generate_value(0), 'Math::BigInt';
        };

        subtest 'bit is not 0' => sub {
            isa_ok Orange3::Generator::_generate_value(1), 'Math::BigInt';
        };
    };

    subtest '_select_varnode' => sub {
        $generator->{var_max} = 5;
        $generator->generate_random_vars();
        my $var = $generator->_select_varnode();

        is $var->{ntype}, 'var';
    };

    subtest 'define_value' => sub {
        subtest 'type is float' => sub {
            my $value = $generator->define_value('float');
            ok $value;
        };

        # subtest 'type is signed int' => sub {
        #     my $value = $generator->define_value('signed int');
        #     ok $value;
        # };
    };

    subtest 'integral_promotion' => sub {
        subtest 'smaller' => sub {
            my $type = 'unsigned char';
            my $got = $generator->integral_promotion($type);
            is $got, 'signed int';
        };
    };
};

done_testing;
