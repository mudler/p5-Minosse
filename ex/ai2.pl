#!/usr/bin/perl

use lib 'lib';
use Minosse::Agent::NFQ;
use Minosse::Environment::Packages;

my $env
    = Minosse::Environment::Packages->new->max_epoch(10000)
    ->universe("ex/universe.json")->specfile("ex/specfile.json")
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
        brain              => "nets/packages.ann",
        inputs             => "3",
        hidden_layers      => 4,
        outputs            => 1,
        auto_learn         => 1,
        choose_best_factor => 0,
        discount_factor    => 1,
        learning_rate      => 0.5
    )
    )->endless(1)->step( sub { sleep 1; } )->go;
