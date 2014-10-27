package Minosse::Agent;
use Deeme::Obj -base;
use Carp;
use feature 'say';
use Data::Printer;

has id => sub {
    int( rand(1000000) );
};

my $cb;

sub unregister {
    my $agent = shift;
    my $env   = shift;
    $agent->end if $agent->can("end");
    $env->unsubscribe( tick => $cb );
    $env->{_agents}--;
}

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

sub choose {
    croak 'choose() not implemented by Agent base class';
}

sub end {
    shift->{_goal_reached}++;
}

sub learn {
    croak 'learn() not implemented by Agent base class';
}

1;
