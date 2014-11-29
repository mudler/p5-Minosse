use strict;
use Test::More 0.98;
use_ok("Minosse::Environment::Packages");
my $env = Minosse::Environment::Packages->new;

$env->init();
( my $module, my $version ) = $env->parse_version("Net::Twitter");
$env->install_module( $module, 0, $version );

print "===================\n\n\n\n";
(  $module,  $version )  = $env->parse_version("Data::Dumper");
$env->grab_deps( $module, $version );

done_testing;

