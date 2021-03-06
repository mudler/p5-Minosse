package Minosse::Environment::NFQ;

=head1 NAME

Minosse::Environment::NFQ - NFQ Environment for L<Minosse>

=head1 DESCRIPTION

L<Minosse::Environment::NFQ> is a Neural fitted network agent implementation for the <Minosse> simulation framework.

=cut

use Deeme::Obj "Minosse::Environment";
use feature 'say';
use Data::Printer;
use Storable qw(dclone);
use Minosse::Util;

#Possible actions
use constant UP    => 0;
use constant DOWN  => 1;
use constant LEFT  => 2;
use constant RIGHT => 3;

has actions => sub { [ UP, DOWN, LEFT, RIGHT ] }; #defyining the agent's possible actions in the environment

=head2 rewards

Here you can supply the reward matrix (you can subclass and override using a function)

=cut

has rewards => sub { [] };

sub process {
    my $env    = shift;
    my $agent  = shift;
    my $action = shift;
    my $status = shift;

    #say "Action : $action , status: " . p($status);
    my $reward = -2;

    my $previous_status = dclone($status);

    #sleep 1;
    # Change status of the agent
    $status->[1] += 1 if ( $action eq UP );
    $status->[1] -= 1 if ( $action eq DOWN );
    $status->[0] -= 1 if ( $action eq LEFT );
    $status->[0] += 1 if ( $action eq RIGHT );
    if (    ( $status->[1] <= 5 and $status->[1] >= 0 )
        and ( $status->[0] <= 5 and $status->[0] >= 0 ) )
    {
        $reward = $env->rewards->[ $status->[1] ]->[ $status->[0] ];
    }
    else {
        $status->[0] = $previous_status->[0];
        $status->[1] = $previous_status->[1];
    }

    # p( $env->rewards );
    environment "BAD BOYYYYY, you shouldn't see me"
        if !exists $env->rewards->[ $status->[1] ]->[ $status->[0] ];

    return [ $status, $reward ];
}
1;
