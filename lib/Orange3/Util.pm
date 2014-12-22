package Orange3::Util;

use strict;
use warnings;

use Carp       ();
use File::Spec ();

sub is_dir {
  my $path = shift;

  return -d $path ? 1 : 0;
}

sub is_file {
  my $path = shift;

  return -f $path ? 1 : 0;
}

sub read_directory {
  my $dir = shift;

  opendir my $dh, $dir or Carp::croak("Can't open directory $dir: $!");
  my @dirs = grep { !m{^\.\.?$} } readdir $dh;
  closedir $dh;

  return @dirs;
}

sub which {
  my $command = shift;

  my @paths      = File::Spec->path;
  my @extensions = ('');

  for my $path (@paths) {
    my $path = File::Spec->catfile( $path, $command );

    for my $extension (@extensions) {
      my $file = $path . $extension;
      next if -d $file;

      if ( -e $file && -x $file ) {
        return 1;
      }
    }
  }

  return 0;
}

package Orange3::Util::Chdir;

use Cwd qw(getcwd);

sub new {
  my ( $class, $dir ) = @_;

  my $cwd = getcwd();
  my $guard = sub { chdir $cwd; };

  chdir($dir) or die "Can't chdir '$dir'";
  bless \$guard, $class;
}

sub DESTROY {
  ${ $_[0] }->();
}

1;

