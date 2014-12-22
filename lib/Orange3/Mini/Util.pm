package Orange3::Mini::Util;

use strict;
use warnings;
use Carp ();

sub _check_assign {
  my ($assign_i) = @_;
  return ( defined $assign_i->{root} && $assign_i->{print_statement} ) ? 1 : 0;
}

sub print {
  my ( $debug, $body ) = @_;
  if   ($debug) { print $body . "\n"; }
  else          { ; }
}

sub _count_defined_assign {
  my ($assigns) = @_;
  my $assign_define = 0;
  for my $i ( 0 .. $#{$assigns} ) {
    $assign_define =
      _check_assign( $assigns->[$i] ) ? ++$assign_define : $assign_define;
  }
  return $assign_define;
}

sub _check_assign_exp_only {
  my ($assign_i) = @_;
  return ( defined $assign_i->{root} && $assign_i->{print_statement} == 2 )
    ? 1
    : 0;
}

sub _check_assign_exp {
  my ($assign_i) = @_;
  return ( defined $assign_i->{root} && $assign_i->{print_statement} == 1 )
    ? 1
    : 0;
}

sub _count_assign_exp {
  my ($assigns) = @_;
  my $assign_define = 0;
  for my $i ( 0 .. $#{$assigns} ) {
    $assign_define =
      _check_assign_exp( $assigns->[$i] ) ? ++$assign_define : $assign_define;
  }
  return $assign_define;
}

sub _count_assign_exp_only {
  my ($assigns) = @_;
  my $assign_define = 0;
  for my $i ( 0 .. $#{$assigns} ) {
    $assign_define =
      _check_assign_exp_only( $assigns->[$i] )
      ? ++$assign_define
      : $assign_define;
  }
  return $assign_define;
}

sub search_assigns_var {
  my ( $assigns, $name, $assign_var_locate ) = @_;

  my $exist_total = 0;

  for my $i ( 0 .. $#{$assigns} ) {
    my $assign_i = $assigns->[$i];
    if ( _check_assign($assign_i) ) {
      my $s     = '$assigns->[' . $i . ']->{root}';
      my $exist = search_assign_var( $assigns->[$i]->{root},
        $name, $s, $assign_var_locate );
      $exist_total += $exist;
    }
  }
  return $exist_total;
}

sub search_assign_var {
  my ( $ref, $name, $s, $assign_var_locate ) = @_;

  my $exist_total = 0;

  if ( $ref->{ntype} eq 'op' ) {
    $s .= "{'in'}";
    my $i = 0;
    for my $r ( @{ $ref->{in} } ) {
      if ( $r->{print_value} == 0 ) {
        my $sr .= $s . "[$i]{'ref'}";
        my $exist =
          search_assign_var( $r->{ref}, $name, $sr, $assign_var_locate );
        $exist_total += $exist;
      }
      $i++;
    }
    return $exist_total;
  }
  elsif ( $ref->{ntype} eq 'var' ) {
    my $var_name = $ref->{var}->{name_type} . $ref->{var}->{name_num};
    $s .= "{'var'}";
    if ( $var_name eq $name ) {
      push @$assign_var_locate, $s;
      return ++$exist_total;
    }
    return $exist_total;
  }
  else {
    Carp::croak("$ref->{ntype}");
  }
}

sub put_assign_var {
  my ( $assigns, $assign_var_locate, $v ) = @_;

  for my $i ( 0 .. $#{$assign_var_locate} ) {
    if ( defined $assign_var_locate->[$i] ) {
      my $s  = $assign_var_locate->[$i];
      my $sr = $s . "{type}='" . $v->{type} . "';";
      $sr .= $s . "{ival}='" . $v->{ival} . "';";
      $sr .= $s . "{val}='" . $v->{val} . "';";
      $sr .= $s . "{name_type}='" . $v->{name_type} . "';";
      $sr .= $s . "{name_num}='" . $v->{name_num} . "';";
      $sr .= $s . "{class}='" . $v->{class} . "';";
      $sr .= $s . "{modifier}='" . $v->{modifier} . "';";
      $sr .= $s . "{scope}='" . $v->{scope} . "';";
      $sr .= $s . "{used}='" . $v->{used} . "';";
      eval $sr;

      if ($@) {
        Carp::croak("eval $sr\n$@\n");
      }
    }
  }
}

sub int_ification {
  my ( $conifg, $type, $val ) = @_;

  my ( $s, $ty ) = split( / /, $type, 2 );
  my $at;

  if ( $s eq "signed" || $s eq "unsigned" ) {
    if    ( $ty eq "long long" ) { $at = $s . ' long'; }
    elsif ( $ty eq "long" )      { $at = $s . ' int'; }
    elsif ( $ty eq "int" )       { $at = $s . ' int'; }
    elsif ( $ty eq "short" )     { $at = $s . ' int'; }
    elsif ( $ty eq "char" )      { $at = $s . ' short'; }
    else                         { Carp::croak("type = $s $ty"); }
  }
  else {
    if    ( $type eq "long double" ) { $at = 'double'; }
    elsif ( $type eq "double" )      { $at = 'float'; }
    elsif ( $type eq "float" )       { $at = 'signed long long'; }
    else                             { Carp::croak("type = $type($s $ty)"); }
  }

  my $types = $conifg->get('type');
  my $max   = Math::BigInt->new( $types->{$at}->{max} );
  my $min   = Math::BigInt->new( $types->{$at}->{min} );
  if ( $s eq "unsigned" ) {
    $val = $val % ( $max + 1 );
  }
  else {
    unless ( $min <= $val && $val <= $max ) {
      $at = $type;
    }
  }
  return ( $at, $val );

}
1;
