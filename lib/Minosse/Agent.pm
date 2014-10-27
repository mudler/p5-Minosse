package Minosse::Agent;

=head1 NAME

Minosse::Agent - Agent base class for L<Minosse>

=head1 DESCRIPTION

L<Minosse::Agent> is a base class for implementing agents in L<Minosse> simulation framework.

=cut


use Deeme::Obj -base;
use Carp;
use feature 'say';
use Data::Printer;

=head1 ATTRIBUTES

=head2 id

Agent random id (just for display purposes, not used internally)

=cut

has id => sub {
    int( rand(1000000) );
};

my $cb;

=head1 METHODS

=head2 unregister

unregister the agent from the L<Minosse::Environment> loop

=cut

sub unregister {
    my $agent = shift;
    my $env   = shift;
    $agent->end if $agent->can("end");
    $env->unsubscribe( tick => $cb );
    $env->{_agents}--;
}

=head2 register

register the agent to the L<Minosse::Environment> loop

=cut

sub register {
    my $agent = shift;
    my $env   = shift;
    $agent->startup if $agent->can("startup");
    $env->on(
        update_beliefs => sub {
            $agent->learn(@_);
        }
    );
    $env->on( simulation_end => sub { $agent->end } );
    $cb = sub {
        $env->emit(
            choise_result => (
                $agent,
                $agent->choose( $env->{status}->{$agent} ),
                $env->{status}->{$agent}
            )
        );
    };
    $env->on( tick => $cb );
    $env->{_agents}++;
}



=head2 end

Increments the internal counter of goal reached

=cut

sub end {
    shift->{_goal_reached}++;
}

=head2 learn

unimplemented

=cut

sub learn {
    croak 'learn() not implemented by Agent base class';
}

=head2 choose

unimplemented

=cut

sub choose {
    croak 'choose() not implemented by Agent base class';
}

=head1 LICENSE

Copyright (C) mudler.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

mudler E<lt>mudler@dark-lab.netE<gt>

=cut



1;
