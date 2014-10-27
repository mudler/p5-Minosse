package Minosse::IOLoop::Client;
use Deeme -base;

use Errno 'EINPROGRESS';
use IO::Socket::INET;
use Minosse::IOLoop;
use Scalar::Util 'weaken';
use Socket qw(IPPROTO_TCP SO_ERROR TCP_NODELAY);

# IPv6 support requires IO::Socket::IP
use constant IPV6 => $ENV{MINOSSE_NO_IPV6}
    ? 0
    : eval 'use IO::Socket::IP 0.20 (); 1';

# TLS support requires IO::Socket::SSL
use constant TLS => $ENV{MINOSSE_NO_TLS}
    ? 0
    : eval 'use IO::Socket::SSL 1.84 (); 1';
use constant TLS_READ  => TLS ? IO::Socket::SSL::SSL_WANT_READ()  : 0;
use constant TLS_WRITE => TLS ? IO::Socket::SSL::SSL_WANT_WRITE() : 0;

# SOCKS support requires IO::Socket::Socks
use constant SOCKS => $ENV{MINOSSE_NO_SOCKS}
    ? 0
    : eval 'use IO::Socket::Socks 0.64 (); 1';
use constant SOCKS_READ  => SOCKS ? IO::Socket::Socks::SOCKS_WANT_READ()  : 0;
use constant SOCKS_WRITE => SOCKS ? IO::Socket::Socks::SOCKS_WANT_WRITE() : 0;

has reactor => sub { Minosse::IOLoop->singleton->reactor };

sub DESTROY { shift->_cleanup }

sub connect {
    my $self = shift;
    my $args = ref $_[0] ? $_[0] : {@_};
    weaken $self;
    $self->reactor->next_tick( sub { $self && $self->_connect($args) } );
}

sub _cleanup {
    my $self = shift;
    return $self unless my $reactor = $self->reactor;
    $self->{$_} && $reactor->remove( delete $self->{$_} )
        for qw(timer handle);
    return $self;
}

sub _connect {
    my ( $self, $args ) = @_;

    my $handle;
    my $reactor = $self->reactor;
    my $address
        = $args->{socks_address} || ( $args->{address} ||= 'localhost' );
    my $port
        = $args->{socks_port} || $args->{port} || ( $args->{tls} ? 443 : 80 );
    unless ( $handle = $self->{handle} = $args->{handle} ) {
        my %options = (
            Blocking => 0,
            PeerAddr => $address eq 'localhost' ? '127.0.0.1' : $address,
            PeerPort => $port
        );
        $options{LocalAddr} = $args->{local_address}
            if $args->{local_address};
        $options{PeerAddr} =~ s/[\[\]]//g if $options{PeerAddr};
        my $class = IPV6 ? 'IO::Socket::IP' : 'IO::Socket::INET';
        return $self->emit( error => "Can't connect: $@" )
            unless $self->{handle} = $handle = $class->new(%options);
    }
    $handle->blocking(0);

    # Timeout
    $self->{timer} = $reactor->timer( $args->{timeout} || 10,
        sub { $self->emit( error => 'Connect timeout' ) } );

    # Wait for handle to become writable
    weaken $self;
    $reactor->io( $handle => sub { $self->_ready($args) } )
        ->watch( $handle, 0, 1 );
}

sub _ready {
    my ( $self, $args ) = @_;

    # Retry or handle exceptions
    my $handle = $self->{handle};
    return $! == EINPROGRESS ? undef : $self->emit( error => $! )
        if $handle->isa('IO::Socket::IP') && !$handle->connect;
    return $self->emit( error => $! = $handle->sockopt(SO_ERROR) )
        unless $handle->connected;

    # Disable Nagle's algorithm
    setsockopt $handle, IPPROTO_TCP, TCP_NODELAY, 1;

    $self->_try_socks($args);
}

sub _socks {
    my ( $self, $args ) = @_;

    # Connected
    my $handle = $self->{handle};
    return $self->_try_tls($args) if $handle->ready;

    # Switch between reading and writing
    my $err = $IO::Socket::Socks::SOCKS_ERROR;
    if    ( $err == SOCKS_READ )  { $self->reactor->watch( $handle, 1, 0 ) }
    elsif ( $err == SOCKS_WRITE ) { $self->reactor->watch( $handle, 1, 1 ) }
    else                          { $self->emit( error => $err ) }
}

sub _tls {
    my $self = shift;

    # Connected
    my $handle = $self->{handle};
    return $self->_cleanup->emit( connect => $handle )
        if $handle->connect_SSL;

    # Switch between reading and writing
    my $err = $IO::Socket::SSL::SSL_ERROR;
    if    ( $err == TLS_READ )  { $self->reactor->watch( $handle, 1, 0 ) }
    elsif ( $err == TLS_WRITE ) { $self->reactor->watch( $handle, 1, 1 ) }
}

sub _try_socks {
    my ( $self, $args ) = @_;

    my $handle = $self->{handle};
    return $self->_try_tls($args) unless $args->{socks_address};
    return $self->emit(
        error => 'IO::Socket::Socks 0.64 required for SOCKS support' )
        unless SOCKS;

    my %options
        = ( ConnectAddr => $args->{address}, ConnectPort => $args->{port} );
    @options{qw(AuthType Username Password)}
        = ( 'userpass', @$args{qw(socks_user socks_pass)} )
        if $args->{socks_user};
    my $reactor = $self->reactor;
    $reactor->remove($handle);
    return $self->emit( error => 'SOCKS upgrade failed' )
        unless IO::Socket::Socks->start_SOCKS( $handle, %options );
    weaken $self;
    $reactor->io( $handle => sub { $self->_socks($args) } )
        ->watch( $handle, 0, 1 );
}

sub _try_tls {
    my ( $self, $args ) = @_;

    my $handle = $self->{handle};
    return $self->_cleanup->emit( connect => $handle )
        if !$args->{tls} || $handle->isa('IO::Socket::SSL');
    return $self->emit(
        error => 'IO::Socket::SSL 1.84 required for TLS support' )
        unless TLS;

    # Upgrade
    weaken $self;
    my %options = (
        SSL_ca_file => $args->{tls_ca}
            && -T $args->{tls_ca} ? $args->{tls_ca} : undef,
        SSL_cert_file  => $args->{tls_cert},
        SSL_error_trap => sub { $self->emit( error => $_[1] ) },
        SSL_hostname   => IO::Socket::SSL->can_client_sni
        ? $args->{address}
        : '',
        SSL_key_file        => $args->{tls_key},
        SSL_startHandshake  => 0,
        SSL_verify_mode     => $args->{tls_ca} ? 0x01 : 0x00,
        SSL_verifycn_name   => $args->{address},
        SSL_verifycn_scheme => $args->{tls_ca} ? 'http' : undef
    );
    my $reactor = $self->reactor;
    $reactor->remove($handle);
    return $self->emit( error => 'TLS upgrade failed' )
        unless IO::Socket::SSL->start_SSL( $handle, %options );
    $reactor->io( $handle => sub { $self->_tls } )->watch( $handle, 0, 1 );
}

1;

=encoding utf8

=head1 NAME

L<Mojo::IOLoop::Client> fork

=cut
