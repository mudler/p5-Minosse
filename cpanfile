requires 'Algorithm::QLearning::NFQ';
requires 'Data::Printer';
requires 'Deeme';
requires 'Deeme::Obj';
requires 'Digest::MD5';
requires 'EV', '4.0';
requires 'Encode';
requires 'Hash::Util::FieldHash';
requires 'IO::Pipely';
requires 'Import::Into';
requires 'JSON';
requires 'List::Util';
requires 'MIME::Base64';
requires 'Perl::OSType';
requires 'Scalar::Util';
requires 'Socket';
requires 'Term::ANSIColor';
requires 'Time::HiRes';
requires 'feature';
requires 'perl', '5.008001';

on configure => sub {
    requires 'Module::Build::Tiny', '0.035';
};

on test => sub {
    requires 'Test::More', '0.98';
};
