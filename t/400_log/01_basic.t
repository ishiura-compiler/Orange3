use strict;
use warnings;

use Test::More;
use File::Spec ();
use File::Temp ();

use Orange3::Log;

my $testdir = File::Temp::tempdir( CLEANUP => 1 );
$testdir =~ s{/$}{};

subtest 'basic' => sub {
    my $log = Orange3::Log->new(
        dir  => $testdir,
        name => 'test.log'
    );

    isa_ok $log, 'Orange3::Log';
    can_ok $log, 'print';

    ok(-e File::Spec->catfile($testdir, 'test.log'), 'create log file');
};

subtest 'dies ok' => sub {
    eval {
        my $log = Orange3::Log->new(
            name => 'test.log'
        );
    };
    like $@, qr/Missing mandatory parameter: dir/, 'no directory';

    eval {
        my $log = Orange3::Log->new(
            dir      => $testdir,
            name     => 'test.log',
            encoding => 'I_AM_ILLEGAL'
        );
    };
    like $@, qr/Not found encoding 'I_AM_ILLEGAL'/, 'illegal parameter';

};

done_testing;
