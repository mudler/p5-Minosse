package Minosse::Agent::NFQ;
use Deeme::Obj "Minosse::Agent";
use base "Algorithm::QLearning::NFQ";
use feature 'say';
use Minosse;
use Data::Printer;
has 'epsilon' => "0.1";

sub greedy {
    my $self   = shift;
    my $status = shift;
    if ( rand(1) < $self->epsilon ) {
        return $self->actions->[ int( rand( scalar( @{ $self->actions } ) ) )
        ];
    }
    else {
 #orders by value the hash given by the actions reward for the current status.
        my %action_rewards
            = map { $_ => $self->nn->run( [ @{$status}, $_ ] )->[0] }
            @{ $self->actions };
        if (DEBUG) {
            foreach my $k ( keys %action_rewards ) {
                warn "$k: " . $action_rewards{$k} . "\n";
            }
        }
        return ~~ (
            sort { $action_rewards{$a} <=> $action_rewards{$b} }
                keys %action_rewards
        )[-1];
    }
}

sub choose {
    my $agent  = shift;
    my $status = shift;

    #my $action = $agent->actions->[ int( rand(4) ) ];
    my $action = $agent->greedy($status);
    warn "-> Agent: was in ["
        . $status->[0] . ", "
        . $status->[1]
        . "] and picked $action\n"
        if DEBUG;
    return $action;
}

sub learn {
    warn "-> Agent: I had to learn \n\t\t@_" if DEBUG;
    my $agent          = shift;
    my $env            = shift;
    my $current_status = shift;

    #  p($current_status);
    my $current_action = shift;
    my $r              = pop @_;
    $agent->train( $current_status, $current_action,
        $env->{status}->{$agent}, $r );
    warn "-> Agent: position ["
        . $current_status->[0] . ", "
        . $current_status->[1] . "]\n"
        if DEBUG;

    #die("GOOD") if $current_status->[1] == 3 and $current_status->[0] ==3;

    #    $agent->nn->print_connections;
}
1;
