package Minosse::Agent::Probabilistic;
use Deeme::Obj "Minosse::Agent";
use feature 'say';
use Storable qw(dclone);
use Minosse::Util;

=head1 NAME

Minosse::Agent::NFQ - NFQ agent for L<Minosse>

=head1 DESCRIPTION

L<Minosse::Agent::NFQ> is a Neural fitted network agent implementation for the <Minosse> simulation framework.

=cut

use Data::Printer;

#on tick => sub { message 0, "Start turn"; };

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
    my $env    = shift;
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

# This is an extremely simple implementation of the 'backtracking' algorithm for
# solving boolean satisfiability problems. It contains no optimizations.

# The input consists of a boolean expression in Conjunctive Normal Form.
# This means it looks something like this:
#
# `(blue OR green) AND (green OR NOT yellow)`
#
# We encode this as an array of strings with a `-` in front for negation:
#
# `[['blue', 'green'], ['green', '-yellow']]`
sub solve {

    # ### solve
    #
    # * `variables` is the list of all variables
    # * `clauses` is an array of clauses.
    # * `model` is a set of variable assignments.
    my $self      = shift;
    my $variables = shift;
    my $clauses   = shift;
    my $model     = shift // {};

    # If every clause is satisfiable, return the model which worked.
    return $model
        if ( grep { !$self->satisfiable( $_, $model ) } @{$clauses} == 0 );

    # If any clause is **exactly** false, return `false`; this model will not
    # work.
    return 0
        if ( grep { !$self->satisfiable( $_, $model ) } @{$clauses} > 0 );

    # Choose a new value to test by simply looping over the possible variables
    # and checking to see if the variable has been given a value yet.

    my $choice;
    foreach my $variable ( @{$variables} ) {
        $choice = $variable and last if ( !exists $model->{$variable} );
    }

    # If there are no more variables to try, return false.

    return 0 if ( !defined $choice );

    # Recurse into two cases. The variable we chose will need to be either
    # true or false for the expression to be satisfied.
    return $self->solve( $variables, $clauses,
        $self->update( $model, $choice, 1 ) )    #true
        || $self->solve( $variables, $clauses,
        $self->update( $model, $choice, 0 ) );    #false
}

# ### update
# Copies the model, then sets `choice` = `value` in the model, and returns it.
sub update {
    shift;
    my $copy = dclone(shift);
    $copy->{shift} = shift;
    return $copy;
}

# ### resolve
# Resolve some variable to its actual value, or undefined.
sub resolve {
    my $self  = shift;
    my $var   = shift;
    my $model = shift;
    if ( substr $var, 0, 1 eq "-" ) {
        my $value = $model->{ substr $var, 1 };
        return !defined $value ? undef : !$value;
    }
    else {
        return $model->{$var};
    }
}

# ### satisfiable
# Determines whether a clause is satisfiable given a certain model.
sub satisfiable {
    my $self    = shift;
    my $clauses = shift;
    my $model   = shift;

    # If every variable is false, then the clause is false.
    return 0
        if ( grep { $self->resolve( $_, $model ) } @{$clauses} == 0 );

    # If any variable is true, then the clause is true.

    return 1
        if ( grep { !$self->resolve( $_, $model ) } @{$clauses} == 0 );

    # Otherwise, we don't know what the clause is.
    return undef;
}

1;

__END__

