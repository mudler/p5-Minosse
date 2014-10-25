package Minosse::Util;

use utf8;
use Encode;

use base 'Exporter';
use Term::ANSIColor;
use constant DEBUG => $ENV{DEBUG} || 0;

our @EXPORT    = qw(message DEBUG environment);
our @EXPORT_OK = qw(monkey_patch);

my $NAME = eval 'use Sub::Util; 1' ? \&Sub::Util::set_subname : sub { $_[1] };

sub monkey_patch {
    my ( $class, %patch ) = @_;
    no strict 'refs';
    no warnings 'redefine';
    *{"${class}::$_"} = $NAME->( "${class}::$_", $patch{$_} ) for keys %patch;
}

sub message {
    my $caller = caller;
    my $id     = shift;
    print STDERR color 'bold yellow';
    print STDERR encode_utf8( '☛ ' . $caller . '#' . $id . ' ☛ ' );
    print STDERR color 'bold white';
    print STDERR join( "\n", @_ ), "\n";
    print STDERR color 'reset';
}

sub environment {
    my $caller = caller;
    print STDERR color 'bold green';
    print STDERR encode_utf8( '☛ ' . $caller . ' ☛ ' );
    print STDERR color 'bold white';
    print STDERR join( "\n", @_ ), "\n";
    print STDERR color 'reset';
}

