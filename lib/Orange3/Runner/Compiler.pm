package Orange3::Runner::Compiler;

use strict;
use warnings;

sub new {
  my ( $class, %args ) = @_;

  bless {
    error_msg => "",
    command   => "",
    %args,
  }, $class;
}

sub run {
  my $self = shift;

  system "rm -f $self->{config}->{exec_file} > /dev/null";
  ( $self->{error_msg}, $self->{command} ) =
    $self->{compile}->( $self->{config}, $self->{option} );
}

sub error_msg { shift->{error_msg}; }
sub command   { shift->{command}; }

1;
