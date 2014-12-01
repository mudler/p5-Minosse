package Minosse::Agent::Probabilistic;
use Deeme::Obj "Minosse::Agent";
use feature 'say';
use Storable qw(dclone);
use Minosse::Util;
use Data::Dumper;

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
    message $self->id,
          Dumper($variables) . " - "
        . Dumper($clauses) . " - "
        . Dumper($model);

    # If every clause is satisfiable, return the model which worked.

    return $model
        if (
        (   grep {
                ( defined $self->satisfiable( $_, $model )
                        and $self->satisfiable( $_, $model ) == 1 )
                    ? ( say Dumper($_) . " is satisfied" and 0 )
                    : 1
            } @{$clauses}
        ) == 0
        );

    # If any clause is **exactly** false, return `false`; this model will not
    # work.

    message $self->id, "damn" and return 0
        if (
        (   grep {
                ( defined $self->satisfiable( $_, $model )
                        and $self->satisfiable( $_, $model ) == 0 )
                    ? 1
                    : 0
            } @{$clauses}
        ) > 0
        );

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
    my $self = shift;
    message $self->id, "Updating model \n\t< \t\n" . Dumper(@_) . " \t>";
    my $copy   = dclone(shift);
    my $choice = shift;
    my $value  = shift;
    $copy->{$choice} = $value;
    return $copy;
}

# ### resolve
# Resolve some variable to its actual value, or undefined.
sub resolve {
    my $self  = shift;
    my $var   = shift;
    my $model = shift;
    if ( substr( $var, 0, 1 ) eq "-" ) {
        my $value = $model->{ substr( $var, 1 ) };
        message $self->id,
            "Updating $var with " . !defined $value ? undef : !$value;
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
    my @clause  = @{$clauses};
    message $self->id, "Clauses: \n\t< \t" . Dumper($clauses) . " \t>";
    message $self->id, "Model: \n\t< \t" . Dumper($model) . " \t>";

    # If every variable is false, then the clause is false.
    message $self->id, "No clauses in the model" and return 0
        if (
        (   grep {
                ( defined $self->resolve( $_, $model )
                        and $self->resolve( $_, $model ) == 0 )
                    ? 0
                    : 1
            } @{$clauses}
        ) == 0
        );

    #If any variable is true, then the clause is true.
    message $self->id, "The clause is true" and return 1
        if (
        (   grep {
                ( defined $self->resolve( $_, $model )
                        and $self->resolve( $_, $model ) == 1 )
                    ? 1
                    : 0
            } @{$clauses}
        ) > 0
        );
    message $self->id, "I don't know about the clause";

    # Otherwise, we don't know what the clause is.
    return undef;
}

1;

__END__

