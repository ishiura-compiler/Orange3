package Orange3::Log;

use strict;
use warnings;

use Carp       ();
use Encode     ();
use File::Spec ();
use File::Temp ();

my $TMPL = 'tmpXXXXXXX';

sub new {
  my ( $class, %args ) = @_;

  unless ( exists $args{dir} ) {
    Carp::croak("Missing mandatory parameter: dir");
  }

  my $encoding = delete $args{encoding} || 'utf8';
  my $encoder = Encode::find_encoding($encoding);
  unless ( defined $encoder ) {
    Carp::croak("Not found encoding '$encoding'");
  }

  my $fh = do {
    my $file_handle;

    if ( exists $args{name} ) {
      my $log = File::Spec->catfile( $args{dir}, $args{name} );
      open $file_handle, '>', $log or Carp::croak("Can't open $log: $!");
    }
    else {
      ($file_handle) = File::Temp::tempfile( $TMPL, DIR => $args{dir} );
    }
    $file_handle;
  };

  bless {
    fh      => $fh,
    encoder => $encoder,
    %args,
  }, $class;
}

sub print {
  my ( $self, $message ) = @_;
  print { $self->{fh} } $self->{encoder}->encode($message);
}

1;
