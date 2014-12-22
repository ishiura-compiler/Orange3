package Orange3::Mini::Bottomup;

use strict;
use warnings;
use Carp ();

use Orange3::Mini::Backup;
use Orange3::Mini::Util;
use Orange3::Mini::Compute;

sub new {
  my ( $class, $config, $vars, $assigns, %args ) = @_;

  bless {
    config  => $config,
    vars    => $vars,
    assigns => $assigns,
    run     => $args{run},
    status  => $args{status},
    backup  => Orange3::Mini::Backup->new( $vars, $assigns ),
    %args,
  }, $class;
}

sub minimize_inorder_head

  # inorder; only parent on the No. 1 special
{
  my ( $self, $ref, $i ) = @_;

  my $reduced = 0;

  if ( $ref->{ntype} eq "op" ) {
    for my $k ( @{ $ref->{in} } ) {
      if ( $k->{print_value} == 0 ) {
        $reduced = $self->minimize_inorder( $k->{ref}, $i );
        if ( $reduced == -1 || $reduced == 2 ) {
          if ( $self->try_reduce( $k, $i ) ) {
            $reduced = 1;
          }
          else {
            # Check the right grandson of child
            $reduced = $self->minimize_inorder( $k->{ref}, $i );
            if ( $reduced > 0 ) {
              $reduced = 1;
            }
            else {
              $reduced = 0;
            }
          }
        }
      }
    }
  }

  return $reduced;
}

sub minimize_inorder

  # inorder; Try to top-down if successful examines only one child
{
  my ( $self, $ref, $i ) = @_;

  my $reduced = -1;

  if ( $ref->{ntype} eq "op" ) {
    for my $k ( @{ $ref->{in} } ) {
      if ( $k->{print_value} == 0 ) {

        # Check the left grandson of child
        $reduced = $self->minimize_inorder( $k->{ref}, $i );
        if ( $reduced == -1 || $reduced == 2 ) {

          #  Check child
          if ( $self->try_reduce( $k, $i ) ) {
            $reduced = 2;
            return $reduced;
          }
          else {
            #  Check the right grandson of child
            $reduced = $self->minimize_inorder( $k->{ref}, $i );
            if ( $reduced > 0 ) {
              $reduced = 1;
            }
            else {
              $reduced = 0;
            }
          }
        }
      }
    }
  }

  return $reduced;
}

sub minimize_preorder

  # preorder, Bisection exploration version (top-down manner I examine)
{
  my ( $self, $ref, $i ) = @_;

  my $reduced = 0;

  if ( $ref->{ntype} eq "op" ) {
    for my $k ( @{ $ref->{in} } ) {
      if ( $k->{print_value} == 0 ) {
        if ( $self->try_reduce( $k, $i ) ) {
          $reduced = 1;
        }
        elsif ( $self->minimize_preorder( $k->{ref}, $i ) ) {
          $reduced = 1;
        }
      }
    }
  }
  return $reduced;
}

sub minimize_postorder

  # Solid plate of the bottom-up
  # (I find out one by one minimization from the node below)
{
  my ( $self, $ref, $i, $s, $assign_in_locate ) = @_;

  my $reduced      = -1;
  my $reduced_next = 0;

  if ( $ref->{ntype} eq "op" ) {
    $s .= "{'in'}";
    my $ii = 0;
    for my $k ( @{ $ref->{in} } ) {
      my $sr = $s . "[$ii]";
      if ( $sr eq $$assign_in_locate || $$assign_in_locate eq 'SKIP' ) {
        $reduced           = 0;
        $$assign_in_locate = 'SKIP';
        return $reduced;
      }
      elsif ( $k->{print_value} == 0 ) {
        $sr .= "{'ref'}";
        $reduced_next =
          $self->minimize_postorder( $k->{ref}, $i, $sr, $assign_in_locate );
        if ( $reduced_next == -1 || $reduced_next == 2 ) {
          if ( $self->try_reduce( $k, $i ) ) {
            $$assign_in_locate = 'BLANK';
            $reduced_next      = 2;
          }
          else {
            # To leave the OK after NG.
            # (Recompile prevention of the same type)
            if ( $$assign_in_locate eq 'BLANK' ) {
              $$assign_in_locate = "$sr";
            }
            if   ( $reduced_next == 2 ) { $reduced_next = 1; }
            else                        { $reduced_next = 0; }
          }
        }
      }
      if ( $reduced < $reduced_next ) {
        $reduced = $reduced_next;
      }
      $ii++;
    }
  }
  return $reduced;
}

sub try_reduce {
  my ( $self, $vn, $i ) = @_;

  my $update = 0;
  my $o      = $vn->{ref}->{out};

  if ( $vn->{type} eq $o->{type} && $vn->{val} == $o->{val} ) {
    $vn->{print_value} = 2;
  }
  else {
    $vn->{print_value} = 1;
  }

  my $obj = Orange3::Generator::Program->new( $self->{config} );
  my $tree_sprint =
    "$i: " . $obj->tree_sprint( $self->{assigns}->[$i]->{root} ) . "\n";
  $self->_print($tree_sprint);
  my $ans = $self->_generate_and_test;
  if ( $ans == 1 ) {
    if ( $vn->{print_value} == 1 ) {
      $vn->{print_value} = 2;
      $tree_sprint =
        "$i: " . $obj->tree_sprint( $self->{assigns}->[$i]->{root} ) . "\n";
      $self->_print($tree_sprint);
      $ans = $self->_generate_and_test;
      if ( $ans == 0 ) {
        $vn->{print_value} = 1;
        $self->_print("");
      }
    }
    $update = 1;
  }
  elsif ( $ans == 0 ) {
    $vn->{print_value} = 0;    # return to the original
  }
  return $update;
}

sub _generate_and_test {
  my $self = shift;

  return Orange3::Mini::Compute->new(
    $self->{config}, $self->{vars}, $self->{assigns},
    run    => $self->{run},
    status => $self->{status},
  )->_generate_and_test;
}

sub _print {
  my ( $self, $body ) = @_;
  Orange3::Mini::Util::print( $self->{status}->{debug}, $body );
}

1;
