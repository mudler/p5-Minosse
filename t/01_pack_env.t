use strict;
use Data::Dumper;

use Test::More 0.98;
use_ok("Minosse::Environment::Packages");
use Data::Dumper;
my $env = Minosse::Environment::Packages->new;

$env->init();

my $model = $env->solve("Data::Dumper");
is( ref $model, "HASH",
    "Data::Dumper solving returns a model: " . Dumper($model) );

my $model = $env->solve("Mojolicious");
is( ref $model, "HASH",
    "Mojolicious solving returns a model: " . Dumper($model) );


my $model = $env->solve("Try::Tiny");
is( ref $model, "HASH",
    "Try::Tiny solving returns a model: " . Dumper($model) );

done_testing;

