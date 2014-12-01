use strict;
use Data::Dumper;

use Test::More 0.98;
use_ok("Minosse::Environment::Packages");
use_ok("Minosse::Agent::Probabilistic");

my $env = Minosse::Environment::Packages->new;

$env->init();
( my $module, my $version ) = $env->parse_version("Data::Dumper");
ok($env->install_module( $module, 0, $version ),"Module install");

print "===================\n\n\n\n";
(  $module,  $version )  = $env->parse_version("Data::Dumper");
my @deps=$env->grab_deps( $module, $version );
print STDERR Dumper(@deps);
is(scalar @deps,2,"Data::Dumper has 2 direct deps");

done_testing;

