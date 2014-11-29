use strict;
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
use Data::Dumper;
print STDERR Dumper(@deps);
is(scalar @deps,2,"Data::Dumper has 2 direct deps");

print "===================\n\n\n\n";

my $clauses = [
  ['blue', 'green', '-yellow'],
  ['-blue', '-green', 'yellow'],
  ['pink', 'purple', 'green', 'blue', '-yellow']
];

 my $variables = ['blue', 'green', 'yellow', 'pink', 'purple'];
my $agent= Minosse::Agent::Probabilistic->new;
my $model = $agent->solve($variables, $clauses);
print STDERR Dumper($model)."\n";
done_testing;

