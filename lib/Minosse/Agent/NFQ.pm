package Minosse::Agent::NFQ;
use Deeme::Obj "Minosse::Agent";
use base "Algorithm::QLearning::NFQ";
use feature 'say';
use Minosse "Minosse::Environment::NFQ";
use Minosse::Util;

=head1 NAME

Minosse::Agent::NFQ - NFQ agent for L<Minosse>

=head1 DESCRIPTION

L<Minosse::Agent::NFQ> is a Neural fitted network agent implementation for the <Minosse> simulation framework.

=cut

use Data::Printer;
on tick => sub { message 0, "Start turn"; };

sub startup {
    my $self = shift;
    my $env  = shift;
    on( tick => sub {
            message $self->id, "start turn";
        }
    );
}

sub prepare {
    my $self = shift;
    my $env  = shift;
    on( tick => sub {
            message $self->id, "end turn";
        }
    );
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
    my $current_action = shift;
    my $r              = pop @_;
    my $qv             = $agent->batch( $current_status, $current_action,
        $env->{status}->{$agent}, $r );
    message $agent->id,
          "position ["
        . $current_status->[0] . ", "
        . $current_status->[1]
        . "] to [ "
        . $env->{status}->{$agent}->[0] . ", "
        . $env->{status}->{$agent}->[1]
        . "] with Qval = $qv";

    $agent->nn->print_connections if DEBUG;
}

sub end {
    message $_[0]->id, "End reached, saving neural";
    $_[0]->goal_reached;
    shift->batch_save();
}
1;
