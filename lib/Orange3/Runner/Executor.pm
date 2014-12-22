package Orange3::Runner::Executor;

use strict;
use warnings;

sub new {
  my ( $class, %args ) = @_;

  bless {
    error     => [],
    error_msg => "",
    command   => "",
    %args,
  }, $class;
}

sub run {
  my $self = shift;

  ( $self->{error_msg}, $self->{error}, $self->{command} ) =
    $self->{execute}->( $self->{config} );
}

sub error     { @{ shift->{error} }; }
sub error_msg { shift->{error_msg}; }
sub command   { shift->{command}; }

1;
