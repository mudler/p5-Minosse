package Minosse::Environment;
use Deeme -base;
use Carp;
use feature 'say';
use Storable 'dclone';
use Minosse::Util;

my $singleton;
sub new { $singleton ||= shift->SUPER::new(@_); }

sub subscribe {
    $_[1]->register( $_[0] );
    $_[1]->prepare( $_[0] ) if $_[1]->can("prepare");
    $_[0]->{status}->{ $_[1] } = [ 0, 0 ];
    $_[1]->{_env} = __PACKAGE__;
    return $_[0];
}

sub run {
    $_[0]->on(
        choise_result => sub {
            my $env            = shift;
            my $current_status = dclone( $env->{status}->{ $_[0] } );
            environment "current status @{$current_status}\n" if DEBUG;
            my @r = @{ $env->process(@_) };
            $env->{status}->{ $_[0] } = $r[0];
            $env->emit( update_beliefs => ( $current_status, $_[1], @r ) );
        }
    );
    while (1) { $_[0]->emit("tick") }
}

sub process {
    croak 'process() not implemented by base class';
}

1;
