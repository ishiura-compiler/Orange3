package Orange3::Generator::Expect;

use strict;
use warnings;

use Orange3::Generator::Arithmetic;

sub value_compute {
  my ( $n, $varset, $config, $avoide_undef ) = @_;

  if ( $n->{ntype} eq 'var' ) {
    $n->{out}->{val} = $n->{var}->{val};
  }
  elsif ( $n->{ntype} eq 'op' ) {
    for my $i ( @{ $n->{in} } ) {
      if ( $i->{print_value} == 0 ) {
        value_compute( $i->{ref}, $varset, $config, $avoide_undef );
      }
      if ( $i->{print_value} <= 1 ) {
        $i->{val} = $i->{ref}->{out}->{val};
      }
      if ( $i->{val} eq "UNDEF" ) {
        $n->{out}->{val} = "UNDEF";
        return;
      }
    }

    my $arithmetic = Orange3::Generator::Arithmetic->new(
      config       => $config,
      avoide_undef => $avoide_undef,
    );

    for my $l ( @{ $n->{in} } ) {
      if ( $l->{print_value} <= 1 ) {
        $l->{val} = $arithmetic->value_conversion(
          $l->{ref}->{out}->{val},
          $l->{ref}->{out}->{type},
          $l->{type}
        );
      }
    }

    $n->{out}->{val} = $arithmetic->arithmetic_expectation_value( $n, $varset );
  }
}

1;
