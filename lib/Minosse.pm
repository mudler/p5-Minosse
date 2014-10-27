package Minosse;
use 5.008001;
use strict;
use warnings;
use Minosse::Util qw(monkey_patch);
use Deeme::Obj -base;
use Import::Into;

our $VERSION = "0.01";
my $NAME = eval 'use Sub::Util; 1' ? \&Sub::Util::set_subname : sub { $_[1] };

sub import {
    my ( $self, $env ) = ( shift, shift );

    # Remember executable for later
    $ENV{EXE} ||= (caller)[1];

    # Initialize application class
    my $caller = caller;

    #no strict 'refs';
    #push @{"${caller}::ISA"}, 'Minosse';
    #my $self=shift->new;
    if ($env) {
        eval 'use '.$env.';1;';
        monkey_patch $caller, on   => sub { $env->new->on(@_) };
        monkey_patch $caller, emit => sub { $env->new->emit(@_) };
    }

}

1;
__END__

=encoding utf-8

=head1 NAME

Minosse - A perl Discrete-Event simulator

=head1 DESCRIPTION

Minosse is under development, it's a small Perl Simulator Framework. Aim to be easy-to-use, portable and quick to hack to obtain your desired behaviour.

If you want to use it, install it and subclass the Agent and Environment classes. There are two example classes using an NFQ algorithm L<Minosse::Agent::NFQ> and L<Minosse::Agent::NFQ> using <Algorithm::QLearning>.

=head1 LICENSE

Copyright (C) mudler.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

mudler E<lt>mudler@dark-lab.netE<gt>

=cut

