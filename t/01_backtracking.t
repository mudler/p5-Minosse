use strict;
use Test::More 0.98;
use Data::Dumper;

use_ok("Minosse::Agent::Probabilistic");

my $clauses = [
    [ 'blue',  'green',  '-yellow' ],
    [ '-blue', '-green', 'yellow' ],
    [ 'pink', 'purple', 'green', 'blue', '-yellow' ]
];

my $variables = [ 'blue', 'green', 'yellow', 'pink', 'purple' ];
my $agent     = Minosse::Agent::Probabilistic->new;
my $model     = $agent->solve( $variables, $clauses );
is( ref $model, "HASH", "Backtrack returned a model" );
is_deeply(
    $model,
    { purple => 1, pink => 1, yellow => 1, green => 1 },
    "Testing solver"
);
print STDERR Dumper($model) . "\n";
done_testing;

