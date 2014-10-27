package Minosse::Environment;
use Deeme -base;
use Carp;
use feature 'say';
use Storable 'dclone';
use Minosse::Util;
use Data::Printer;
has max_epoch => sub {0};
has goals     => sub { [] };
has rewards   => sub { [] };
has endless   => sub {0};
my $singleton;
sub new { $singleton ||= shift->SUPER::new(@_); }

sub subscribe {
    $_[1]->register( $_[0] );
    $_[1]->prepare( $_[0] ) if $_[1]->can("prepare");
    $_[0]->{status}->{ $_[1] } = [ 0, 0 ];
    return $_[0];
}

sub remove {
    $_[1]->unregister( $_[0] );
    $_[0]->{_agents_reached_goal}
        += $_[1]->{_goal_reached};    #sums the agent's goals reached number
    environment "$_[0] removed";
    return $_[0];
}

sub run {
    $_[0]->prepare() if $_[0]->can("prepare");
    $_[0]->{_agents_reached_goal}
        = 0;    #tracking the agents who reached the goal state
    my $tick = 0;
    $_[0]->on(
        tick => sub {
            environment "[Maximum epoch "
                . $_[0]->max_epoch
                . "] [Current Ticks: "
                . ++$tick . "]";

            warn(
                environment "A total of "
                    . $_[0]->{_agents_reached_goal}
                    . " agents reached the specified goal",
                environment("Simulation off, max_epoch reached")
                )
                and $_[0]->emit("simulation_end")
                and exit 1
                if $_[0]->max_epoch
                and $tick >= $_[0]->max_epoch;
        }
    );
    $_[0]->on(
        goal_check => sub {

            #    die("@_");
            my $env    = shift;
            my $agent  = shift;
            my $status = shift;
            (           $_->[0] eq $status->[0]
                    and $_->[1] eq $status->[1]
                    and $env->endless == 0 )
                ? $env->remove($agent)
                : 1
                for ( @{ $env->goals } );

            environment "A total of "
                . $env->{_agents_reached_goal}
                . " agents reached the specified goal"
                and environment "Simulation termined, goal reached"
                and exit 1
                if (exists $env->{_agents}
                and $env->{_agents} == 0
                and $env->endless == 0 );
        }
    );
    $_[0]->on(
        choise_result => sub {
            my $env            = shift;
            my $current_status = dclone( $env->{status}->{ $_[0] } );
            environment "current status @{$current_status}\n" if DEBUG;
            my $r = $env->process(@_);
            environment "REWARD is " . $r->[1];
            $env->{status}->{ $_[0] } = $r->[0];
            $env->emit( update_beliefs => ( $current_status, $_[1], @{$r} ) );
            $env->emit( goal_check => ( $_[0], $r->[0] ) );
        }
    );
    while (1) { $_[0]->emit("tick") }
}

sub process {
    croak 'process() not implemented by base class';
}

1;
