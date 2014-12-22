package t::Util;
use strict;
use warnings;

use base qw/Exporter/;
use Data::Dumper;
use File::Temp;

our @EXPORT = qw/create_configfile/;

sub create_configfile {
    my $config = shift;

    my $tmp = File::Temp->new( UNLINK => 1 );
    print {$tmp} Data::Dumper::Dumper($config);
    $tmp->autoflush(1);

    return $tmp;
}

1;
