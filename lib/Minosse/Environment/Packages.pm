package Minosse::Environment::Packages;

=head1 NAME

Minosse::Environment::Packages - Packages Environment for L<Minosse>

=head1 DESCRIPTION

L<Minosse::Environment::Packages> is a Neural fitted network agent implementation for the <Minosse> simulation framework.

=cut

use Deeme::Obj "Minosse::Environment";
use feature 'say';
use Data::Printer;
use Storable qw(dclone);
use Minosse::Util;
use Minosse::Util qw(slurp);
use constant INSTALL => 0;
use constant REMOVE  => 1;

use Cwd;
use Config;
use JSON::PP;
use CPAN::Meta::Check;
use CPAN::Meta::YAML;
use CPAN::Meta::Requirements;
use CPAN::Meta::Prereqs;
use HTTP::Request;
use Minosse::Asset::Dep;
use LWP::UserAgent;

use JSON;
use version ();

use local::lib;

has [qw(universe specfile)];

has 'force_install' => sub{1};
has actions => sub { [ INSTALL, REMOVE ] };

=head2 rewards

Here you can supply the reward matrix (you can subclass and override using a function)

=cut

sub prepare {
    my $self = shift;

    #Loads the universe and the specfile
    $self->{_universe} = decode_json( slurp( $self->universe ) );
    $self->{_specfile} = decode_json( slurp( $self->specfile ) );
    environment "Universe and Specfile are correctly loaded";
    p( $self->{_specfile} );
    p( $self->{_universe} );
    $self->init();
    die("test");
}

sub reward {

}

has rewards => sub { [] };

sub process {
    my $env            = shift;
    my $agent          = shift;
    my $action         = shift;
    my $status         = shift;
    my $implementation = $env->{_universe}->{implementation};

    #say "Action : $action , status: " . p($status);
    my $reward = -2;

    my $previous_status = dclone($status);

    #sleep 1;
    # Change status of the agent
    # $status->[1] += 1 if ( $action eq UP );
    # $status->[1] -= 1 if ( $action eq DOWN );
    # $status->[0] -= 1 if ( $action eq LEFT );
    # $status->[0] += 1 if ( $action eq RIGHT );
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

##### from cpanminus

sub grab_deps{
    my $self=shift;
        my $dist = $self->resolve_name( shift, shift );
    my @deps        = $self->find_prereqs($dist);
    environment "@deps ";
    return @deps;

}

sub cpan_module {
    my ( $self, $module, $dist, $version ) = @_;

    my $dist = $self->cpan_dist($dist);
    $dist->{module} = $module;
    $dist->{module_version} = $version if $version && $version ne 'undef';

    return $dist;
}

sub cpan_dist {
    my ( $self, $dist, $url ) = @_;

    $dist =~ s!^([A-Z]{2})!substr($1,0,1)."/".substr($1,0,2)."/".$1!e;

    require CPAN::DistnameInfo;
    my $d = CPAN::DistnameInfo->new($dist);

    if ($url) {
        $url = [$url] unless ref $url eq 'ARRAY';
    }
    else {
        my $id = $d->cpanid;
        my $fn
            = substr( $id, 0, 1 ) . "/"
            . substr( $id, 0, 2 ) . "/"
            . $id . "/"
            . $d->filename;

        my @mirrors = @{ $self->{mirrors} };
        my @urls = map "$_/authors/id/$fn", @mirrors;

        $url = \@urls,;
    }

    return {
        $d->properties,
        source => 'cpan',
        uris   => $url,
    };
}

sub find_best_match {
    my ( $self, $match, $version ) = @_;
    return unless $match && @{ $match->{hits}{hits} || [] };
    my @hits
        = $self->{dev_release}
        ? sort { &by_version || &by_date } @{ $match->{hits}{hits} }
        : sort { &by_version || &by_first_come } @{ $match->{hits}{hits} };
    $hits[0]->{fields};
}

sub by_version {
    my %s = qw( latest 3  cpan 2  backpan 1 );
    $b->{_score} <=> $a->{_score}
        ||    # version: higher version that satisfies the query
        $s{ $b->{fields}{status} } <=> $s{ $a->{fields}{status} }
        ;     # prefer non-BackPAN dist
}

sub by_first_come {
    $a->{fields}{date} cmp $b->{fields}{date}
        ;     # first one wins, if all are in BackPAN/CPAN
}

sub by_date {
    $b->{fields}{date} cmp $a->{fields}{date}
        ;     # prefer new uploads, when searching for dev
}

sub from_versions {
    my ( $class, $versions, $type ) = @_;

    my @deps;
    while ( my ( $module, $version ) = each %$versions ) {
        push @deps,
            Minosse::Asset::Dep->new(
            module  => $module,
            version => $version,
            type    => $type
            );
    }

    @deps;
}

sub parse_version {
    my ( $self, $module ) = @_;

    # Plack@1.2 -> Plack~"==1.2"
    # BUT don't expand @ in git URLs
    $module =~ s/^([A-Za-z0-9_:]+)@([v\d\._]+)$/$1~== $2/;

    # Plack~1.20, DBI~"> 1.0, <= 2.0"
    if ( $module =~ /\~[v\d\._,\!<>= ]+$/ ) {
        return split /\~/, $module, 2;
    }
    else {
        return $module, undef;
    }
}

sub install_module {
    my ( $self, $module, $depth, $version ) = @_;

    $self->check_libs;

    if ( $self->{seen}{$module}++ ) {

        # TODO: circular dependencies
        environment("Already tried $module. Skipping.");
        return 1;
    }

    if ( $self->{skip_satisfied} ) {
        my ( $ok, $local ) = $self->check_module( $module, $version || 0 );
        if ($ok) {
            environment( "You have $module ($local)" );
            return 1;
        }
    }

    my $dist = $self->resolve_name( $module, $version );
    unless ($dist) {
        my $what = $module . ( $version ? " ($version)" : "" );
        error( "Couldn't find module or a distribution $what" );
        return;
    }

    if ( $dist->{distvname} && $self->{seen}{ $dist->{distvname} }++ ) {
        environment("Already tried $dist->{distvname}. Skipping.");
        return 1;
    }

    $dist->{depth} = $depth;    # ugly hack

    if ( $dist->{module} ) {
        unless (
            $self->satisfy_version(
                $dist->{module}, $dist->{module_version}, $version
            )
            )
        {
            environment(
                "Found $dist->{module} $dist->{module_version} which doesn't satisfy $version.",
                1
            );
            return;
        }

# If a version is requested, it has to be the exact same version, otherwise, check as if
# it is the minimum version you need.
        my $cmp = $version ? "==" : "";
        my $requirement
            = $dist->{module_version} ? "$cmp$dist->{module_version}" : 0;
        my ( $ok, $local )
            = $self->check_module( $dist->{module}, $requirement );
        if ( $self->{skip_installed} && $ok ) {
            environment( "$dist->{module} is up to date. ($local)" );
            return 1;
        }
    }

    if ( $dist->{dist} eq 'perl' ) {
        environment("skipping $dist->{pathname}");
        return 1;
    }

    environment("--> Working on $module");

    return $self->build_stuff( $module, $dist, $depth );
}

sub search_inc {
    my $self = shift;
    $self->{search_inc} ||= do {

        # strip lib/ and fatlib/ from search path when booted from dev
        if ( defined $::Bin ) {
            [ grep !/^\Q$::Bin\E\/..\/(?:fat)?lib$/, @INC ];
        }
        else {
            [@INC];
        }
    };
}

sub check_module {
    my ( $self, $mod, $want_ver ) = @_;

    require Module::Metadata;
    my $meta
        = Module::Metadata->new_from_module( $mod, inc => $self->search_inc )
        or return 0, undef;

    my $version = $meta->version;

    # When -L is in use, the version loaded from 'perl' library path
    # might be newer than (or actually wasn't core at) the version
    # that is shipped with the current perl
    if ( $self->{self_contained} && $self->loaded_from_perl_lib($meta) ) {
        $version = $self->core_version_for($mod);
        return 0, undef if $version && $version == -1;
    }

    $self->{local_versions}{$mod} = $version;

    if ( $self->is_deprecated($meta) ) {
        return 0, $version;
    }
    elsif ( $self->satisfy_version( $mod, $version, $want_ver ) ) {
        return 1, ( $version || 'undef' );
    }
    else {
        return 0, $version;
    }
}

sub is_deprecated {
    my ( $self, $meta ) = @_;

    my $deprecated = eval {
        require Module::CoreList;    # no fatpack
        Module::CoreList::is_deprecated( $meta->{module} );
    };

    return $deprecated && $self->loaded_from_perl_lib($meta);
}

sub loaded_from_perl_lib {
    my ( $self, $meta ) = @_;

    require Config;
    for my $dir (qw(archlibexp privlibexp)) {
        my $confdir = $Config{$dir};
        if ( $confdir eq substr( $meta->filename, 0, length($confdir) ) ) {
            return 1;
        }
    }

    return;
}

sub install_deps_bailout {
    my ( $self, $target, $dir, $depth, @deps ) = @_;

    my ( $ok, $fail ) = $self->install_deps( $dir, $depth, @deps );
    if ( !$ok ) {
        error( "Installing the dependencies failed: " . join( ", ", @$fail ));
        unless (
            $self->force_install == 0
            )
        {
            error( "Bailing out the installation for $target." );
            return;
        }
    }

    return 1;
}

sub satisfy_version {
    my ( $self, $mod, $version, $want_ver ) = @_;

    $want_ver = '0' unless defined($want_ver) && length($want_ver);

    require CPAN::Meta::Requirements;
    my $requirements = CPAN::Meta::Requirements->new;
    $requirements->add_string_requirement( $mod, $want_ver );
    $requirements->accepts_module( $mod, $version );
}

# TODO extract this as a module?
sub version_to_query {
    my ( $self, $module, $version ) = @_;

    require CPAN::Meta::Requirements;

    my $requirements = CPAN::Meta::Requirements->new;
    $requirements->add_string_requirement( $module, $version || '0' );

    my $req = $requirements->requirements_for_module($module);

    if ( $req =~ s/^==\s*// ) {
        return { term => { 'module.version' => $req }, };
    }
    elsif ( $req !~ /\s/ ) {
        return {
            range => {
                'module.version_numified' =>
                    { 'gte' => $self->numify_ver_metacpan($req) }
            },
        };
    }
    else {
        my %ops = qw(< lt <= lte > gt >= gte);
        my ( %range, @exclusion );
        my @requirements = split /,\s*/, $req;
        for my $r (@requirements) {
            if ( $r =~ s/^([<>]=?)\s*// ) {
                $range{ $ops{$1} } = $self->numify_ver_metacpan($r);
            }
            elsif ( $r =~ s/\!=\s*// ) {
                push @exclusion, $self->numify_ver_metacpan($r);
            }
        }

        my @filters
            = ( { range => { 'module.version_numified' => \%range } }, );

        if (@exclusion) {
            push @filters, {
                not => {
                    or => [
                        map {
                            +{  term => {
                                    'module.version_numified' =>
                                        $self->numify_ver_metacpan($_)
                                }
                                }
                        } @exclusion
                    ]
                },
            };
        }

        return @filters;
    }
}

# Apparently MetaCPAN numifies devel releases by stripping _ first
sub numify_ver_metacpan {
    my ( $self, $ver ) = @_;
    $ver =~ s/_//g;
    version->new($ver)->numify;
}

sub check_libs {
    my $self = shift;
    return if $self->{_checked}++;

    $self->bootstrap_local_lib;
    if ( @{ $self->{bootstrap_deps} || [] } ) {
        local $self->{notest}
            = 1;    # test failure in bootstrap should be tolerated
        local $self->{scandeps} = 0;
        $self->install_deps( Cwd::cwd, 0, @{ $self->{bootstrap_deps} } );
    }
}

sub bootstrap_local_lib {
    my $self = shift;

    # If -l is specified, use that.
    if ( $self->{local_lib} ) {
        return $self->setup_local_lib( $self->{local_lib} );
    }

# PERL_LOCAL_LIB_ROOT is defined. Run as local::lib mode without overwriting ENV
    if ( $ENV{PERL_LOCAL_LIB_ROOT} && $ENV{PERL_MM_OPT} ) {
        return $self->setup_local_lib(
            $self->local_lib_target( $ENV{PERL_LOCAL_LIB_ROOT} ), 1 );
    }

    # root, locally-installed perl or --sudo: don't care about install_base
    return;

    # local::lib is configured in the shell -- yay
    if ( $ENV{PERL_MM_OPT} and ( $ENV{MODULEBUILDRC} or $ENV{PERL_MB_OPT} ) )
    {
        $self->bootstrap_local_lib_deps;
        return;
    }

    $self->setup_local_lib;

    environment( "
!
! Can't write to $Config{installsitelib} and $Config{installsitebin}: Installing modules to $ENV{HOME}/perl5
! To turn off this warning, you have to do one of the following:
!   - run me as a root or with --sudo option (to install to $Config{installsitelib} and $Config{installsitebin})
!   - Configure local::lib your existing local::lib in this shell to set PERL_MM_OPT etc.
!   - Install local::lib by running the following commands
!
!         cpanm --local-lib=~/perl5 local::lib && eval \$(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)
!
"
    );
    sleep 2;
}

sub local_lib_target {
    my ( $self, $root ) = @_;

    # local::lib 1.008025 changed the order of PERL_LOCAL_LIB_ROOT
    ( grep { $_ ne '' } split /\Q$Config{path_sep}/, $root )[0];
}

sub _setup_local_lib_env {
    my ( $self, $base ) = @_;

    environment(
        "WARNING: Your lib directory name ($base) contains a space in it. It's known to cause issues with perl builder tools such as local::lib and MakeMaker. You're recommended to rename your directory."
    ) if $base =~ /\s/;
    local $SIG{__WARN__} = sub { };    # catch 'Attempting to write ...'
    local::lib->setup_env_hash_for( $base, 0 );
}

sub setup_local_lib {
    my ( $self, $base, $no_env ) = @_;
    $base = undef if $base eq '_';

    require local::lib;
    {
        local $0 = 'cpanm';            # so curl/wget | perl works
        $base ||= "~/perl5";
        $base = local::lib->resolve_path($base);
        if ( $self->{self_contained} ) {
            my @inc = $self->_core_only_inc($base);
            $self->{search_inc} = [@inc];
        }
        else {
            $self->{search_inc} = [
                local::lib->install_base_arch_path($base),
                local::lib->install_base_perl_path($base),
                @INC,
            ];
        }
        $self->_setup_local_lib_env($base) unless $no_env;
        $self->{local_lib} = $base;
    }

    $self->bootstrap_local_lib_deps;
}
sub should_install {
    my($self, $mod, $ver) = @_;

    environment("Checking if you have $mod $ver ... ");
    my($ok, $local) = $self->check_module($mod, $ver);

    if ($ok)       { environment("Yes ($local)") }
    elsif ($local) { environment("No (" . $self->unsatisfy_how($local, $ver) . ")") }
    else           { environment("No") }

    return $mod unless $ok;
    return;
}
sub check_perl_version {
    my($self, $version) = @_;
    require CPAN::Meta::Requirements;
    my $req = CPAN::Meta::Requirements->from_string_hash({ perl => $version });
    $req->accepts_module(perl => $]);
}

sub install_deps {
    my ( $self, $dir, $depth, @deps ) = @_;
    my ( @install, %seen, @fail );
    for my $dep (@deps) {
        next if $seen{ $dep->module };
        if ( $dep->module eq 'perl' ) {
            if ( $dep->is_requirement
                && !$self->check_perl_version( $dep->version ) )
            {
                environment("Needs perl @{[$dep->version]}, you have $]");
                push @fail, 'perl';
            }
        }
        elsif ( $self->should_install( $dep->module, $dep->version ) ) {
            push @install, $dep;
            $seen{ $dep->module } = 1;
        }
    }

    if (@install) {
        environment( "==> Found dependencies: "
                . join( ", ", map $_->module, @install )
                . "" );
    }

    for my $dep (@install) {
        $self->install_module( $dep->module, $depth + 1, $dep->version );
    }

    if ( $self->{scandeps} ) {
        return
            1
            ; # Don't check if dependencies are installed, since with --scandeps they aren't
    }
    my @not_ok = $self->unsatisfied_deps(@deps);
    if (@not_ok) {
        return 0, \@not_ok;
    }
    else {
        return 1;
    }
}

sub configure_features {
    my ( $self, $dist, @features ) = @_;
    map $_->identifier,
        grep { $self->effective_feature( $dist, $_ ) } @features;
}

sub effective_feature {
    my ( $self, $dist, $feature ) = @_;

    if ( $dist->{depth} == 0 ) {
        my $value = $self->{features}{ $feature->identifier };
        return $value if defined $value;
        return 1 if $self->{features}{__all};
    }

    if ( $self->{interactive} ) {
        require CPAN::Meta::Requirements;

        environment( "[@{[ $feature->description ]}]" );

        my $req = CPAN::Meta::Requirements->new;
        for my $phase ( @{ $dist->{want_phases} } ) {
            for my $type ( @{ $self->{install_types} } ) {
                $req->add_requirements(
                    $feature->prereqs->requirements_for( $phase, $type ) );
            }
        }

        my $reqs = $req->as_string_hash;
        my @missing;
        for my $module ( keys %$reqs ) {
            if ( $self->should_install( $module, $req->{$module} ) ) {
                push @missing, $module;
            }
        }

        if (@missing) {
            my $howmany = @missing;
            environment(
                "==> Found missing dependencies: "
                    . join( ", ", @missing )
            );
            local $self->{prompt} = 1;
            return $self->prompt_bool(
                "Install the $howmany optional module(s)?", "y" );
        }
    }

    return;
}

sub from_prereqs {
    my ( $class, $prereq, $phases, $types ) = @_;
    environment( p(@_) );
    $types = ['requires'];
    $phases = [ 'runtime', 'configure', 'build' ];
    my @deps;
    environment("finding prereqs");
    for my $type (@$types) {
        my $req = CPAN::Meta::Requirements->new;
        $req->add_requirements( $prereq->requirements_for( $_, $type ) )
            for @$phases;
        environment( p( $req->as_string_hash ) );
        push @deps, $class->from_versions( $req->as_string_hash, $type );
    }

    return @deps;
}

sub extract_meta_prereqs {
    my ( $self, $dist ) = @_;

    if ( $dist->{cpanfile} ) {
        my @features
            = $self->configure_features( $dist, $dist->{cpanfile}->features );
        my $prereqs = $dist->{cpanfile}->prereqs_with(@features);
        return $self->from_prereqs( $prereqs, $dist->{want_phases},
            $self->{install_types} );
    }

    require CPAN::Meta;
    my $meta = $self->get( $dist->{'META'} );

    my @deps;
    if ($meta) {
        environment("Checking dependencies from $dist->{META} ...");
        my $mymeta = eval {
            CPAN::Meta->load_yaml_string( $meta, { lazy_validation => 1 } );
        };
        $mymeta = eval {
            CPAN::Meta->load_json_string( $meta, { lazy_validation => 1 } );
        } if !$mymeta;
        if ($mymeta) {
            environment("Good");
            $dist->{meta}{name}    = $mymeta->name;
            $dist->{meta}{version} = $mymeta->version;
            return $self->extract_prereqs( $mymeta, $dist );
        }
    }

    return @deps;
}

sub extract_prereqs {
    my ( $self, $meta, $dist ) = @_;
    my @features = $self->configure_features( $dist, $meta->features );
    return $self->from_prereqs( $meta->effective_prereqs( \@features ),
        $dist->{want_phases}, $self->{install_types} );
}

sub safe_eval {
    my ( $self, $code ) = @_;
    eval $code;
}

sub find_module_name {
    my ( $self, $state ) = @_;

    return unless $state->{configured_ok};

    if ( $state->{use_module_build}
        && -e "_build/build_params" )
    {
        my $params = do {
            open my $in, "_build/build_params";
            $self->safe_eval( join "", <$in> );
        };
        return eval { $params->[2]{module_name} } || undef;
    }
    elsif ( -e "Makefile" ) {
        open my $mf, "Makefile";
        while (<$mf>) {
            if (/^\#\s+NAME\s+=>\s+(.*)/) {
                return $self->safe_eval($1);
            }
        }
    }

    return;
}

sub build_stuff {
    my ( $self, $stuff, $dist, $depth ) = @_;

    require CPAN::Meta;

    environment("META.yml/json not found. Creating skeleton for it.");
    $dist->{cpanmeta} = CPAN::Meta->new(
        { name => $dist->{dist}, version => $dist->{version} } );

    $dist->{meta} = $dist->{cpanmeta} ? $dist->{cpanmeta}->as_struct : {};

    my @config_deps;
    if ( $dist->{cpanmeta} ) {
        push @config_deps,
            $self->from_prereqs(
            $dist->{cpanmeta}->effective_prereqs,
            ['configure'], $self->{install_types},
            );
    }

    my $target
        = $dist->{meta}{name}
        ? "$dist->{meta}{name}-$dist->{meta}{version}"
        : $dist->{dir};

    $self->install_deps_bailout( $target, $dist->{dir}, $depth, @config_deps )
        or return;

    environment("Configuring $target");

    my @deps        = $self->find_prereqs($dist);
    my $module_name = $dist->{meta}{name};
    $module_name =~ s/-/::/g;

    if ( $self->{showdeps} ) {
        for my $dep ( @config_deps, @deps ) {
            environment $dep->module,
                ( $dep->version ? ( "~" . $dep->version ) : "" );
        }
        return 1;
    }

    my $distname
        = $dist->{meta}{name}
        ? "$dist->{meta}{name}-$dist->{meta}{version}"
        : $stuff;

    my $walkup;
    if ( $self->{scandeps} ) {
        $walkup = $self->scandeps_append_child($dist);
    }

    $self->install_deps_bailout( $distname, $dist->{dir}, $depth, @deps )
        or return;

    if ( $self->{scandeps} ) {
        $walkup->();
        return 1;
    }

    if ( $self->{installdeps} && $depth == 0 ) {

        environment("<== Installed dependencies for $stuff. Finishing.");
        return 1;

    }

    my $installed;
    environment(
        "Building " . ( $self->{notest} ? "" : "and testing " ) . $distname );
    $installed++;

    my $local = $self->{local_versions}{ $dist->{module} || '' };
    my $version
        = $dist->{module_version}
        || $dist->{meta}{version}
        || $dist->{version};
    my $reinstall = $local && ( $local eq $version );
    my $action
        = $local && !$reinstall
        ? $self->numify_ver($version) < $self->numify_ver($local)
            ? "downgraded"
            : "upgraded"
        : undef;

    my $how
        = $reinstall ? "reinstalled $distname"
        : $local     ? "installed $distname ($action from $local)"
        :              "installed $distname";
    my $msg = "Successfully $how";
    environment( "$msg" );
    $self->{installed_dists}++;

   #   $self->save_meta( $stuff, $dist, $module_name, \@config_deps, \@deps );
    return 1;

}

sub find_prereqs {
    my ( $self, $dist ) = @_;
    environment("Finding deps");
    my @deps = $self->extract_meta_prereqs($dist);

    return @deps;
}

sub resolve_name {
    my ( $self, $module, $version ) = @_;

    # URL
    if ( $module =~ /^(ftp|https?|file):/ ) {
        if ( $module =~ m!authors/id/(.*)! ) {
            return $self->cpan_dist( $1, $module );
        }
        else {
            return { uris => [$module] };
        }
    }

    # Directory
    if ( $module =~ m!^[\./]! && -d $module ) {
        return {
            source => 'local',
            dir    => Cwd::abs_path($module),
        };
    }

    # File
    if ( -f $module ) {
        return {
            source => 'local',
            uris   => [ "file://" . Cwd::abs_path($module) ],
        };
    }

    # Git
    if ( $module =~ /(?:^git:|\.git(?:@.+)?$)/ ) {
        return $self->git_uri($module);
    }

    # cpan URI
    if ( $module =~ s!^cpan:///distfile/!! ) {
        return $self->cpan_dist($module);
    }

    # PAUSEID/foo
    # P/PA/PAUSEID/foo
    if ( $module =~ m!^(?:[A-Z]/[A-Z]{2}/)?([A-Z]{2}[\-A-Z0-9]*/.*)$! ) {
        return $self->cpan_dist($1);
    }

    # Module name
    return $self->search_module( $module, $version );
}

sub search_module {
    my ( $self, $module, $version ) = @_;

    if ( $self->{mirror_index} ) {
        $self->mask_output( chat =>
                "Searching $module on mirror index $self->{mirror_index} ..."
        );
        my $pkg = $self->search_mirror_index_file( $self->{mirror_index},
            $module, $version );
        return $pkg if $pkg;

        unless ( $self->{cascade_search} ) {
            $self->mask_output( diag_fail =>
                    "Finding $module ($version) on mirror index $self->{mirror_index} failed."
            );
            return;
        }
    }

    unless ( $self->{mirror_only} ) {
        my $found = $self->search_metacpan( $module, $version );
        return $found if $found;
    }

MIRROR: for my $mirror ( @{ $self->{mirrors} } ) {
        $self->mask_output(
            chat => "Searching $module on mirror $mirror ..." );
        my $name    = '02packages.details.txt.gz';
        my $uri     = "$mirror/modules/$name";
        my $gz_file = $self->package_index_for($mirror) . '.gz';

        unless ( $self->{pkgs}{$uri} ) {
            $self->mask_output( chat => "Downloading index file $uri ..." );
            $self->mirror( $uri, $gz_file );
            $self->generate_mirror_index($mirror) or next MIRROR;
            $self->{pkgs}{$uri} = "!!retrieved!!";
        }

        my $pkg = $self->search_mirror_index( $mirror, $module, $version );
        return $pkg if $pkg;

        $self->mask_output( diag_fail =>
                "Finding $module ($version) on mirror $mirror failed." );
    }

    return;
}

sub search_metacpan {
    my ( $self, $module, $version ) = @_;

    require JSON::PP;

    environment("Searching $module ($version) on metacpan ...");

    my $metacpan_uri = 'http://api.metacpan.org/v0';

    my $query = {
        filtered => {
            ( () ),
            query => {
                nested => {
                    score_mode => 'max',
                    path       => 'module',
                    query      => {
                        custom_score => {
                            metacpan_script => "score_version_numified",
                            query           => {
                                constant_score => {
                                    filter => {
                                        and => [
                                            {   term => {
                                                    'module.authorized' =>
                                                        JSON::PP::true()
                                                }
                                            },
                                            {   term => {
                                                    'module.indexed' =>
                                                        JSON::PP::true()
                                                }
                                            },
                                            {   term => {
                                                    'module.name' => $module
                                                }
                                            },
                                            $self->version_to_query(
                                                $module, $version
                                            ),
                                        ]
                                    }
                                }
                            },
                        }
                    },
                }
            },
        }
    };

    my $module_uri = "$metacpan_uri/file/_search?source=";
    $module_uri .= $self->encode_json(
        {   query  => $query,
            fields => [ 'date', 'release', 'author', 'module', 'status' ],
        }
    );

    my ( $release, $author, $module_version );

    my $module_json = $self->get($module_uri);
    my $module_meta = eval { JSON::PP::decode_json($module_json) };
    my $match       = $self->find_best_match($module_meta);
    if ($match) {
        $release = $match->{release};
        $author  = $match->{author};
        my $module_matched
            = ( grep { $_->{name} eq $module } @{ $match->{module} } )[0];
        $module_version = $module_matched->{version};
    }

    unless ($release) {
        environment(
            "! Could not find a release matching $module ($version) on MetaCPAN."
        );
        return;
    }

    my $dist_uri = "$metacpan_uri/release/_search?source=";
    $dist_uri .= $self->encode_json(
        {   filter => {
                and => [
                    { term => { 'release.name'   => $release } },
                    { term => { 'release.author' => $author } },
                ]
            },
            fields => [ 'download_url', 'stat', 'status' ],
        }
    );

    my $dist_json = $self->get($dist_uri);
    my $dist_meta = eval { JSON::PP::decode_json($dist_json) };

    if ($dist_meta) {
        $dist_meta = $dist_meta->{hits}{hits}[0]{fields};
    }
    if ( $dist_meta && $dist_meta->{download_url} ) {
        ( my $distfile = $dist_meta->{download_url} ) =~ s!.+/authors/id/!!;
        local $self->{mirrors} = $self->{mirrors};
        if ( $dist_meta->{status} eq 'backpan' ) {
            $self->{mirrors} = ['http://backpan.perl.org'];
        }
        else {
            $self->{mirrors} = ['http://cpan.metacpan.org'];
        }

        my $m = $self->cpan_module( $module, $distfile, $module_version );
        $m->{'META'} = $dist_meta->{download_url};
        $m->{'META'} =~ s/\.tar\.gz/\.meta/g;
        return $m;
    }

    error("Finding $module on metacpan failed.");
    return;
}

sub encode_json {
    my ( $self, $data ) = @_;
    my $json = JSON::PP::encode_json($data);
    $json =~ s/([^a-zA-Z0-9_\-.])/uc sprintf("%%%02x",ord($1))/eg;
    $json;
}

sub get {
    my ( $self, $uri ) = @_;
    if ( $uri =~ /^file:/ ) {
        $self->file_get($uri);
    }
    else {
        $self->{_backends}{get}->(@_);
    }
}

sub file_get {
    my ( $self, $uri ) = @_;
    my $file = $self->uri_to_file($uri);
    open my $fh, "<$file" or return;
    join '', <$fh>;
}

sub agent {
    my $self  = shift;
    my $agent = "minosse";
    $agent .= " perl/$]" if $self->{report_perl_version};
    $agent;
}

sub unsatisfied_deps {
    my ( $self, @deps ) = @_;

    my $reqs = CPAN::Meta::Requirements->new;
    for my $dep ( grep $_->is_requirement, @deps ) {
        $reqs->add_string_requirement( $dep->module => $dep->version || '0' );
    }

    my $ret = CPAN::Meta::Check::check_requirements( $reqs, 'requires',
        $self->{search_inc} );
    grep defined, values %$ret;
}

sub init {
    my $self = shift;
    my $ua   = sub {
        LWP::UserAgent->new(
            parse_head => 0,
            env_proxy  => 1,
            agent      => $self->agent,
            timeout    => 30,
            @_,
        );
    };
    $self->{_backends}{get} = sub {
        my $self = shift;
        my $res = $ua->()->request( HTTP::Request->new( GET => $_[0] ) );
        return unless $res->is_success;
        return $res->decoded_content;
    };
}

1;
