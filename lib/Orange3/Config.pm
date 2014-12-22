package Orange3::Config;

use strict;
use warnings;

use Math::BigInt;

sub new {
  my ( $class, $file ) = @_;
  my $conf = do $file or die "Can't load $file: $!";

  bless $conf, $class;
}

sub get {
  my ( $self, $param ) = @_;

  unless ( exists $self->{$param} ) {
    return undef;
  }

  return $self->{$param};
}

sub _print_check_config {
  my $caution = shift;

  if ( $caution eq "" ) { ; }
  else {
    print <<END_OF_DATA;
[[[[[[[[[[[[[[[[[[[[[     CAUTION     ]]]]]]]]]]]]]]]]]]]]]
In the configuration file, you may have the wrong settings.
If the Orange3 does not work correctly, please review the
following settings.
END_OF_DATA
    print $caution;
  }
}

sub _check_config {
  my $self = shift;

  my $caution = "";
  $caution .= $self->_check_config_e_size_num;
  $caution .= $self->_check_config_options;
  $caution .= $self->_check_config_source_file;
  $caution .= $self->_check_config_exec_file;
  $caution .= $self->_check_config_macro_ok;
  $caution .= $self->_check_config_macro_ng;
  $caution .= $self->_check_config_compiler;
  $caution .= $self->_check_config_operators;
  $caution .= $self->_check_config_classes;
  $caution .= $self->_check_config_modifiers;
  $caution .= $self->_check_config_types;
  $caution .= $self->_check_config_scopes;
  $caution .= $self->_check_config_type;

  _print_check_config($caution);
}

sub _check_config_type {
  my $self = shift;
  if ( !defined $self->{type} || ref($self->{type}) ne "HASH") {
    return _c_msg("Undefined types.");
  }
  my $caution = "";
  foreach my $type ( keys %{$self->{type}} ) {
    if ( $type eq "" ) {
      return _c_msg("Undefined types.");
    }
    elsif ( $type =~
/^((signed|unsigned) (char|short|int|long|long long)|(float|double|long double))$/
      )
    {
      my $type_ = $self->{type}->{$type};
      if ( !defined $type_->{order}
        || $type_->{order} !~ /^[0-9]+$/ )
      {
        $caution .= _c_msg("Order of type '$type' is wrong.");
      }
      elsif ( !defined $type_->{printf_format} ) {
        $caution .= _c_msg("Printf_format of type '$type' is wrong.");
      }
      elsif ( !defined $type_->{const_suffix} ) {
        $caution .= _c_msg("Const_suffix of type '$type' is wrong.");
      }
      elsif ( !defined $type_->{bits}
        || $type_->{bits} !~ /^[0-9]+$/ )
      {
        $caution .= _c_msg("Bit of type '$type' is wrong.");
      }
      elsif ( $type =~ /^(unsigned|signed)/
        && ( $type_->{bits} % 4 ) != 0 )
      {
        $caution .= _c_msg("Bit of type '$type' is not divisible by 4.");
      }
      elsif ( !defined $type_->{min}
        || $type_->{min} !~ /^[+-]?[0-9]+$/ )
      {
        $caution .= _c_msg("Min of type '$type' is wrong.");
      }
      elsif ( !defined $type_->{max}
        || $type_->{max} !~ /^[+-]?[0-9]+$/ )
      {
        $caution .= _c_msg("Max of type '$type' is wrong.");
      }
      elsif ( $type =~ /^(signed)/ ) {
        my $two_bit = Math::BigInt->new(2) << ( $type_->{bits} - 2 );
        if ( $type_->{min} != -$two_bit ) {
          $caution .= _c_msg("Bit OR min of type '$type' may be wrong");
        }
        if ( $type_->{max} != ( $two_bit - 1 ) ) {
          $caution .= _c_msg("Bit OR max of type '$type' may be wrong");
        }
      }
      elsif ( $type =~ /^(unsigned)/ ) {
        my $two_bit = Math::BigInt->new(2) << ( $type_->{bits} - 1 );
        if ( $type_->{min} != 0 ) {
          $caution .= _c_msg("Bit OR min of type '$type' may be wrong");
        }
        if ( $type_->{max} != ( $two_bit - 1 ) ) {
          $caution .= _c_msg("Bit OR max of type '$type' may be wrong");
        }
      }
    }
    else {
      return _c_msg("Type contains the unsupported type '$type'.");
    }
  }
  return $caution;
}

sub _check_config_scopes {
  my $self = shift;
  if ( !defined $self->{scopes}->[0] ) {
    return _c_msg("Undefined types.");
  }
  foreach my $scope ( @{ $self->{scopes} } ) {
    if ( $scope eq "" ) {
      return _c_msg("Undefined types.");
    }
    elsif ( $scope =~ /^(LOCAL|GLOBAL)$/ ) {
      ;
    }
    else {
      return _c_msg("Scopes contain the unsupported type '$scope'.");
    }
  }
  return "";
}

sub _check_config_types {
  my $self = shift;
  if ( !defined $self->{types}->[0] ) {
    return _c_msg("Undefined types.");
  }
  foreach my $type ( @{ $self->{types} } ) {
    if ( $type eq "" ) {
      return _c_msg("Undefined types.");
    }
    elsif ( $type =~
/^((signed|unsigned) (char|short|int|long|long long)|(float|double|long double))$/
      )
    {
      ;
    }
    else {
      return _c_msg("Types contain the unsupported type '$type'.");
    }
  }
  return "";
}

sub _check_config_modifiers {
  my $self = shift;
  if ( !defined $self->{modifiers}->[0] ) {
    return _c_msg("Undefined modifiers.");
  }
  foreach my $modifier ( @{ $self->{modifiers} } ) {
    if ( $modifier eq ""
      || $modifier =~ /(const|volatile)/ )
    {
      ;
    }
    else {
      return _c_msg("Classes contain the unsupported class '$modifier'.");
    }
  }
  return "";
}

sub _check_config_classes {
  my $self = shift;
  if ( !defined $self->{classes}->[0] ) {
    return _c_msg("Undefined classes.");
  }
  foreach my $class ( @{ $self->{classes} } ) {
    if ( $class eq ""
      || $class =~ /^(static)$/ )
    {
      ;
    }
    else {
      return _c_msg("Classes contain the unsupported class '$class'.");
    }
  }
  return "";
}

sub _check_config_operators {
  my $self = shift;
  if ( !defined $self->{operators}->[0] ) {
    return _c_msg("Undefined operators.");
  }
  foreach my $operator ( @{ $self->{operators} } ) {
    if ( $operator eq "" ) {
      return _c_msg("Undefined operators.");
    }
    elsif ( $operator =~
      /^(\+|-|\*|\/|\%|<<|>>|==|!=|<|>|<=|>=|\&\&|\|\||\||\&|\^)$/ )
    {
      ;
    }
    else {
      return _c_msg("Operators contain the unsupported operator '$operator'.");
    }
  }
  return "";
}

sub _check_config_compiler {
  my $self = shift;
  if ( !defined $self->{compiler}
    || $self->{compiler} eq "" )
  {
    return _c_msg("Undefined source_file.");
  }
  elsif ( system "which $self->{compiler} > /dev/null" ) {
    return _c_msg("Compiler Command '$self->{compiler}' is not found.");
  }
  else {
    return "";
  }
}

sub _check_config_macro_ng {
  my $self = shift;
  if ( !defined $self->{macro_ng}
    || $self->{macro_ng} eq "" )
  {
    return _c_msg("Undefined source_file.");
  }
  elsif ( $self->{macro_ng} !~ /NG|abort/ ) {
    return _c_msg(
      "macro_ng does not contain 'NG' word. Please rewrite the executor.cnf" );
  }
  else {
    return "";
  }
}

sub _check_config_macro_ok {
  my $self = shift;
  if ( !defined $self->{macro_ok}
    || $self->{macro_ok} eq "" )
  {
    return _c_msg("Undefined source_file.");
  }
  elsif ( $self->{macro_ok} !~ /OK/ ) {
    return _c_msg(
      "macro_ok does not contain 'OK' word. Please rewrite the executor.cnf" );
  }
  else {
    return "";
  }
}

sub _check_config_exec_file {
  my $self = shift;
  if ( !defined $self->{exec_file}
    || $self->{exec_file} eq "" )
  {
    return _c_msg("Undefined source_file.");
  }
  elsif ( $self->{exec_file} =~ /\s|\$|\%|\'|\@|\!|\`|\(|\)|\~/ ) {
    return _c_msg("Source_file contain the special character.");
  }
  else {
    return "";
  }
}

sub _check_config_source_file {
  my $self = shift;
  if ( !defined $self->{source_file}
    || $self->{source_file} eq "" )
  {
    return _c_msg("Undefined source_file.");
  }
  elsif ( $self->{source_file} =~ /\s|\$|\%|\'|\@|\!|\`|\(|\)|\~/ ) {
    return _c_msg("Source_file contain the special character.");
  }
  else {
    return "";
  }
}

sub _check_config_options {
  my $self = shift;
  if ( !defined $self->{options}->[0] ) {
    $self->{options}->[0] = "";
    return _c_msg(
      "Undefined options. No-string element is added to the array of options.");
  }
  foreach my $option ( @{ $self->{options} } ) {
    if ( $option eq "" ) {
      ;
    }
    elsif ( $option =~ /\s|\$|\%|\'|\@|\!|\`|\(|\)|\~/ ) {
      return _c_msg("Options contain the special character.");
    }
  }
  return "";
}

sub _c_msg {
  my $massage = shift;
  return "! $massage\n";
}

sub _check_config_e_size_num {
  my $self = shift;

  if ( !defined $self->{e_size_num} ) {
    return _c_msg("Undefined e_size_num.");
  }
  elsif ( $self->{e_size_num} > 10000 ) {
    return _c_msg("! e_size_num is too big.");
  }
  elsif ( $self->{e_size_num} < 1
    || $self->{e_size_num} !~ /^[0-9]+$/ )
  {
    return _c_msg("! e_size_num is wrong.");
  }
  elsif ( $self->{e_size_num} > 0
    && $self->{e_size_num} < 10000 )
  {
    return "";
  }
  else {
    Carp::croak("! e_size_num is wrong.");
  }
}

1;
