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
    #push @{"${caller}::ISA"}, 'Mojo';
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

Minosse - It's new $module

=head1 SYNOPSIS

    use Minosse;

=head1 DESCRIPTION

Minosse is ...

=head1 LICENSE

Copyright (C) mudler.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

mudler E<lt>mudler@dark-lab.netE<gt>

=cut

