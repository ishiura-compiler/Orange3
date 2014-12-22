package Orange3::Generator::Arithmetic;

use parent 'Orange3::Generator';

use strict;
use warnings;

use Math::BigInt;
use Math::BigFloat;

our $FLOAT_MODE = 1;

sub new {
  my ( $class, %args ) = @_;

  bless {%args}, $class;
}

sub arithmetic_conversion {
  my ( $self, $l, $r ) = @_;    # load the type of type of in
  my $type       = $self->_get_type;
  my $debug_mode = $self->{config}->get('debug_mode');
  my $res;

  # c99 processing of standard
  # If one type of long double
  if ( $l eq "long double" || $r eq "long double" ) {
    $res = "long double";
  }

  # If one type of double
  elsif ( $l eq "double" || $r eq "double" ) {
    $res = "double";
  }

  # If one type of float
  elsif ( $l eq "float" || $r eq "float" ) {
    $res = "float";
  }

  # others
  else {
    my ( $ls, $lt ) = split( / /, $l, 2 );
    my ( $rs, $rt ) = split( / /, $r, 2 );

    if ( $l eq $r ) {
      $res = $l;
    }

    # If both operands have an integer or unsigned integer type signed
    elsif ( ( $ls eq "unsigned" && $rs eq "unsigned" )
      || ( $ls eq "signed" && $rs eq "signed" ) )
    {
      # convert the type of order is in high operand
      if ( $type->{$l}->{order} > $type->{$r}->{order} ) {
        $res = $l;
      }
      elsif ( $type->{$l}->{order} < $type->{$r}->{order} ) {
        $res = $r;
      }
      else {
        die "error:arithmetic_conversion_1";
      }
    }

    # If the same rank or unsigned operands than other high
    elsif (
      (
           $ls eq "unsigned"
        && $rs eq "signed"
        && $type->{$l}->{order} >= $type->{$r}->{order}
      )
      || ( $ls eq "signed"
        && $rs eq "unsigned"
        && $type->{$l}->{order} <= $type->{$r}->{order} )
      )
    {
      # converted to unsigned operand
      if ( $ls eq "unsigned" ) {
        $res = $l;
      }
      elsif ( $rs eq "unsigned" ) {
        $res = $r;
      }
      else {
        die "error:arithmetic_conversion_2";
      }
    }

  # If high signed the operand can be represented all types of unsigned operands
    elsif (
      (
           $ls eq "unsigned"
        && $rs eq "signed"
        && $type->{$l}->{order} < $type->{$r}->{order}
        && $type->{$r}->{bits} > $type->{$l}->{bits}
      )
      || ( $ls eq "signed"
        && $rs eq "unsigned"
        && $type->{$l}->{order} > $type->{$r}->{order}
        && $type->{$l}->{bits} > $type->{$r}->{bits} )
      )
    {
      # converted to signed operand
      if ( $ls eq "signed" ) {
        $res = $l;
      }
      elsif ( $rs eq "signed" ) {
        $res = $r;
      }
      else {
        die "error:arithmetic_conversion_3";
      }
    }

    # If signed operand is unable to represent all types of unsigned operands
    elsif (
      (
           $ls eq "unsigned"
        && $rs eq "signed"
        && $type->{$l}->{order} < $type->{$r}->{order}
        && $type->{$r}->{bits} <= $type->{$l}->{bits}
      )
      || ( $ls eq "signed"
        && $rs eq "unsigned"
        && $type->{$l}->{order} > $type->{$r}->{order}
        && $type->{$l}->{bits} <= $type->{$r}->{bits} )
      )
    {
      # converted to high unsigned and ranking operand
      if ( $ls eq "unsigned" ) {
        $res = "un" . $r;
      }
      elsif ( $rs eq "unsigned" ) {
        $res = "un" . $l;
      }
      else {
        die "error:arithmetic_conversion_4";
      }
    }
    else {
      die "error:arithmetic_conversion_5";
    }
  }
  return $res;
}

sub value_conversion {
  my ( $self, $bv, $bt, $at ) = @_;
  my $type       = $self->_get_type;
  my $debug_mode = $self->{config}->get('debug_mode');
  my ( $bs, $bty ) = split( / /, $bt, 2 );
  my ( $as, $aty ) = split( / /, $at, 2 );
  my $av = Math::BigInt->new(0);

  if ( $bv < 0
    && $type->{$bt}->{bits} <= $type->{$at}->{bits}
    && $bs eq "signed"
    && $as eq "unsigned" )
  {
    if ( $at eq "unsigned int" ) {
      $av = $bv + $type->{'unsigned int'}->{max} + 1;
    }
    elsif ( $at eq "unsigned long" ) {
      $av = $bv + $type->{'unsigned long'}->{max} + 1;
    }
    elsif ( $at eq "unsigned long long" ) {
      $av = $bv + $type->{'unsigned long long'}->{max} + 1;
    }
    else { die; }
  }
  else {
    $av = $bv;
  }

  return $av;
}

sub arithmetic_expectation_value {
  my ( $self, $n, $varset ) = @_;
  my $type       = $self->_get_type;
  my $debug_mode = $self->{config}->get('debug_mode');

  my $val0 = $n->{in}->[0]->{val}  if ( exists $n->{in}->[0] );
  my $val1 = $n->{in}->[1]->{val}  if ( exists $n->{in}->[1] );
  my $bt0  = $n->{in}->[0]->{type} if ( exists $n->{in}->[0] );
  my $bt1  = $n->{in}->[1]->{type} if ( exists $n->{in}->[1] );
  my $ans  = 0;
  my $at   = $n->{out}->{type};
  my ( $as,  $aty )  = split( / /, $at,  2 );
  my ( $bs0, $bty0 ) = split( / /, $bt0, 2 ) if ( exists $n->{in}->[0] );
  my ( $bs1, $bty1 ) = split( / /, $bt1, 2 ) if ( exists $n->{in}->[1] );
  my $in0       = $n->{in}->[0]              if ( exists $n->{in}->[0] );
  my $in1       = $n->{in}->[1]              if ( exists $n->{in}->[1] );
  my $ref0_type = $in0->{ref}->{out}->{type} if ( exists $n->{in}->[0] );
  my $ref1_type = $in1->{ref}->{out}->{type} if ( exists $n->{in}->[1] );
  my ( $ref0_si, $ref0_ty ) = split( / /, $ref0_type, 2 )
    if ( exists $n->{in}->[0] );
  my ( $ref1_si, $ref1_ty ) = split( / /, $ref1_type, 2 )
    if ( exists $n->{in}->[1] );
  my $ref0_val = $in0->{ref}->{out}->{val} if ( exists $n->{in}->[0] );
  my $ref1_val = $in1->{ref}->{out}->{val} if ( exists $n->{in}->[1] );

  my $min        = $type->{$at}->{min};
  my $max        = $type->{$at}->{max};
  my $top_num    = 0;
  my $bottom_num = 0;
  if ( $as eq "signed" || $as eq "unsigned" ) {
    $min = Math::BigInt->new( $type->{$at}->{min} );
    $max = Math::BigInt->new( $type->{$at}->{max} );
    $ans = Math::BigInt->new(0);
  }
  if ( $n->{otype} eq '+'
    || $n->{otype} eq '-'
    || $n->{otype} eq '*'
    || $n->{otype} eq '/' )
  {
    if ( $at eq "float" || $at eq "double" || $at eq "long double" ) {
      if ( $ref0_si eq "signed" || $ref0_si eq "unsigned" ) {
        $self->type_promotion_value( $n->{in}->[0], $varset, $at );
      }
      elsif ( $ref1_si eq "signed" || $ref1_si eq "unsigned" ) {
        $self->type_promotion_value( $n->{in}->[1], $varset, $at );
      }
    }
  }

  if ( exists $n->{in}->[0] ) {
    $val0 = Math::BigInt->new($val0) if ( ref $val0 ne 'Math::BigInt' );
  }

  if ( exists $n->{in}->[1] ) {
    $val1 = Math::BigInt->new($val1) if ( ref $val1 ne 'Math::BigInt' );
  }

  if ( $n->{otype} eq '+' ) {
    $ans = $self->arith_add_and_sub( $n, $varset, $n->{otype} );
  }
  elsif ( $n->{otype} eq '-' ) {
    $ans = $self->arith_add_and_sub( $n, $varset, $n->{otype} );
  }
  elsif ( $n->{otype} eq '*' ) { $ans = $self->arith_mul( $n, $varset ); }
  elsif ( $n->{otype} eq '/' ) { $ans = $self->arith_div( $n, $varset ); }
  elsif ( $n->{otype} eq '%' ) { $ans = $self->arith_mod( $n, $varset ); }
  elsif ( $n->{otype} eq '<<' ) { $ans = $self->arith_lshift( $n, $varset ); }
  elsif ( $n->{otype} eq '>>' ) { $ans = $self->arith_rshift( $n, $varset ); }
  elsif ( $n->{otype} eq '<' ) {
    $ans = ( $val0 < $val1 ) ? 1 : 0;
  }
  elsif ( $n->{otype} eq '>' ) {
    $ans = ( $val0 > $val1 ) ? 1 : 0;
  }
  elsif ( $n->{otype} eq '<=' ) {
    $ans = ( $val0 <= $val1 ) ? 1 : 0;
  }
  elsif ( $n->{otype} eq '>=' ) {
    $ans = ( $val0 >= $val1 ) ? 1 : 0;
  }
  elsif ( $n->{otype} eq '==' ) {
    $ans = ( $val0 == $val1 ) ? 1 : 0;
  }
  elsif ( $n->{otype} eq '!=' ) {
    $ans = ( $val0 != $val1 ) ? 1 : 0;
  }
  elsif ( $n->{otype} eq '&&' ) {
    $ans = ( $val0 != 0 && $val1 != 0 ) ? 1 : 0;
  }
  elsif ( $n->{otype} eq '||' ) {
    $ans = ( $val0 == 0 && $val1 == 0 ) ? 0 : 1;
  }
  elsif ( $n->{otype} eq "|" ) {
    $ans =
      ( $val0 < 0 || $val1 < 0 )
      ? -( ~( $val0 | $val1 ) + 1 )
      : $val0 | $val1;
  }
  elsif ( $n->{otype} eq "^" ) {
    $ans =
      ( ( $val0 < 0 && $val1 >= 0 ) && ( $val0 >= 0 && $val1 < 0 ) )
      ? -( ~( $val0 ^ $val1 ) + 1 )
      : $val0 ^ $val1;
  }
  elsif ( $n->{otype} eq "&" ) {
    $ans =
      ( $val0 < 0 && $val1 < 0 )
      ? -( ~( $val0 & $val1 ) + 1 )
      : $val0 & $val1;
  }
  elsif ( $n->{otype} eq '(signed int)' ) {
    $ans = $self->arith_cast( $n, $varset );
  }
  else {
    die "n->{otype} = '$n->{otype}'";
  }
  if ( $ans eq "NaN" ) {
    print "NaN is occurd.\n" if ($debug_mode);
    $ans = "UNDEF";
  }

  return $ans;
}

sub type_promotion_value {
  my ( $self, $n, $varset, $at ) = @_;
  my $types        = $self->_get_type;
  my $avoide_undef = $self->_get_undef_avoide;

  my $debug_mode = $self->{config}->get('debug_mode');
  my $n_ref      = $n->{ref};

  my $at_min = $types->{$at}->{min};
  my $at_max = $types->{$at}->{max};
  my $val    = $n->{val};
  my $type   = $n->{ref}->{out}->{type};
  my $bt_min = $types->{$type}->{min};
  my $bt_max = $types->{$type}->{max};
  my ( $bt, $bty ) = split( / /, $type, 2 );
  my $i_rmin = Math::BigInt->new(0);
  my $i_rmax = Math::BigInt->new(0);

  if ( $val < $at_min || $at_max < $val ) {
    if ( $avoide_undef == 0 ) { $n->{val} = "UNDEF"; }
    else {
      print "TPV: Floating Avoid Overflow\n" if ($debug_mode);
      $i_rmax = $at_max - $val;
      $i_rmin = $at_min - $val;
      if ( $bt eq "unsigned" ) {
        $i_rmax = $bt_max - $val + 1 + $at_max;
        $i_rmin = $bt_max - $val + 1;
        if ( $bt_max < $i_rmax ) { $i_rmax = $bt_max; }
      }
      else {
        if ( $bt_max < $i_rmax ) { $i_rmax = $bt_max; }
        if ( $i_rmin < $bt_min ) { $i_rmin = $bt_min; }
      }
      $self->new_ins_add( $n, $i_rmin, $i_rmax, $varset );
      $val = $n->{val};
      if ( $val < $at_min || $at_max < $val ) {
        print "TPV: Floating Avoid Overflow[FAILED]\n" if ($debug_mode);
        $n->{ref}->{out}->{val} = "UNDEF";
      }
    }
  }
}

# Generator/Arith/Add|Sub ...
sub arith_add_and_sub {
  my ( $self, $n, $varset, $otype ) = @_;
  my $type         = $self->_get_type;
  my $avoide_undef = $self->_get_undef_avoide;
  my $debug_mode   = $self->{config}->get('debug_mode');

  exists $n->{in}->[0] && exists $n->{in}->[1]
    || die "less than two children.";

  my $in0  = $n->{in}->[0];
  my $in1  = $n->{in}->[1];
  my $val0 = $in0->{val};
  my $val1 = $in1->{val};
  my $bt0  = $in0->{ref}->{out}->{type};
  my $bt1  = $in1->{ref}->{out}->{type};
  my $ans  = 0;
  my $at   = $n->{out}->{type};
  my ( $as,  $aty )  = split( / /, $at,  2 );
  my ( $bs0, $bty0 ) = split( / /, $bt0, 2 );
  my ( $bs1, $bty1 ) = split( / /, $bt1, 2 );
  my $ref0_type = $in0->{ref}->{out}->{type};
  my $ref1_type = $in1->{ref}->{out}->{type};
  my ( $ref0_si, $ref0_ty ) = split( / /, $ref0_type, 2 );
  my ( $ref1_si, $ref1_ty ) = split( / /, $ref1_type, 2 );
  my $ref0_val = $in0->{ref}->{out}->{val};
  my $ref1_val = $in1->{ref}->{out}->{val};
  my $rmax     = Math::BigFloat->new(0);
  my $rmin     = Math::BigFloat->new(0);
  my $i_rmin   = 0;
  my $i_rmax   = 0;

  if ( $as eq "signed" || $as eq "unsigned" ) {
    $val0 = Math::BigInt->new($val0) if ( ref $val0 ne 'Math::BigInt' );
    $val1 = Math::BigInt->new($val1) if ( ref $val1 ne 'Math::BigInt' );

    if   ( $otype eq '+' ) { $ans = $val0 + $val1; }
    else                   { $ans = $val0 - $val1; }

    my $min = Math::BigInt->new( $type->{$at}->{min} );
    my $max = Math::BigInt->new( $type->{$at}->{max} );

    if ( $as eq "unsigned" ) {
      $ans = ( $ans % ( $max + 1 ) );
    }
    elsif ( $as eq "signed" ) {

      # Overflow processing
      if ( $ans < $min || $max < $ans ) {
        if ( $avoide_undef == 0 ) { $ans = "UNDEF"; }
        elsif ( $avoide_undef == 2 ) {
          if ( $otype eq '+' ) {
            print "+ : Avoid Overflow\n" if ($debug_mode);
          }
          elsif ( $otype eq '-' ) {
            print "- : Avoid Overflow\n" if ($debug_mode);
          }
          else { die; }

          if ( $n->{ntype} eq "op" ) {
            change_arithmetic_operators($n);    #TODO
            $ans = $self->arithmetic_expectation_value( $n, $varset );    #TODO
          }
          else { die; }
        }
        else { die; }
      }
      else { ; }
    }
    else { die "as = '$as'"; }
  }

  #   elsif($FLOAT_MODE == 1)
  else {

    $val0 = Math::BigInt->new($val0) if ( ref $val0 ne 'Math::BigInt' );
    $val1 = Math::BigInt->new($val1) if ( ref $val1 ne 'Math::BigInt' );

    if   ( $otype eq '+' ) { $ans = $val0 + $val1; }
    else                   { $ans = $val0 - $val1; }

    my $min = Math::BigInt->new( $type->{$at}->{min} );
    my $max = Math::BigInt->new( $type->{$at}->{max} );

    # Overflow processing
    if ( $ans < $min || $max < $ans ) {
      if ( $avoide_undef == 0 ) { $ans = "UNDEF"; }
      elsif ( $avoide_undef > 0 ) {
        print "$otype : Floating Avoid Overflow\n" if ($debug_mode);

        # The overflow processing to type the number of bits is large operand
        if ( $otype eq '+' ) {
          $i_rmax = $max - ( $val0 + $val1 );
          $i_rmin = 1 - ( $val0 + $val1 );
          if ( $type->{$bt0}->{bits} > $type->{$bt1}->{bits} ) {
            if ( $type->{$bt0}->{max} < $i_rmax ) {
              $i_rmax = $type->{$bt0}->{max};
            }
            if ( $type->{$bt0}->{max} < $i_rmin ) {
              $i_rmin = $type->{$bt0}->{max};
            }    # In this case undefined can not be prevented
            elsif ( $i_rmin < $type->{$bt0}->{min} ) {
              $i_rmin = $type->{$bt0}->{min};
            }
            $self->new_ins_add( $in0, $i_rmin, $i_rmax, $varset );
            $val0 = $in0->{val};
            $ans  = $val0 + $val1;

            # If you are unable to undefined avoided by left-hand operand
            if ( $ans < $min || $max < $ans ) {
              $i_rmax = $max - ( $val0 + $val1 );
              $i_rmin = 1 - ( $val0 + $val1 );
              if ( $type->{$bt1}->{max} < $i_rmax ) {
                $i_rmax = $type->{$bt1}->{max};
              }
              if ( $type->{$bt1}->{max} < $i_rmin ) {
                $i_rmin = $type->{$bt1}->{max};
              }    # In this case undefined can not be prevented
              elsif ( $i_rmin < $type->{$bt1}->{min} ) {
                $i_rmin = $type->{$bt1}->{min};
              }
              $self->new_ins_add( $in1, $i_rmin, $i_rmax, $varset );
              $ans = $val0 + $in1->{val};
            }
          }
          else {
            if ( $type->{$bt1}->{max} < $i_rmax ) {
              $i_rmax = $type->{$bt1}->{max};
            }
            if ( $type->{$bt1}->{max} < $i_rmin ) {
              $i_rmin = $type->{$bt1}->{max};
            }
            elsif ( $i_rmin < $type->{$bt1}->{min} ) {
              $i_rmin = $type->{$bt1}->{min};
            }
            $self->new_ins_add( $in1, $i_rmin, $i_rmax, $varset );
            $val1 = $in1->{val};
            $ans  = $val0 + $val1;
            if ( $ans < $min || $max < $ans ) {
              $i_rmax = $max - ( $val0 + $val1 );
              $i_rmin = 1 - ( $val0 + $val1 );
              if ( $type->{$bt0}->{max} < $i_rmax ) {
                $i_rmax = $type->{$bt0}->{max};
              }
              if ( $type->{$bt0}->{max} < $i_rmin ) {
                $i_rmin = $type->{$bt0}->{max};
              }
              elsif ( $i_rmin < $type->{$bt0}->{min} ) {
                $i_rmin = $type->{$bt0}->{min};
              }
              $self->new_ins_add( $in0, $i_rmin, $i_rmax, $varset );
              $ans = $in0->{val} + $val1;
            }
          }
        }
        else {

          if ( $type->{$bt0}->{bits} > $type->{$bt1}->{bits} ) {
            $i_rmax = ( $max - ( $val0 - $val1 ) );
            $i_rmin = ( 1 - ( $val0 - $val1 ) );
            if ( $type->{$bt0}->{max} < $i_rmax ) {
              $i_rmax = $type->{$bt0}->{max};
            }
            elsif ( $i_rmax < $type->{$bt0}->{min} ) {
              $i_rmax = $type->{$bt0}->{min};
            }
            if ( $type->{$bt0}->{max} < $i_rmin ) {
              $i_rmin = $type->{$bt0}->{max};
            }
            elsif ( $i_rmin < $type->{$bt0}->{min} ) {
              $i_rmin = $type->{$bt0}->{min};
            }
            $self->new_ins_add( $in0, $i_rmin, $i_rmax, $varset );
            $val0 = $in0->{val};
            $ans  = $val0 - $val1;

            # If you are unable to undefined avoided by left-hand operand
            if ( $ans < $min || $max < $ans ) {
              if ( $ans < $min ) {
                $i_rmax = ( -$min + ( $val0 - $val1 ) );
                $i_rmin = ( 1 + ( $val0 - $val1 ) );
              }
              elsif ( $max < $ans ) {
                $i_rmax = ( $val0 - $val1 ) - 1;
                $i_rmin = ( $val0 - $val1 ) - $max;
              }
              if ( $type->{$bt1}->{max} < $i_rmax ) {
                $i_rmax = $type->{$bt1}->{max};
              }
              elsif ( $i_rmax < $type->{$bt1}->{min} ) {
                $i_rmax = $type->{$bt1}->{min};
              }
              if ( $type->{$bt1}->{max} < $i_rmin ) {
                $i_rmin = $type->{$bt1}->{max};
              }    # In this case undefined can not be prevented
              elsif ( $i_rmin < $type->{$bt1}->{min} ) {
                $i_rmin = $type->{$bt1}->{min};
              }
              $self->new_ins_add( $in1, $i_rmin, $i_rmax, $varset );
              $ans = $val0 - $in1->{val};
            }
          }
          else {
            if ( $ans < $min ) {
              $i_rmax = ( -$min + ( $val0 - $val1 ) );
              $i_rmin = ( 1 + ( $val0 - $val1 ) );
            }
            elsif ( $max < $ans ) {
              $i_rmax = ( $val0 - $val1 ) - 1;
              $i_rmin = ( $val0 - $val1 ) - $max;
            }
            if ( $type->{$bt1}->{max} < $i_rmax ) {
              $i_rmax = $type->{$bt1}->{max};
            }
            elsif ( $i_rmax < $type->{$bt1}->{min} ) {
              $i_rmax = $type->{$bt1}->{min};
            }
            if ( $type->{$bt1}->{max} < $i_rmin ) {
              $i_rmin = $type->{$bt1}->{max};
            }
            elsif ( $i_rmin < $type->{$bt1}->{min} ) {
              $i_rmin = $type->{$bt1}->{min};
            }
            $self->new_ins_add( $in1, $i_rmin, $i_rmax, $varset );
            $val1 = $in1->{val};
            $ans  = $val0 - $val1;
            if ( $ans < $min || $max < $ans ) {
              $i_rmax = ( $max - ( $val0 - $val1 ) );
              $i_rmin = ( 1 - ( $val0 - $val1 ) );
              if ( $type->{$bt0}->{max} < $i_rmax ) {
                $i_rmax = $type->{$bt0}->{max};
              }
              elsif ( $i_rmax < $type->{$bt0}->{min} ) {
                $i_rmax = $type->{$bt0}->{min};
              }
              if ( $type->{$bt0}->{max} < $i_rmin ) {
                $i_rmin = $type->{$bt0}->{max};
              }
              elsif ( $i_rmin < $type->{$bt0}->{min} ) {
                $i_rmin = $type->{$bt0}->{min};
              }
              $self->new_ins_add( $in0, $i_rmin, $i_rmax, $varset );
              $ans = $in0->{val} - $val1;
            }
          }
        }
        if ( $ans < $min || $max < $ans ) {
          print "Floating Avoid Overflow : $otype [FAILED]\n"
            if ($debug_mode);
          $ans = "UNDEF";
        }
      }
    }
  }
  return $ans;
}

sub arith_mul {
  my ( $self, $n, $varset ) = @_;
  my $type         = $self->_get_type;
  my $avoide_undef = $self->_get_undef_avoide;
  my $debug_mode   = $self->{config}->get('debug_mode');

  exists $n->{in}->[0] && exists $n->{in}->[1]
    || die "less than two children.";

  my $in0  = $n->{in}->[0];
  my $in1  = $n->{in}->[1];
  my $val0 = $in0->{val};
  my $val1 = $in1->{val};
  my $bt0  = $in0->{ref}->{out}->{type};
  my $bt1  = $in1->{ref}->{out}->{type};
  my $ans  = 0;
  my $at   = $n->{out}->{type};
  my ( $as,  $aty )  = split( / /, $at,  2 );
  my ( $bs0, $bty0 ) = split( / /, $bt0, 2 );
  my ( $bs1, $bty1 ) = split( / /, $bt1, 2 );
  my $ref0_type = $in0->{ref}->{out}->{type};
  my $ref1_type = $in1->{ref}->{out}->{type};
  my ( $ref0_si, $ref0_ty ) = split( / /, $ref0_type, 2 );
  my ( $ref1_si, $ref1_ty ) = split( / /, $ref1_type, 2 );
  my $ref0_val = $in0->{ref}->{out}->{val};
  my $ref1_val = $in1->{ref}->{out}->{val};
  my $rmax     = Math::BigFloat->new(0);
  my $rmin     = Math::BigFloat->new(0);
  my $i_rmin   = 0;
  my $i_rmax   = 0;

  if ( $as eq "signed" || $as eq "unsigned" ) {
    $val0 = Math::BigInt->new($val0) if ( ref $val0 ne 'Math::BigInt' );
    $val1 = Math::BigInt->new($val1) if ( ref $val1 ne 'Math::BigInt' );

    $ans = $val0 * $val1;
    my $min = Math::BigInt->new( $type->{$at}->{min} );
    my $max = Math::BigInt->new( $type->{$at}->{max} );

    if ( $as eq "unsigned" ) {
      $ans = ( $ans % ( $max + 1 ) );    # Wrap round
    }
    elsif ( $as eq "signed" ) {

      # Overflow processing
      if ( $ans < $min || $max < $ans ) {
        my $new_ans = $val0 / $val1;
        if ( $avoide_undef == 0 ) { $ans = "UNDEF"; }

#               elsif ($avoide_undef == 2 && $min <= $new_ans && $new_ans <= $max)
        elsif ( $min <= $new_ans && $new_ans <= $max ) {
          print "* : Avoid Overflow\n" if ($debug_mode);

          if ( $n->{ntype} eq "op" ) {
            change_arithmetic_operators($n);
            $ans = $self->arithmetic_expectation_value( $n, $varset );
          }
          else { die; }
        }
        else {
          print "* : Avoid Overflow\n" if ($debug_mode);
          if ( $ans < $min ) {
            if ( $val1 < 0 ) {
              $i_rmax = -1 * $val1;
              if ( $val1 == $type->{$bt1}->{min} ) {
                $i_rmin = ( -1 * $val1 ) - 1;
              }    # In this case undefined can not be prevented
              $i_rmin = ( $type->{$bt1}->{min} / $val0 ) - $val1;    # Interim
            }
            else {
              $i_rmax = ( $type->{$bt1}->{min} / $val0 ) - $val1;
              $i_rmin = -1 * $val1;
              if ( $val1 == $type->{$bt1}->{min} ) {
                $i_rmin = ( -1 * $val1 ) - 1;
              }    # In this case undefined can not be prevented
            }
          }
          else {
            if ( $val1 < 0 ) {
              $i_rmax = -1 * $val1;
              if ( $val1 == $type->{$bt1}->{min} ) {
                $i_rmin = ( -1 * $val1 ) - 1;
              }    # In this case undefined can not be prevented
              $i_rmin = ( $type->{$bt1}->{max} / $val0 ) - $val1;    # Interim
            }
            else {
              $i_rmax = ( $type->{$bt1}->{max} / $val0 ) - $val1;
              $i_rmin = -1 * $val1;
              if ( $val1 == $type->{$bt1}->{min} ) {
                $i_rmin = ( -1 * $val1 ) - 1;
              }    # In this case undefined can not be prevented
            }
          }
          $self->new_ins_add( $in1, $i_rmin, $i_rmax, $varset );
          $ans = $val0 * $in1->{val};
          if ( $ans < $min || $max < $ans ) {
            print " $n->{otype} [FAILED]\n" if ($debug_mode);
            $ans = "UNDEF";
          }
        }
      }
      else { ; }
    }
    else { die "as = '$as'"; }
  }
  else {
    $val0 = Math::BigInt->new($val0) if ( ref $val0 ne 'Math::BigInt' );
    $val1 = Math::BigInt->new($val1) if ( ref $val1 ne 'Math::BigInt' );
    $ans  = $val0 * $val1;
    my $min = Math::BigInt->new( $type->{$at}->{min} );
    my $max = Math::BigInt->new( $type->{$at}->{max} );

    # Overflow processing
    if ( $ans < $min || $max < $ans ) {
      if ( $avoide_undef == 0 ) { $ans = "UNDEF"; }
      elsif ( $avoide_undef == 2 ) {
        print "* : Floating Avoid Overflow\n" if ($debug_mode);

        # The overflow processing to type the number of bits is large operand
        if ( $type->{$bt0}->{bits} > $type->{$bt1}->{bits} ) {
          if ( $val0 == $type->{$bt0}->{min} ) {
            $i_rmax = $type->{$bt0}->{max};
            $i_rmin = $type->{$bt0}->{max};
          }
          elsif ( $val0 < 0 ) {
            $i_rmax = -1 * $val0;
            if ( $ans < $min ) {
              $i_rmin = ( $min / $val1 ) - $val0;
            }
            else {
              $i_rmin = ( $max / $val1 ) - $val0;
            }
          }
          else {
            if ( $ans < $min ) {
              $i_rmax = ( $min / $val1 ) - $val0;
            }
            else {
              $i_rmax = ( $max / $val1 ) - $val0;
            }
            $i_rmin = -1 * $val0;
          }
          $self->new_ins_add( $in0, $i_rmin, $i_rmax, $varset );
          $val0 = $in0->{val};
          $ans  = $val0 * $val1;
        }
        else {
          if ( $val1 == $type->{$bt1}->{min} ) {
            $i_rmax = $type->{$bt1}->{max};
            $i_rmin = $type->{$bt1}->{max};
          }
          elsif ( $val1 < 0 ) {
            $i_rmax = -1 * $val1;
            if ( $ans < $min ) {
              $i_rmin = ( $min / $val0 ) - $val1;
            }
            else {
              $i_rmin = ( $max / $val0 ) - $val1;
            }
          }
          else {
            if ( $ans < $min ) {
              $i_rmax = ( $min / $val0 ) - $val1;
            }
            else {
              $i_rmax = ( $max / $val0 ) - $val1;
            }
            $i_rmin = -1 * $val1;
          }
          $self->new_ins_add( $in1, $i_rmin, $i_rmax, $varset );
          $val1 = $in1->{val};
          $ans  = $val0 * $val1;
        }
        if ( $ans < $min || $max < $ans ) {
          print "Floating Avoid Overflow : * [FAILED]\n"
            if ($debug_mode);
          $ans = "UNDEF";
        }
      }
    }
  }

  return $ans;

}

sub arith_div {
  my ( $self, $n, $varset ) = @_;
  my $type         = $self->_get_type;
  my $avoide_undef = $self->_get_undef_avoide;
  my $debug_mode   = $self->{config}->get('debug_mode');

  exists $n->{in}->[0] && exists $n->{in}->[1]
    || die "less than two children.";

  my $in0  = $n->{in}->[0];
  my $in1  = $n->{in}->[1];
  my $val0 = $in0->{val};
  my $val1 = $in1->{val};
  my $bt0  = $in0->{ref}->{out}->{type};
  my $bt1  = $in1->{ref}->{out}->{type};
  my $ans  = 0;
  my $at   = $n->{out}->{type};
  my ( $as,  $aty )  = split( / /, $at,  2 );
  my ( $bs0, $bty0 ) = split( / /, $bt0, 2 );
  my ( $bs1, $bty1 ) = split( / /, $bt1, 2 );
  my $ref0_type = $in0->{ref}->{out}->{type};
  my $ref1_type = $in1->{ref}->{out}->{type};
  my ( $ref0_si, $ref0_ty ) = split( / /, $ref0_type, 2 );
  my ( $ref1_si, $ref1_ty ) = split( / /, $ref1_type, 2 );
  my $ref0_val = $in0->{ref}->{out}->{val};
  my $ref1_val = $in1->{ref}->{out}->{val};
  my $rmax     = Math::BigFloat->new(0);
  my $rmin     = Math::BigFloat->new(0);
  my $i_rmin   = 0;
  my $i_rmax   = 0;

  $val0 = Math::BigInt->new($val0) if ( ref $val0 ne 'Math::BigInt' );
  $val1 = Math::BigInt->new($val1) if ( ref $val1 ne 'Math::BigInt' );

  # Check of the divide-by-zero
  if ( $val1 == 0 ) {
    if ( $avoide_undef == 0 ) {
      $ans = "UNDEF";
    }
    elsif ( $avoide_undef == 2 ) {
      my $ref1_ntype = $in1->{ref}->{ntype};
      print "/ : Avoid Undefined -> " if ($debug_mode);
      if ( $ref1_ntype eq "op" ) {
        my $ref1_otype = $in1->{ref}->{otype};
        print " $ref1_otype\n" if ($debug_mode);
        if ( $ref1_otype eq '<'
          || $ref1_otype eq '>'
          || $ref1_otype eq '<='
          || $ref1_otype eq '>='
          || $ref1_otype eq '=='
          || $ref1_otype eq '!=' )
        {
          change_relational_operators($n);
          $n->{in}->[1]->{ref}->{out}->{val} = 1;
          $n->{in}->[1]->{val} = $n->{in}->[1]->{ref}->{out}->{val};
          $val1 = $n->{in}->[1]->{val};
        }
        else {
          $i_rmax = $type->{$bt1}->{max};
          if ( $type->{$bt1}->{max} > $type->{$at}->{max} ) {
            $i_rmax = $type->{$at}->{max};
          }
          $i_rmin = 1;
          $self->new_ins_add( $in1, $i_rmin, $i_rmax, $varset );
          $val1 = $in1->{val};
        }
      }
      else {
        $i_rmax = $type->{$bt1}->{max};
        if ( $type->{$bt1}->{max} > $type->{$at}->{max} ) {
          $i_rmax = $type->{$at}->{max};
        }
        $i_rmin = 1;
        $self->change_value( $in1, $i_rmin, $i_rmax, $varset );
        $n->{in}->[1]->{val} = $n->{in}->[1]->{ref}->{out}->{val};
        $val1 = $n->{in}->[1]->{val};
      }
    }
    else { die; }
  }
  if ( $val1 == 0 ) {
    print "$n->{otype} [FAILED]\n" if ($debug_mode);
    $ans = "UNDEF";
  }
  else {
    $ans = $val0 / $val1;
  }

  if ( $ans ne "UNDEF" ) {
    my $min      = Math::BigInt->new( $type->{$at}->{min} );
    my $max      = Math::BigInt->new( $type->{$at}->{max} );
    my $ref0_min = Math::BigInt->new( $type->{$ref0_type}->{min} );
    my $ref0_max = Math::BigInt->new( $type->{$ref0_type}->{max} );
    my $ref1_min = Math::BigInt->new( $type->{$ref1_type}->{min} );
    my $ref1_max = Math::BigInt->new( $type->{$ref1_type}->{max} );
    if ( $as eq "unsigned" ) {
      $ans = ( $ans % ( $max + 1 ) );    # Wrap round
    }
    else {
      my $type0_float = 0;
      my $type1_float = 0;
      if ( $ref0_type eq "long double"
        || $ref0_type eq "double"
        || $ref0_type eq "float" )
      {
        $type0_float = 1;
      }
      if ( $ref1_type eq "long double"
        || $ref1_type eq "double"
        || $ref1_type eq "float" )
      {
        $type1_float = 1;
      }

      # Overflow processing
      # Overflow type after the operation is on the left side
      if ( $val0 < $min || $max < $val0 ) {
        if ( $avoide_undef == 0 ) { $ans = "UNDEF"; }
        else {
          print "/ : Floating Avoid Overflow(left)\n"
            if ($debug_mode);
          $i_rmax = $max - $val0;
          $i_rmin = $min - $val0;
          if ( $ref0_si eq "unsigned" ) {
            ;
          }
          else {
            if ( $i_rmin < $ref0_min ) { $i_rmin = $ref0_min; }
            if ( $ref0_max < $i_rmax ) { $i_rmax = $ref0_max; }
          }
          $self->new_ins_add( $in0, $i_rmin, $i_rmax, $varset );
          $val0 = $in0->{val};
          $ans  = $val0 / $val1;
        }
      }

      # Overflow type after the operation is in the right-hand side
      if ( $val1 < $min || $max < $val1 ) {
        if ( $avoide_undef == 0 ) { $ans = "UNDEF"; }
        else {
          print "/ : Floating Avoid Overflow(right)\n"
            if ($debug_mode);
          $i_rmax = $max - $val1;
          $i_rmin = $min - $val1;
          if ( $ref1_si eq "unsigned" ) {
            ;
          }
          else {
            if ( $i_rmin < $ref1_min ) { $i_rmin = $ref1_min; }
            if ( $ref1_max < $i_rmax ) { $i_rmax = $ref1_max; }
          }
          $self->new_ins_add( $in1, $i_rmin, $i_rmax, $varset );
          $val1 = $in1->{val};
          $ans  = $val0 / $val1;
        }
      }

      # Operation result is overflow
      if ( $ans < $min || $max < $ans ) {
        my $new_ans = $val0 * $val1;
        if ( $avoide_undef == 0 ) { $ans = "UNDEF"; }
        elsif ( $min <= $new_ans
          && $new_ans <= $max
          && $type0_float + $type1_float != 1 )
        {
          # If even of there unsigned or sign either of type
          print "/ : Avoid Overflow:1\n" if ($debug_mode);
          if ( $n->{ntype} eq "op" ) {
            change_arithmetic_operators($n);
            $ans = $self->arithmetic_expectation_value( $n, $varset );
          }
          else { die; }
        }
        else {
          print "/ : Avoid Overflow:2\n" if ($debug_mode);

          # The undefined avoid processing to more number of bits is large
          if ( $ans < $min || $max < $ans ) {
            if ( $type->{$bt0}->{bits} > $type->{$bt1}->{bits} ) {
              $i_rmax = ( $type->{$bt0}->{min} * $val1 ) - $val0;
              $i_rmin = ( $type->{$bt0}->{max} * $val1 ) - $val0;
              if ( $ref0_max < $i_rmax ) { $i_rmax = $ref0_max; }
              if ( $i_rmax < $ref0_min ) { $i_rmin = $ref0_min; }
              if ( $i_rmax - $i_rmin < 0 ) {
                $i_rmax =
                  ( $type->{$bt0}->{max} * $val1 ) - $val0;
                $i_rmin =
                  ( $type->{$bt0}->{min} * $val1 ) - $val0;
              }
              $self->new_ins_add( $in0, $i_rmin, $i_rmax, $varset );
              $val0 = $in0->{val};
              $ans  = $val0 / $val1;
            }
            else {
              $i_rmax = ( $val0 / $type->{$bt1}->{min} ) - $val1;
              $i_rmin = ( $val0 / $type->{$bt1}->{max} ) - $val1;
              if ( $ref1_max < $i_rmax ) { $i_rmax = $ref1_max; }
              if ( $i_rmax < $ref1_min ) { $i_rmin = $ref1_min; }
              if ( $i_rmax - $i_rmin < 0 ) {
                $i_rmax =
                  ( $val0 / $type->{$bt1}->{max} ) - $val1;
                $i_rmin =
                  ( $val0 / $type->{$bt1}->{min} ) - $val1;
              }
              $self->new_ins_add( $in1, $i_rmin, $i_rmax, $varset );
              $val1 = $in1->{val};
              $ans  = $val0 / $val1;
            }
          }
        }

        if ( $ans < $min || $max < $ans ) {
          print "Avoid Overflow : $n->{otype} [FAILED]\n"
            if ($debug_mode);
          $ans = "UNDEF";
        }
      }
      else { ; }

      # The processing for floating-point
      if ( $as ne "signed" ) {
        if ( $val0 % $val1 == 0 ) {
          ;    # If you are divisible
        }
        else {
          if ( $avoide_undef == 0 ) { $ans = "UNDEF"; }
          else {
            print "/ : Float Avoid Decimal\n" if ($debug_mode);
            if ( ( 0 < $val0 && $val1 < 0 )
              || ( $val1 > 0 && 0 > $val0 ) )
            {
              $i_rmax = $val1 - ( $val0 % $val1 );
              $i_rmin = $val1 - ( $val0 % $val1 );
            }
            else {
              $i_rmax = -( $val0 % $val1 );
              $i_rmin = -( $val0 % $val1 );
            }

        # When the operation variables plus that the left-hand side to overflow,
        # I convert the right-hand side to 1
            if ( $i_rmin < $ref0_min || $ref0_max < $i_rmax ) {
              $i_rmax = -$val1 + 1;    # Interim
              $i_rmin = -$val1 + 1;    # Interim
              if ( $i_rmax < $min ) {
                $i_rmax = -$val1 - 1;
                $i_rmin = -$val1 - 1;
              }
              elsif ( $i_rmax > $max ) {
                $i_rmax = -$val1 - 1;    # Interim
                $i_rmin = -$val1 - 1;    # Interim
              }
              $self->new_ins_add( $in1, $i_rmin, $i_rmax, $varset );
              $val1 = $in1->{val};
              $ans  = $val0 / $val1;
            }
            else {
              $self->new_ins_add( $in0, $i_rmin, $i_rmax, $varset );
              $val0 = $in0->{val};
              $ans  = $val0 / $val1;
            }
            if ( $val0 % $val1 != 0 ) {
              print "/ : Float Avoid Decimal [FAILED]\n"
                if ($debug_mode);
              $ans = "UNDEF";
            }
          }
        }
      }
    }
  }
  else { ; }
  return $ans;
}

sub arith_mod {
  my ( $self, $n, $varset ) = @_;
  my $type         = $self->_get_type;
  my $avoide_undef = $self->_get_undef_avoide;
  my $debug_mode   = $self->{config}->get('debug_mode');

  exists $n->{in}->[0] && exists $n->{in}->[1]
    || die "less than two children.";

  my $in0  = $n->{in}->[0];
  my $in1  = $n->{in}->[1];
  my $val0 = $in0->{val};
  my $val1 = $in1->{val};
  my $bt0  = $in0->{ref}->{out}->{type};
  my $bt1  = $in1->{ref}->{out}->{type};
  my $ans  = 0;
  my $at   = $n->{out}->{type};
  my ( $as,  $aty )  = split( / /, $at,  2 );
  my ( $bs0, $bty0 ) = split( / /, $bt0, 2 );
  my ( $bs1, $bty1 ) = split( / /, $bt1, 2 );
  my $i_rmin = 0;
  my $i_rmax = 0;

  if ( $as eq "signed" || $as eq "unsigned" ) {
    $val0 = Math::BigInt->new($val0) if ( ref $val0 ne 'Math::BigInt' );
    $val1 = Math::BigInt->new($val1) if ( ref $val1 ne 'Math::BigInt' );

    if ( $val1 == 0 ) {
      if ( $avoide_undef == 0 ) {
        $ans = "UNDEF";
      }
      elsif ( $avoide_undef == 2 ) {
        my $ref1_ntype = $in1->{ref}->{ntype};
        print "% : Avoid Undefined ->" if ($debug_mode);
        if ( $ref1_ntype eq "op" ) {
          my $ref1_otype = $in1->{ref}->{otype};
          print " $ref1_otype\n" if ($debug_mode);
          if ( $ref1_otype eq '<'
            || $ref1_otype eq '>'
            || $ref1_otype eq '<='
            || $ref1_otype eq '>='
            || $ref1_otype eq '=='
            || $ref1_otype eq '!=' )
          {
            change_relational_operators($n);
            $n->{in}->[1]->{ref}->{out}->{val} = 1;
            $n->{in}->[1]->{val} =
              $n->{in}->[1]->{ref}->{out}->{val};
            $val1 = $n->{in}->[1]->{val};
          }
          else {
            $i_rmax = $type->{$bt1}->{max};
            $i_rmin = 1;
            $self->new_ins_add( $in1, $i_rmin, $i_rmax, $varset );
            $val1 = $in1->{val};
          }
        }
        else {
          $i_rmax = $type->{$bt1}->{max};
          $i_rmin = 1;
          $self->change_value( $in1, $i_rmin, $i_rmax, $varset );
          $n->{in}->[1]->{val} = $n->{in}->[1]->{ref}->{out}->{val};
          $val1 = $n->{in}->[1]->{val};
        }
      }
      else { die; }
    }

    if ( $val1 == 0 ) {
      print "$n->{otype} [FAILED]\n" if ($debug_mode);
      $ans = "UNDEF";
    }
    else {
      $ans = $val0 % $val1;

      # If the division result is negative, it is truncated to 0 direction
      if ( $val0 < 0 && 0 < $ans || 0 < $val0 && $ans < 0 ) {
        $ans -= $val1;
      }
    }

    if ( $ans ne "UNDEF" ) {
      my $min = Math::BigInt->new( $type->{$at}->{min} );
      my $max = Math::BigInt->new( $type->{$at}->{max} );

      if ( $as eq "unsigned" ) {
        $ans = ( $ans % ( $max + 1 ) );    # Wrap round
      }
      elsif ( $as eq "signed" ) {

        #Overflow processing
        if ( $ans < $min || $max < $ans ) {
          if ( $avoide_undef == 0 ) {
            $ans = "UNDEF";
          }
          else {
            $i_rmax = 0;
            $i_rmin = 0;
            print "% : Avoid Overflow\n" if ($debug_mode);
            $i_rmax = -1 * $type->{$bt1}->{min} - $val0;
            $i_rmin = -1 * $type->{$bt1}->{max} - $val0;
            $self->new_ins_add( $in1, $i_rmin, $i_rmax, $varset );
            $val1 = $in1->{val};
            $ans  = $val0 % $val1;

            if ( $ans < $min || $max < $ans ) {
              print "$n->{otype} [FAILED]\n" if ($debug_mode);
              $ans = "UNDEF";
            }
          }
        }
        else { ; }
      }
      else { die; }
    }
    else { ; }
  }
  else { die; }

  return $ans;

}

sub arith_lshift {
  my ( $self, $n, $varset ) = @_;
  my $type         = $self->_get_type;
  my $avoide_undef = $self->_get_undef_avoide;
  my $debug_mode   = $self->{config}->get('debug_mode');

  exists $n->{in}->[0] && exists $n->{in}->[1]
    || die "less than two children.";

  my $in0  = $n->{in}->[0];
  my $in1  = $n->{in}->[1];
  my $val0 = $in0->{val};
  my $val1 = $in1->{val};
  my $bt0  = $in0->{ref}->{out}->{type};
  my $bt1  = $in1->{ref}->{out}->{type};
  my $ans  = 0;
  my $at   = $n->{out}->{type};
  my ( $as,  $aty )  = split( / /, $at,  2 );
  my ( $bs0, $bty0 ) = split( / /, $bt0, 2 );
  my ( $bs1, $bty1 ) = split( / /, $bt1, 2 );
  my $i_rmin = Math::BigInt->new(0);
  my $i_rmax = Math::BigInt->new(0);

  if ( $as eq "signed" || $as eq "unsigned" ) {
    $val0 = Math::BigInt->new($val0) if ( ref $val0 ne 'Math::BigInt' );
    $val1 = Math::BigInt->new($val1) if ( ref $val1 ne 'Math::BigInt' );

    if ( $val1 < 0 ) {
      if ( $avoide_undef == 0 ) {
        $ans = "UNDEF";
      }
      elsif ( $avoide_undef == 2 ) {
        print "<<1 : Avoid Undefined\n" if ($debug_mode);
        my $ref1_ntype = $in1->{ref}->{ntype};
        if ( $ref1_ntype eq "op" ) {

          # performing undefined avoid twice when 'val1' is 'min' value
          if ( $val1 == $type->{$bt1}->{min} ) {
            $i_rmax = $type->{$bt1}->{max};
            $i_rmin = $type->{$bt1}->{max};
            $self->new_ins_add( $in1, $i_rmin, $i_rmax, $varset );
            $val1 = $in1->{val};
          }
          $i_rmax = -1 * $val1 + $type->{$bt1}->{bits} - 1;
          if ( $i_rmax > $type->{$bt1}->{max} ) {
            $i_rmax = $type->{$bt1}->{max};
          }
          $i_rmin = -1 * $val1;
          if ( $val1 == $type->{$bt1}->{min} ) {
            $i_rmin =
              ( -1 * $val1 ) - 1;    # I can not prevent undefined at this time
          }
          $self->new_ins_add( $in1, $i_rmin, $i_rmax, $varset );
          $val1 = $in1->{val};
        }
        else {
          $i_rmax = $type->{$bt0}->{bits} - 1;
          $i_rmin = 0;
          $self->change_value( $in1, $i_rmin, $i_rmax, $varset );
          $n->{in}->[1]->{val} = $n->{in}->[1]->{ref}->{out}->{val};
          $val1 = $n->{in}->[1]->{val};
        }
      }
      else { die; }
    }

    if ( $val1 < 0 ) {
      print "$n->{otype}:1 [FAILED]\n" if ($debug_mode);
      $ans = "UNDEF";
    }
    else {
      if ( $type->{$bt0}->{bits} <= $val1 ) {
        if ( $avoide_undef == 0 ) {
          $ans = "UNDEF";
        }
        elsif ( $avoide_undef == 2 ) {
          print "<<2 : Avoid Undefined\n" if ($debug_mode);
          my $ref1_ntype = $in1->{ref}->{ntype};
          if ( $ref1_ntype eq "op" ) {
            $i_rmax = -1 * $val1 + $type->{$bt0}->{bits} - 1;
            if ( $i_rmax > $type->{$bt1}->{max} ) {
              $i_rmax = $type->{$bt1}->{max};
            }
            $i_rmin = -1 * $val1;
            if ( $val1 == $type->{$bt1}->{min} ) {
              $i_rmin =
                ( -1 * $val1 ) - 1;   # I can not prevent undefined at this time
            }
            $self->new_ins_add( $in1, $i_rmin, $i_rmax, $varset );
            $val1 = $in1->{val};
          }
          else {
            $i_rmax = $type->{$bt0}->{bits} - 1;
            $i_rmin = 0;
            $self->change_value( $in1, $i_rmin, $i_rmax, $varset );
            $n->{in}->[1]->{val} =
              $n->{in}->[1]->{ref}->{out}->{val};
            $val1 = $n->{in}->[1]->{val};
          }
        }
        else { die; }
      }
    }

    if ( $val1 < 0 || $type->{$bt0}->{bits} <= $val1 ) {
      print "$n->{otype}:2 [FAILED]\n" if ($debug_mode);
      $ans = "UNDEF";
    }
    else {
      if ( $bs0 eq "unsigned" ) {
        $ans = ( $val0 << $val1 );
      }
      elsif ( $bs0 eq "signed" ) {
        if ( $val0 < 0 ) {
          if ( $avoide_undef == 0 ) {
            $ans = "UNDEF";
          }
          else {
            print "<<3 : Avoid Undefined\n" if ($debug_mode);

            # performing undefined avoid twice when 'val0' is 'min' value
            if ( $val0 == $type->{$bt0}->{min} ) {
              $i_rmax = $type->{$bt0}->{max};
              $i_rmin = $type->{$bt0}->{max};
              $self->new_ins_add( $in0, $i_rmin, $i_rmax, $varset );
              $val0 = $in0->{val};
            }
            $i_rmax =
              ( -1 * $val0 ) + ( $type->{$bt0}->{max} - ( -1 * $val0 ) );
            $i_rmin = ( -1 * $val0 );
            if ( $val0 == $type->{$bt0}->{min} ) {
              $i_rmin =
                ( -1 * $val0 ) - 1;    #I can not prevent undefined at this time
            }
            $self->new_ins_add( $in0, $i_rmin, $i_rmax, $varset );
            $val0 = $in0->{val};
          }
          if ( $val0 < 0 ) {
            print "$n->{otype}:3 [FAILED]\n" if ($debug_mode);
            $ans = "UNDEF";
          }
        }
        if ( $val0 >= 0 ) {
          $ans = ( $val0 << $val1 );

        }
      }
    }

    if ( $ans ne "UNDEF" ) {
      my $min = Math::BigInt->new( $type->{$at}->{min} );
      my $max = Math::BigInt->new( $type->{$at}->{max} );
      if ( $as eq "unsigned" ) {
        $ans = ( $ans % ( $max + 1 ) );    # Wrap round
      }
      elsif ( $as eq "signed" ) {

        # Overflow processing
        if ( $ans < $min || $max < $ans ) {
          if ( $avoide_undef == 0 ) { $ans = "UNDEF"; }
          elsif ( $avoide_undef == 2 ) {
            print "<< : Avoid Overflow\n" if ($debug_mode);

            if ( $n->{ntype} eq "op" ) {
              change_arithmetic_operators($n);
              $ans = $self->arithmetic_expectation_value( $n, $varset );
            }
            else { die; }
          }
          else { die; }
          if ( $ans < $min || $max < $ans ) {
            print "$n->{otype}:Overflow [FAILED]\n"
              if ($debug_mode);
            $ans = "UNDEF";
          }
        }
        else { ; }
      }
      else { die "as = '$as'"; }
    }
    else { ; }
  }
  else { die; }
  return $ans;

}

sub arith_rshift {
  my ( $self, $n, $varset ) = @_;
  my $type         = $self->_get_type;
  my $avoide_undef = $self->_get_undef_avoide;
  my $debug_mode   = $self->{config}->get('debug_mode');

  exists $n->{in}->[0] && exists $n->{in}->[1]
    || die "less than two children.";

  my $in0  = $n->{in}->[0];
  my $in1  = $n->{in}->[1];
  my $val0 = $in0->{val};
  my $val1 = $in1->{val};
  my $bt0  = $in0->{ref}->{out}->{type};
  my $bt1  = $in1->{ref}->{out}->{type};
  my $ans  = 0;
  my $at   = $n->{out}->{type};
  my ( $as,  $aty )  = split( / /, $at,  2 );
  my ( $bs0, $bty0 ) = split( / /, $bt0, 2 );
  my ( $bs1, $bty1 ) = split( / /, $bt1, 2 );
  my $i_rmin = Math::BigInt->new(0);
  my $i_rmax = Math::BigInt->new(0);

  if ( $as eq "signed" || $as eq "unsigned" ) {
    $val0 = Math::BigInt->new($val0) if ( ref $val0 ne 'Math::BigInt' );
    $val1 = Math::BigInt->new($val1) if ( ref $val1 ne 'Math::BigInt' );

    if ( $val1 < 0 ) {
      if ( $avoide_undef == 0 ) {
        $ans = "UNDEF";
      }
      elsif ( $avoide_undef == 2 ) {
        print ">>1 : Avoid Undefined\n" if ($debug_mode);
        my $ref1_ntype = $in1->{ref}->{ntype};
        if ( $ref1_ntype eq "op" ) {

          # 'val1' is undefined avoid twice when 'min'
          if ( $val1 == $type->{$bt1}->{min} ) {
            $i_rmax = $type->{$bt1}->{max};
            $i_rmin = $type->{$bt1}->{max};
            $self->new_ins_add( $in1, $i_rmin, $i_rmax, $varset );
            $val1 = $in1->{val};
          }
          $i_rmax = -1 * $val1 + $type->{$bt1}->{bits} - 1;
          if ( $i_rmax > $type->{$bt1}->{max} ) {
            $i_rmax = $type->{$bt1}->{max};
          }
          $i_rmin = -1 * $val1;
          if ( $val1 == $type->{$bt1}->{min} ) {
            $i_rmin =
              ( -1 * $val1 ) - 1;    #I can not prevent undefined at this time
          }
          $self->new_ins_add( $in1, $i_rmin, $i_rmax, $varset );
          $val1 = $in1->{val};
        }
        else {
          $i_rmax = $type->{$bt0}->{bits} - 1;
          $i_rmin = 0;
          $self->change_value( $in1, $i_rmin, $i_rmax, $varset );
          $n->{in}->[1]->{val} = $n->{in}->[1]->{ref}->{out}->{val};
          $val1 = $n->{in}->[1]->{val};
        }
      }
    }

    if ( $val1 < 0 ) {
      print "$n->{otype}:1 [FAILED]\n" if ($debug_mode);
      $ans = "UNDEF";
    }
    else {
      if ( $type->{$bt0}->{bits} <= $val1 ) {
        if ( $avoide_undef == 0 ) {
          $ans = "UNDEF";
        }
        elsif ( $avoide_undef == 2 ) {
          print ">>2 : Avoid Undefined\n" if ($debug_mode);
          my $ref1_ntype = $in1->{ref}->{ntype};
          if ( $ref1_ntype eq "op" ) {
            $i_rmax = -1 * $val1 + $type->{$bt0}->{bits} - 1;
            if ( $i_rmax > $type->{$bt1}->{max} ) {
              $i_rmax = $type->{$bt1}->{max};
            }
            $i_rmin = -1 * $val1;
            if ( $val1 == $type->{$bt1}->{min} ) {
              $i_rmin =
                ( -1 * $val1 ) - 1;    #I can not prevent undefined at this time
            }
            $self->new_ins_add( $in1, $i_rmin, $i_rmax, $varset );
            $val1 = $in1->{val};
          }
          else {
            $i_rmax = $type->{$bt0}->{bits} - 1;
            $i_rmin = 0;
            $self->change_value( $in1, $i_rmin, $i_rmax, $varset );    #TODO
            $n->{in}->[1]->{val} =
              $n->{in}->[1]->{ref}->{out}->{val};
            $val1 = $n->{in}->[1]->{val};
          }
        }
      }
    }

    if ( $ans eq "UNDEF" ) { ; }
    elsif ( $type->{$bt0}->{bits} <= $val1 ) {
      print "$n->{otype}:2 [FAILED]\n" if ($debug_mode);
      $ans = "UNDEF";
    }
    else {
      if ( $bs0 eq "unsigned" ) {
        $ans = int( $val0 / ( 2**$val1 ) );
      }
      elsif ( $bs0 eq "signed" ) {
        if ( $val0 >= 0 ) {
          $ans = int( $val0 / ( 2**$val1 ) );
        }
        else {
          if ( $avoide_undef == 0 ) {
            $ans = "UNDEF";
          }
          else {
            print ">>3 : Avoid Undefined\n" if ($debug_mode);

            # 'val0' is undefined avoid twice when 'min'
            if ( $val0 == $type->{$bt0}->{min} ) {
              $i_rmax = $type->{$bt0}->{max};
              $i_rmin = $type->{$bt0}->{max};
              $self->new_ins_add( $in0, $i_rmin, $i_rmax, $varset );
              $val0 = $in0->{val};
            }
            $i_rmax = $type->{$bt0}->{max};
            $i_rmin = -1 * $val0;
            if ( $val0 == $type->{$bt0}->{min} ) {
              $i_rmin = ( -1 * $val0 ) - 1;
            }
            $self->new_ins_add( $in0, $i_rmin, $i_rmax, $varset );
            $val0 = $in0->{val};
            $ans = int( $val0 / ( 2**$val1 ) );
            if ( $val0 < 0 ) {
              print "$n->{otype}:3 [FAILED]\n" if ($debug_mode);
              $ans = "UNDEF";
            }
          }
        }
      }
      else {
        $ans = ( $val0 >> $val1 );
      }
    }
  }
  else { die; }

  return $ans;

}

sub arith_cast {
  my ( $self, $n, $varset ) = @_;
  my $type         = $self->_get_type;
  my $avoide_undef = $self->_get_undef_avoide;
  my $debug_mode   = $self->{config}->get('debug_mode');

  exists $n->{in}->[0] || die "less than one children.";

  my $in0  = $n->{in}->[0];
  my $val0 = Math::BigInt->new( $in0->{val} );
  my $bt0  = $in0->{ref}->{out}->{type};
  my $ans  = 0;
  my $at   = $n->{out}->{type};
  my ( $as,  $aty )  = split( / /, $at,  2 );
  my ( $bs0, $bty0 ) = split( / /, $bt0, 2 );

  my $min      = Math::BigInt->new( $type->{$at}->{min} );
  my $max      = Math::BigInt->new( $type->{$at}->{max} );
  my $ref0_min = Math::BigInt->new( $type->{$bt0}->{min} );
  my $ref0_max = Math::BigInt->new( $type->{$bt0}->{max} );
  my $i_rmin   = Math::BigInt->new(0);
  my $i_rmax   = Math::BigInt->new(0);

  # Arithmetic processing
  $ans = $val0->as_int();

  # Overflow processing
  if ( $ans < $min || $max < $ans ) {
    if ( $avoide_undef == 0 ) { $ans = "UNDEF"; }
    else {
      print "(signed int) : Avoid Overflow\n" if ($debug_mode);
      $i_rmax = $max - $val0;
      if ( $ref0_max < $i_rmax ) { $i_rmax = $ref0_max; }
      $i_rmin = $min - $val0;
      if ( $i_rmin < $ref0_min ) { $i_rmin = $ref0_min; }
      $self->new_ins_add( $in0, $i_rmin, $i_rmax, $varset );
      $val0 = $in0->{val};
      $ans  = $val0;

      if ( $ans < $min || $max < $ans ) {
        print "(signed int) : Avoid Overflow [FAILED]\n"
          if ($debug_mode);
        $ans = "UNDEF";
      }
    }
  }
  else { ; }

  if ( $ans =~ /\.9/ ) { $ans = "UNDEF"; }
  else                 { ; }

  return $ans;

}

sub _get_type {
  my $self = shift;
  return $self->{config}->get('type');
}

sub _get_undef_avoide {
  my $self = shift;
  unless ( defined( $self->{avoide_undef} ) ) { die; }
  return $self->{avoide_undef};
}

##### Undefined avoidance process #####
sub new_ins_add {
  my ( $self, $n, $rmin, $rmax, $varset ) = @_;
  my $config = $self->{config};
  my $n_ref  = $n->{ref};
  my $n_type = $n_ref->{out}->{type};
  my $c      = random_range( $rmax, $rmin, $n_type, $config );

  my $num_new_var    = scalar @$varset;
  my $rand_classes   = rand @{ $config->get('classes') };
  my $rand_modifiers = rand @{ $config->get('modifiers') };
  my $rand_scopes    = rand @{ $config->get('scopes') };
  my ( $si, $t ) = split( / /, $n_type, 2 );
  $c = Math::BigInt->new($c);

  my $new_var = {
    name_type => "k",
    name_num  => "$num_new_var",
    type      => $n_type,
    ival      => $c,
    val       => $c,
    class     => $config->get('classes')->[$rand_classes],
    modifier  => $config->get('modifiers')->[$rand_modifiers],
    scope     => $config->get('scopes')->[$rand_scopes],
    used      => 1,
  };

  if ( defined( $self->{volatile_mode} )
    && $new_var->{scope} =~ /GLOBAL/
    && !( $new_var->{modifier} =~ /(const|volatile)/ ) )
  {
    $new_var->{scope} = 'LOCAL';
  }
  push @$varset, $new_var;

  my $var_node = {
    ntype => "var",
    var   => $new_var,
    out   => {
      type => $new_var->{type},
      val  => $new_var->{val},
    },
  };

  my $op_node = {
    ntype => 'op',
    otype => '+',
    in    => [ { ref => $n_ref }, { ref => $var_node } ],
    out   => {
      type => $var_node->{out}->{type},
      val  => undef,
    },
    ins_add => "k$num_new_var",
  };

  foreach my $l ( @{ $op_node->{in} } ) {
    $l->{val}         = $l->{ref}->{out}->{val};
    $l->{type}        = $l->{ref}->{out}->{type};
    $l->{print_value} = 0 unless ( defined $l->{print_value} );
  }
  my $type = $self->_get_type;
  my $max  = Math::BigInt->new( $type->{$n_type}->{max} );
  my $min  = Math::BigInt->new( $type->{$n_type}->{min} );
  if ( $c < $min || $max < $c ) { die "($n_type)$c < $min || $max < $c"; }

  if ( $FLOAT_MODE == 1 ) {
    $op_node->{out}->{val} =
      $op_node->{in}->[0]->{val} + $op_node->{in}->[1]->{val};
    if ( $si eq "unsigned" ) {
      $op_node->{out}->{val} = ( $op_node->{out}->{val} % ( $max + 1 ) );
    }
    else { ; }
  }
  elsif ( $n_type eq "float" ) {
    $op_node->{out}->{val} =
      &FADD( $op_node->{in}->[0]->{val}, $op_node->{in}->[1]->{val} );
  }
  elsif ( $n_type eq "double" ) {
    $op_node->{out}->{val} =
      &DADD( $op_node->{in}->[0]->{val}, $op_node->{in}->[1]->{val} );
  }
  elsif ( $n_type eq "long double" ) {
    $op_node->{out}->{val} =
      &LDADD( $op_node->{in}->[0]->{val}, $op_node->{in}->[1]->{val} );
  }
  else {
    $op_node->{out}->{val} =
      $op_node->{in}->[0]->{val} + $op_node->{in}->[1]->{val};
    if ( $si eq "unsigned" ) {
      $op_node->{out}->{val} = ( $op_node->{out}->{val} % ( $max + 1 ) );
    }
    else { ; }
  }
  $n->{type} = $op_node->{out}->{type};
  $n->{val}  = $op_node->{out}->{val};

  $n->{print_value} = 0 unless ( defined $n->{print_value} );
  $n->{ref} = $op_node;

}

# not using
sub new_ins_mul {
  my ( $self, $n, $rmin, $rmax, $varset ) = @_;
  my $config = $self->{config};
  my $n_ref  = $n->{ref};
  my $n_type = $n_ref->{out}->{type};
  my $c      = random_range( $rmax, $rmin, $n_type, $self->{config} );

  # 1 When you have come back, because there is no meaning of ins_mul interim
  if ( $c == 1 ) { $c = 0; }

  my $num_new_var    = scalar @$varset;
  my $rand_classes   = rand @{ $config->get('classes') };
  my $rand_modifiers = rand @{ $config->get('modifiers') };
  my $rand_scopes    = rand @{ $config->get('scopes') };

  my ( $si, $t ) = split( / /, $n_type, 2 );

  $c = Math::BigInt->new($c);

  my $new_var = {
    name_type => "k",
    name_num  => "$num_new_var",
    type      => $n_type,
    ival      => $c,
    val       => $c,
    class     => $config->get('classes')->[$rand_classes],
    modifier  => $config->get('modifiers')->[$rand_modifiers],
    scope     => $config->get('scopes')->[$rand_scopes],
    used      => 1,
  };
  push @$varset, $new_var;

  my $var_node = {
    ntype => "var",
    var   => $new_var,
    out   => {
      type => $new_var->{type},
      val  => $new_var->{val},
    },
  };

  my $op_node = {
    ntype => 'op',
    otype => '*',
    in    => [ { ref => $n_ref }, { ref => $var_node } ],
    out   => {
      type => $var_node->{out}->{type},
      val  => undef,
    },
    ins_add => "k$num_new_var",
  };

  foreach my $l ( @{ $op_node->{in} } ) {
    $l->{val}         = $l->{ref}->{out}->{val};
    $l->{type}        = $l->{ref}->{out}->{type};
    $l->{print_value} = 0 unless ( defined $l->{print_value} );
  }

  my $type = $self->_get_type;
  my $max  = Math::BigInt->new( $type->{$n_type}->{max} );
  my $min  = Math::BigInt->new( $type->{$n_type}->{min} );

  if ( $FLOAT_MODE == 1 ) {
    $op_node->{out}->{val} =
      $op_node->{in}->[0]->{val} * $op_node->{in}->[1]->{val};
    if ( $si eq "unsigned" ) {
      $op_node->{out}->{val} =
        ( $op_node->{out}->{val} % ( $type->{$n_type}->{max} + 1 ) );
    }
    else { ; }
  }
  elsif ( $n_type eq "float" ) {
    $op_node->{out}->{val} =
      &FMUL( $op_node->{in}->[0]->{val}, $op_node->{in}->[1]->{val} );
  }
  elsif ( $n_type eq "double" ) {
    $op_node->{out}->{val} =
      &DMUL( $op_node->{in}->[0]->{val}, $op_node->{in}->[1]->{val} );
  }
  elsif ( $n_type eq "long double" ) {
    $op_node->{out}->{val} =
      &LDMUL( $op_node->{in}->[0]->{val}, $op_node->{in}->[1]->{val} );
  }
  else {
    $op_node->{out}->{val} =
      $op_node->{in}->[0]->{val} * $op_node->{in}->[1]->{val};
    if ( $si eq "unsigned" ) {
      $op_node->{out}->{val} =
        ( $op_node->{out}->{val} % ( $type->{$n_type}->{max} + 1 ) );
    }
    else { ; }
  }

  $n->{type} = $op_node->{out}->{type};
  $n->{val}  = $op_node->{out}->{val};

  $n->{print_value} = 0 unless ( defined $n->{print_value} );
  $n->{ref} = $op_node;
}

# move Generator/Util
sub random_range {
  my ( $top, $bottom, $type, $config ) = @_;
  my $ans = Math::BigFloat->new(0);
  my ( $si, $ty ) = split( / /, $type, 2 );
  my $max        = Math::BigInt->new( $config->get('type')->{$type}->{max} );
  my $debug_mode = $config->get('debug_mode');

  if ( ref $top ne 'Math::BigInt' )    { $top    = Math::BigInt->new($top); }
  if ( ref $bottom ne 'Math::BigInt' ) { $bottom = Math::BigInt->new($top); }
  $ans = Math::BigInt->new(0);
  $ans = $top->as_int()->bsub($bottom);    # top - bottom + 1;
  my $rand = Math::BigFloat->new( rand() );
  $rand = $rand->copy()->bmul($ans)->ffround(0)->bstr()
    ;    # rand * $ans, Integer and rounds to a point below 0 direction
  $rand = Math::BigInt->new($rand);
  $ans  = $rand->as_int()->badd($bottom);    # rand + bottom
  unless ( $bottom <= $ans && $ans <= $top ) {
    die "$bottom < $ans < $top\n";
  }

  # print "$bottom < $ans < $top\n";
  if ( $ans eq 'NaN' || $ans eq 'nan' )

    # NaN is I've been avoiding because generated by that accidentally
    # get a few rare cases very small in rand
  {
    print "Nan is occured.\n" if ($debug_mode);
    $ans = $bottom;    # Interim
    if ( $bottom eq 'NaN'
      || $top eq 'NaN'
      || $bottom eq 'nan'
      || $top eq 'nan'
      || $bottom eq 'inf'
      || $top eq 'inf' )
    {
      $ans = 0;
    }
  }
  elsif ( $ans eq 'inf' ) {
    print "inf is occured.\n" if ($debug_mode);
    $ans = 0;
  }
  else { ; }

  if ( $si eq "unsigned" ) {
    $ans = ( $ans % ( $max + 1 ) );
  }

  return $ans;
}

sub change_relational_operators    # Node/revere_operator
{
  my ($n)     = @_;
  my $in1_ref = $n->{in}->[1]->{ref};
  my $otype   = $in1_ref->{otype};

  if    ( $otype eq '<' )  { $n->{in}->[1]->{ref}->{otype} = '>='; }
  elsif ( $otype eq '>' )  { $n->{in}->[1]->{ref}->{otype} = '<='; }
  elsif ( $otype eq '<=' ) { $n->{in}->[1]->{ref}->{otype} = '>'; }
  elsif ( $otype eq '>=' ) { $n->{in}->[1]->{ref}->{otype} = '<'; }
  elsif ( $otype eq '==' ) { $n->{in}->[1]->{ref}->{otype} = '!='; }
  elsif ( $otype eq '!=' ) { $n->{in}->[1]->{ref}->{otype} = '=='; }
  else                     { die; }

}

sub change_div_to_mod {
  my ($n)     = @_;
  my $in1_ref = $n->{in}->[1]->{ref};
  my $otype   = $in1_ref->{otype};

  if ( $otype eq '/' ) { $n->{in}->[1]->{ref}->{otype} = '%'; }
  else                 { die; }

}

# Four arithmetic operations for the undefined behavior avoidance,
# the shift operator to reverse (overflow measures)
sub change_arithmetic_operators {
  my ($n) = @_;
  my $otype = $n->{otype};

  if    ( $otype eq '+' )  { $n->{otype} = '-'; }
  elsif ( $otype eq '-' )  { $n->{otype} = '+'; }
  elsif ( $otype eq '*' )  { $n->{otype} = '/'; }
  elsif ( $otype eq '/' )  { $n->{otype} = '*'; }
  elsif ( $otype eq '<<' ) { $n->{otype} = '>>'; }
  elsif ( $otype eq '>>' ) { $n->{otype} = '<<'; }
  else                     { die; }

}

# Because of undefined behavior avoidance,
# to change the value of the analysis leaves
sub change_value {
  my ( $self, $n, $min, $max, $varset ) = @_;
  my $config         = $self->{config};
  my $n_ref          = $n->{ref};
  my $ref_type       = $n_ref->{out}->{type};
  my $val            = random_range( $max, $min, $ref_type, $self->{config} );
  my $num_new_var    = scalar @$varset;
  my $rand_classes   = rand @{ $config->get('classes') };
  my $rand_modifiers = rand @{ $config->get('modifiers') };
  my $rand_scopes    = rand @{ $config->get('scopes') };

  my $new_var = {
    name_type => "x",
    name_num  => $num_new_var,
    type      => $ref_type,
    ival      => $val,
    val       => $val,
    class     => $config->get('classes')->[$rand_classes],
    modifier  => $config->get('modifiers')->[$rand_modifiers],
    scope     => $config->get('scopes')->[$rand_scopes],
    used      => 1,
  };

  if ( defined( $self->{volatile_mode} )
    && $new_var->{scope} =~ /GLOBAL/
    && !( $new_var->{modifier} =~ /(const|volatile)/ ) )
  {
    $new_var->{scope} = 'LOCAL';
  }

  push @$varset, $new_var;

  $n->{ref}->{var}         = $new_var;
  $n->{ref}->{out}->{type} = $new_var->{type};
  $n->{ref}->{out}->{val}  = $new_var->{val};
}

1;
