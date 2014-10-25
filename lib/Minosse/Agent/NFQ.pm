package Minosse::Agent::NFQ;
use Deeme::Obj "Minosse::Agent";
use base "Algorithm::QLearning::NFQ";
use feature 'say';
use Minosse "Minosse::Environment::NFQ";
use Minosse::Util;

use Data::Printer;

on tick => sub { sleep 1; message 0,"Start turn"; };

sub prepare {
    my $self = shift;
    my $env  = shift;
    on( tick => sub {  message $self->id,"end turn"; } );
}

sub choose {
    my $agent  = shift;
    my $status = shift;

    #my $action = $agent->actions->[ int( rand(4) ) ];
    my $action = $agent->egreedy($status);
    message $agent->id,
          "was in ["
        . $status->[0] . ", "
        . $status->[1]
        . "] and picked $action\n"
        if DEBUG;
    return $action;
}

sub learn {
    message $_[0]->id, "I had to learn \n\t\t@_" if DEBUG;
    my $agent          = shift;
    my $env            = shift;
    my $current_status = shift;

    #  p($current_status);
    my $current_action = shift;
    my $r              = pop @_;
    $agent->train( $current_status, $current_action,
        $env->{status}->{$agent}, $r );
    message $agent->id,
          "position ["
        . $current_status->[0] . ", "
        . $current_status->[1] . "]";

    #die("GOOD") if $current_status->[1] == 3 and $current_status->[0] ==3;

    #    $agent->nn->print_connections;
}
1;
