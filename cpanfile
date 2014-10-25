requires 'Algorithm::QLearning::NFQ';
requires 'Data::Printer';
requires 'Deeme';
requires 'Deeme::Obj';
requires 'Encode';
requires 'Import::Into';
requires 'Mojo::Base';
requires 'Mojo::IOLoop::Client';
requires 'Mojo::IOLoop::Delay';
requires 'Mojo::IOLoop::Server';
requires 'Mojo::IOLoop::Stream';
requires 'Mojo::Reactor::Poll';
requires 'Mojo::Util';
requires 'Scalar::Util';
requires 'Term::ANSIColor';
requires 'feature';
requires 'perl', '5.008001';

on configure => sub {
    requires 'Module::Build::Tiny', '0.035';
};

on test => sub {
    requires 'Test::More', '0.98';
};
