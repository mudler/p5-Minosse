package Minosse::Util;

use utf8;
use Encode;

use base 'Exporter';
use Term::ANSIColor;
use constant DEBUG => $ENV{DEBUG} || 0;
use MIME::Base64 qw(decode_base64 encode_base64);
use Time::HiRes ();
use Digest::MD5 qw(md5 md5_hex);

# Check for monotonic clock support
use constant MONOTONIC => eval
    '!!Time::HiRes::clock_gettime(Time::HiRes::CLOCK_MONOTONIC())';
our @EXPORT = qw(message DEBUG environment warning);
our @EXPORT_OK
    = qw(monkey_patch _stash b64_decode b64_encode class_to_path steady_time md5_sum);

my $NAME = eval 'use Sub::Util; 1' ? \&Sub::Util::set_subname : sub { $_[1] };
sub b64_decode    { decode_base64( $_[0] ) }
sub b64_encode    { encode_base64( $_[0], $_[1] ) }
sub class_to_path { join '.', join( '/', split /::|'/, shift ), 'pm' }

sub steady_time () {
    MONOTONIC
        ? Time::HiRes::clock_gettime( Time::HiRes::CLOCK_MONOTONIC() )
        : Time::HiRes::time;
}
sub md5_sum { md5_hex(@_) }

sub _stash {
    my ( $name, $object ) = ( shift, shift );

    # Hash
    my $dict = $object->{$name} ||= {};
    return $dict unless @_;

    # Get
    return $dict->{ $_[0] } unless @_ > 1 || ref $_[0];

    # Set
    my $values = ref $_[0] ? $_[0] : {@_};
    @$dict{ keys %$values } = values %$values;

    return $object;
}

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
    print STDERR encode_utf8( '❰ ' . $caller . ' ❱ ♦ ' . $id . ' ♦ ' );
    print STDERR color 'bold blue';
    print STDERR join( "\n", @_ ), "\n";
    print STDERR color 'reset';
}

sub environment {
    my $caller = caller;
    print STDERR color 'bold magenta';
    print STDERR encode_utf8( '❰ ' . $caller . ' ❱ ' );
    print STDERR color 'bold green';
    print STDERR join( "\n", @_ ), "\n";
    print STDERR color 'reset';
}

sub warning {
    print STDERR color 'bold green';
    print STDERR encode_utf8('→ ');
    print STDERR color 'bold white';
    print STDERR join( "\n", @_ ), "\n";
    print STDERR color 'reset';
}

