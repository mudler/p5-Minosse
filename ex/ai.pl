#!/usr/bin/perl

use lib 'lib';
use Minosse::Agent::NFQ;
use Minosse::Environment::NFQ;

use constant UP    => 0;
use constant DOWN  => 1;
use constant LEFT  => 2;
use constant RIGHT => 3;
my $env
    = Minosse::Environment::NFQ->new->max_epoch(100000)
    ->goals( [ [ 3, 3 ] ] )->rewards(
    [   [ -1, 1,  1,  1,   -1, -1 ],
        [ -1, -1, 1,  1,   -1, -1 ],
        [ -1, -1, -1, 1,   -1, -1 ],
        [ -1, -1, -1, 100, -1, -1 ],
        [ -1, -1, -1, -1,  -1, -1 ],
        [ -1, -1, -1, -1,  -1, -1 ],
    ]
    )->subscribe(
    Minosse::Agent::NFQ->new(
        brain              => "nets/sigmoid.ann",
        inputs             => "3",
        hidden_layers      => 4,
        outputs            => 1,
        auto_learn         => 1,
        actions            => [ UP, DOWN, LEFT, RIGHT ],
        choose_best_factor => 0.5,
        discount_factor    => 1,
        learning_rate      => 0.5
    )
    )->endless(1)->go;
