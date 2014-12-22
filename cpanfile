requires 'perl', '5.008001';
requires 'base';
requires 'Carp';
requires 'CPAN::Meta';
requires 'Data::Dumper';
requires 'Encode';
requires 'FindBin';
requires 'File::Basename';
requires 'File::Copy';
requires 'File::Spec';
requires 'File::Path';
requires 'File::Temp';
requires 'Getopt::Long';
requires 'List::MoreUtils';
requires 'Math::BigFloat';
requires 'Math::BigInt::FastCalc', '0.27';
requires 'Math::BigInt::GMP', '1.37';
requires 'Math::BigInt::Pari', '1.16';
requires 'Math::BigInt';
requires 'POSIX';
requires 'Time::HiRes';
requires 'Test::More';

on 'test' => sub {
    requires 'List::MoreUtils', '0.33';
    requires 'Test::More', '0.98';
};

on 'configure' => sub {
  requires 'Module::Install';
  requires 'Module::Install::CPANfile';
};
