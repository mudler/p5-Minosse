package Minosse::Environment;

=head1 NAME

Minosse::Environment - Environment base class for L<Minosse>

=head1 DESCRIPTION

L<Minosse::Environment> is a base class for implementing environments in L<Minosse> simulation framework.
The Environment holds the simulation, and here you can set special attributes to change various aspects of the simulation

=cut

#use Deeme -base;
use Deeme::Obj "Minosse::IOLoop";
use Carp;
use feature 'say';
use Storable 'dclone';
use Minosse::Util;
use Minosse::Util qw(compare);

use Data::Printer;

=head1 ATTRIBUTES

=head2 max_epoch

Your maximum epochs (ticks) that the simulation must run before exit (0 is infinite never ending simulation)

=cut

has max_epoch => sub {0};

=head2 goals

Here you can supply a list of goals (statuses) that must be recorded (and if you explictly set C<endless(0)> when all the agents reaches the goal it will quit the simulation)

=cut

has goals => sub { [] };

=head2 endless

If set to one, the simulation will run forever or until C<max_epoch>.

=cut

has endless => sub {0};

has actions => sub { [] };

my $singleton;
sub new { $singleton ||= shift->SUPER::new(@_); }

=head1 METHODS

=head2 subscribe

subscribe the agent to the environment

=cut

sub subscribe {
    $_[1]->register( $_[0] );
    $_[1]->actions($_[0]->actions);
    $_[1]->prepare( $_[0] ) if $_[1]->can("prepare");
    $_[0]->{status}->{ $_[1] } = [ 0, 0 ];
    return $_[0];
}

=head2 remove

remove the agent to the environment

=cut

sub remove {
    $_[1]->end if $_[1]->can("end");
    $_[1]->unregister( $_[0] );
    $_[0]->_goal_update( $_[1] );
    environment "$_[0] removed";
    return $_[0];
}

sub _goal_update {
    shift->{_agents_reached_goal}
        += shift->{_goal_reached};    #sums the agent's goals reached number
}

=head2 go

starts the simulation

=cut

sub go {
    $_[0]->{_agents_reached_goal}
        = 0;    #tracking the agents who reached the goal state
    $_[0]->_load_plugins;
    $_[0]->_environment_hooks;
    $_[0]->prepare() if $_[0]->can("prepare");
    $_[0]->recurring( 0 => sub { shift->emit("tick") } )
        ;       #adding our "tick" to the Event loop
    environment "starting simulation, hold on.";
    $_[0]->start;

    #    while (1) { $_[0]->emit("tick") }
}

sub process {
    croak 'process() not implemented by base class';
}

=head2 _environment_hooks
t
run the internal environment hooks

=cut

sub _environment_hooks {
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
            ( $env->endless == 0 )
                ? $env->remove($agent)
                : $agent->goal_reached and $env->_goal_update($agent)
                for ( grep { compare( $_, $status ) } @{ $env->goals } );

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
            environment "Reward for the agent is " . $r->[1];
            $env->{status}->{ $_[0] } = $r->[0];
            $env->emit( update_beliefs => ( $current_status, $_[1], @{$r} ) );
            $env->emit( goal_check => ( $_[0], $r->[0] ) );
        }
    );
}

sub _load_plugins {
    my $self   = shift;
    my $Loader = Minosse::Loader->new;
    for ( $Loader->search("Minosse::Plugin") ) {
        next if $Loader->load($_);
        $_->new->register($self) if $_->can("register");
    }
}

=head2 step
t
Add the callback to the main event

    Minosse::Environment->new->step( sub { sleep 1; })->go; # Now the simulation sleeps between each "tick"

=cut

sub step {
    $_[0]->on( tick => $_[1] );
    shift;
}

=head1 LICENSE

Copyright (C) mudler.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

mudler E<lt>mudler@dark-lab.netE<gt>

=cut

1;
