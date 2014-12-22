package Orange3::Mini::Topdown;

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
    topdown => undef,
    %args,
  }, $class;
}

sub top_down_prepare {
  my ( $self, $i ) = @_;
  my $assign_var_locate = [];
  my $name              = 't' . $i;
  $self->{top_down}->{current_assign_i} = $i;
  $self->{top_down}->{update}           = 0;
  if (
    !$self->_search_assigns_var_and_exist_check( $name, $assign_var_locate ) )
  {
    $self->top_down( $self->{assigns}->[$i]->{root} );
  }
  else {
    $self->_print("t$i is unchangeable, missed TOP_DOWN");
  }
  return $self->{top_down}->{update};
}

sub top_down_final_prepare {
  my ( $self, $i ) = @_;
  $self->{top_down}->{current_assign_i} = $i;
  $self->{top_down}->{update}           = 0;
  return $self->top_down_final( $self->{assigns}->[$i]->{root} );
}

sub _top_down_ref_cut_and_judge {
  my $self = shift;
  my $k    = $self->{top_down}->{current_ref_in};
  if ( $k->{ref}->{ntype} eq "op" && $k->{print_value} == 0 ) {
    my $i = $self->{top_down}->{current_assign_i};
    $self->{backup}->_backup_var_and_assigns;
    $self->{assigns}->[$i]->{root} = $k->{ref}
      ; # put an expression that was carried out to minimize the sequence of Formula
    $self->{assigns}->[$i]->{val} =
      $self->{assigns}->[$i]->{root}->{out}->{val};
    $self->{assigns}->[$i]->{type} =
      $self->{assigns}->[$i]->{root}->{out}->{type};
    my $obj = Orange3::Generator::Program->new( $self->{config} );
    my $tree_sprint =
      "$i: " . $obj->tree_sprint( $self->{assigns}->[$i]->{root} ) . "\n";
    $self->_print($tree_sprint);
    $self->_varset_val_reset($i);
    return 1;
  }
  else {
    return 0;
  }
}

sub _top_down_ntype_op_check {
  my ( $self, $n ) = @_;
  if ( $n->{ntype} eq "var" ) {
    return 0;
  }
  return 1;
}

sub top_down {
  my ( $self, $n ) = @_;

  if ( $self->_top_down_ntype_op_check($n) ) {
    for my $k ( @{ $n->{in} } ) {
      $self->{top_down}->{current_ref_in} = $k;
      if ( $self->_top_down_ref_cut_and_judge ) {
        if ( $self->_generate_and_test ) {
          $self->{top_down}->{update} = 1;
          $self->top_down( $self->{top_down}->{current_ref_in}->{ref} );
          return;
        }
        my $i = $self->{top_down}->{current_assign_i};
        $self->{backup}->_restore_assign_number($i);
        $self->{backup}->_restore_var_and_assigns;
      }
    }
  }
}

sub top_down_final {
  my ( $self, $n ) = @_;

  if ( $self->_top_down_ntype_op_check($n) ) {
    for my $k ( @{ $n->{in} } ) {
      my $recompute = 1;
      my $i         = $self->{top_down}->{current_assign_i};
      $self->{top_down}->{current_ref_in} = $k;
      if ( $self->_top_down_ref_cut_and_judge ) {
        if ( $self->_dump_test( $i, $recompute ) == 1 ) {
          $self->{top_down}->{update} = 1;
          $self->top_down_final( $self->{top_down}->{current_ref_in}->{ref} );
          return;
        }
        my $i = $self->{top_down}->{current_assign_i};
        $self->{backup}->_restore_assign_number($i);
        $self->{backup}->_restore_var_and_assigns;
      }
    }
  }
}

sub _varset_val_reset {
  my ( $self, $i ) = @_;
  my $new_type = $self->{assigns}->[$i]->{root}->{out}->{type};
  Orange3::Mini::Compute->new(
    $self->{config}, $self->{vars}, $self->{assigns},
    run    => $self->{run},
    status => $self->{status},
    )
    ->varset_val_reset( "t", $i, $new_type,
    "UNCHANGE", $self->{assigns}->[$i]->{root}->{out}->{val} );
}

sub _tval_compute {
  my ( $self, $modify_t_num ) = @_;
  return Orange3::Mini::Compute->new(
    $self->{config}, $self->{vars}, $self->{assigns},
    run    => $self->{run},
    status => $self->{status},
  )->tval_compute($modify_t_num);
}

sub _search_assigns_var_and_exist_check {
  my ( $self, $name, $assign_var_locate ) = @_;

  return Orange3::Mini::Util::search_assigns_var( $self->{assigns}, $name,
    $assign_var_locate );
}

sub _generate_and_test {
  my $self = shift;

  return Orange3::Mini::Compute->new(
    $self->{config}, $self->{vars}, $self->{assigns},
    run    => $self->{run},
    status => $self->{status},
  )->_generate_and_test;
}

sub _dump_test {
  my ( $self, $assigns_i, $recompute ) = @_;

  return Orange3::Mini::Compute->new(
    $self->{config}, $self->{vars}, $self->{assigns},
    run    => $self->{run},
    status => $self->{status},
  )->dump_test( $assigns_i, $recompute );
}

sub _print {
  my ( $self, $body ) = @_;
  Orange3::Mini::Util::print( $self->{status}->{debug}, $body );
}

1;
