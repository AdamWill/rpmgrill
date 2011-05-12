# -*- perl -*-
#
# RPM::Grill::Plugin::RpmScripts - FIXME
#
# $Id$
#
# Real-world packages that trigger errors in this module:
# See t/RPM::Grill/Plugin/90real-world.t
#
package RPM::Grill::Plugin::RpmScripts;

use base qw(RPM::Grill);

use strict;
use warnings;
use version; our $VERSION = qv( '0.0.1' );

use Carp;
use Getopt::Long                qw(:config gnu_getopt);
use Text::ParseWords;
use RPM::Grill::dprintf;

# Program name of our caller
( our $ME = $0 ) =~ s|.*/||;

###############################################################################
# BEGIN user-configurable section

# Sequence number for this plugin
sub order {90}

# One-line description of this plugin
sub blurb { return "checks for problems with useradd, etc" }

# FIXME
sub doc {
    return <<"END_DOC" }
FIXME FIXME FIXME
END_DOC

#
# Command-line options for the useradd and groupadd commands.
#
our %Command_Line_Options;
#
# This is a direct copy-paste from shadow-utils-4.1.4.2-9.el6 /src/useradd.c
#
$Command_Line_Options{useradd} = <<'END_USERADD_OPTS';
                static struct option long_options[] = {
                        {"base-dir", required_argument, NULL, 'b'},
                        {"comment", required_argument, NULL, 'c'},
                        {"home-dir", required_argument, NULL, 'd'},
                        {"defaults", no_argument, NULL, 'D'},
                        {"expiredate", required_argument, NULL, 'e'},
                        {"inactive", required_argument, NULL, 'f'},
                        {"gid", required_argument, NULL, 'g'},
                        {"groups", required_argument, NULL, 'G'},
                        {"help", no_argument, NULL, 'h'},
                        {"skel", required_argument, NULL, 'k'},
                        {"key", required_argument, NULL, 'K'},
                        {"create-home", no_argument, NULL, 'm'},
                        {"no-create-home", no_argument, NULL, 'M'},
                        {"no-log-init", no_argument, NULL, 'l'},
                        {"no-user-group", no_argument, NULL, 'N'},
                        {"non-unique", no_argument, NULL, 'o'},
                        {"password", required_argument, NULL, 'p'},
                        {"system", no_argument, NULL, 'r'},
                        {"shell", required_argument, NULL, 's'},
#ifdef WITH_SELINUX
                        {"selinux-user", required_argument, NULL, 'Z'},
#endif
                        {"uid", required_argument, NULL, 'u'},
                        {"user-group", no_argument, NULL, 'U'},
                        {NULL, 0, NULL, '\0'}
END_USERADD_OPTS
#
# This is a direct copy-paste from shadow-utils-4.1.4.2-9.el6 /src/groupadd.c
#
$Command_Line_Options{groupadd} = <<'END_GROUPADD_OPTS';
        static struct option long_options[] = {
                {"force", no_argument, NULL, 'f'},
                {"gid", required_argument, NULL, 'g'},
                {"help", no_argument, NULL, 'h'},
                {"key", required_argument, NULL, 'K'},
                {"non-unique", no_argument, NULL, 'o'},
                {"password", required_argument, NULL, 'p'},
                {"system", no_argument, NULL, 'r'},
                {NULL, 0, NULL, '\0'}
END_GROUPADD_OPTS

# Convert that
my %Getopt_Options;
for my $cmd (sort keys %Command_Line_Options) {
  LINE:
    for my $line ( split "\n", $Command_Line_Options{$cmd} ) {
        $line =~ m|^\s+\{\s* "(.*?)",\s* (.*?)_argument,\s* .*?,\s* '(.)'\s*\}|x
            or next LINE;
        my ( $long, $type, $short ) = ( $1, $2, $3 );
        $type eq 'required' || $type eq 'no'
            or die "Internal error: option '$long': unknown ${type}_argument";

        my $x = "$long|$short";
        $x .= ":s" if $type eq 'required';

        push @{ $Getopt_Options{$cmd} }, $x;
    }
}

#use Data::Dumper; print Dumper(\%Getopt_Options);

#
# At script start time, read the uidgid file from the 'setup' package.
#
my $UidGid_File;
my %UidGid;
{
    my @label;                 # NAME, UID, GID, etc

    my $uidgid_glob = '/usr/share/doc/setup-*/uidgid';
    my @uidgid_file = glob( $uidgid_glob )
        or die "$ME: No match for '$uidgid_glob'";
    open my $uidgid_fh, '<', $uidgid_file[0]
        or die "$ME: Cannot read $uidgid_file[0]: $!\n";

  LINE:
    while (<$uidgid_fh>) {
        next LINE               if /^\s*\#/;            # skip comments

        # File format is:
        #
        #   NAME    UID     GID     HOME            SHELL   PACKAGES
        #   root    0       0       /root           /bin/bash       setup
        #   bin     1       1       /bin            /sbin/nologin   setup
        #   ...
        #
        # ...where the first row contains the names of the fields, subsequent
        # rows contain actual usernames/etc.
        chomp;
        if (my @values = split ' ', $_) {
            if (! @label) {
                @label = @values;
            }
            else {
                my %x = map { $label[$_] => $values[$_] } (0 .. $#label);

                # Special case: handle something like this:
                #
                #   vdsm    36      -       /       /bin/bash   kvm, vdsm
                #   wine    -       66      -       -           wine
                #
                # ...which has a gid but no UID or vice-versa.
                $x{UID} = undef         if $x{UID} eq '-';
                $x{GID} = undef         if $x{GID} eq '-';

                # Preserve, keyed on username
                $UidGid{$values[0]} = \%x;
            }
        }
    }
    close $uidgid_fh;

    $UidGid_File = $uidgid_file[0];

#    use Data::Dumper; print Dumper(\%UidGid);
}

# END   user-configurable section
###############################################################################

#
# Calls $self->gripe() with problems
#
sub analyze {
    my $self = shift;    # in: FIXME

    # FIXME: read spec, check specs-and-triggers,
    # FIXME: check for shell other than /bin/noshell(?)
    # FIXME: check for missing UID/GID

    # FIXME: read all the RPM.scripts files, not the spec

    # FIXME: read a file containing uid mappings

    #
    # Find the specfile. Iterate over its lines, looking for useradd
    # or groupadd commands. (We try to handle '||' stuff, eg this
    # from systemtap-1.3.4.el5.spec:
    #
    #    getent passwd stap-server >/dev/null ||
    #      useradd [...] -u 155 -g stap-server stap-server || \
    #      useradd [...]        -g stap-server stap-server
    #
    my $spec  = $self->specfile;
    my @lines = $spec->lines;

  LINE:
    for (my $i=0; $i < @lines; $i++) {
        my $line = $lines[$i];

        my $s       = $line->content;
        my $section = $line->section;
        my $lineno  = $line->lineno;

        # Skip comments
        next LINE               if $s =~ /^\s*#/;

        # Skip prereqs, eg PreReq: %{_sbindir}/groupadd, %{_sbindir}/useradd
        next LINE               if $section eq 'preamble';

        # changelog is the end, and contains no executable code
        last LINE               if $section eq 'changelog';

        # Concatenate continuation lines into one long line
        $s .= $lines[++$i]->content       while $s =~ s{\s*\\$}{ };

        # Split by actual command, eg 'useradd abc || useradd def'
        my @cmds = split /\s+\|\|\s+/, $s;

        for my $x (@cmds) {
            if ($x =~ /\b((user|group)add\b.*)/) {
                my $cmd = $1;

                # Remove redirection, eg '2>/dev/null'
                $cmd =~ s{\s+\d*>\s*\S+}{ }g;

                # Remove trailing whitespace
                $cmd =~ s/\s+$//;

                dprintf "%d : %s : %s\n", $line->lineno, $line->section, $cmd;

                # Set up context (for gripes), and analyze the line
                $spec->context({
                    lineno  => $lineno,
                    excerpt => $cmd,
                    sub     => $section,
                });
                _check_generic_add( $spec, $cmd );
            }
        }
    }
}


########################
#  _check_generic_add  # Setup is the same for useradd/groupadd
########################
sub _check_generic_add {
    my $spec = shift;                   # in: specfile obj
    my $cmd  = shift;                   # in: command, as one string

    # Split the string into tokens; Text::ParseWords will handle
    # things like: useradd -c "This is a comment" foo
    my @words = quotewords('\s+', 0, $cmd);

    # First word will be the command itself, useradd or groupadd
    my $add_command = shift @words;
    $add_command =~ s{^.*/}{};          # just the basename

    # Parse the command-line options
    my $getopt_options = $Getopt_Options{$add_command}
        or die "$ME: Internal error: unknown add command '$add_command'";
    local (@ARGV) = @words;
    my %options;
    GetOptions( \%options, @{$getopt_options});

    # There must be exactly one argument remaining, and that's the
    # name of the user or group to be added.
    my $arg = shift(@ARGV)
        or do {
            # FIXME: this deserves a gripe
            warn "$ME: WARNING: no user/group/etc in '$cmd'";
            return;
        };
    warn "$ME: WARNING: command '$cmd' left \@ARGV with '@ARGV'" if @ARGV;

    # Invoke the specific checker for useradd or groupadd
    {
        no strict 'refs';       ## no critic 'ProhibitNoStrict'
        my $validator = "_check_${add_command}";
        $validator->( $spec, \%options, $arg );
    }
}

####################
#  _check_useradd  #  Checker for 'useradd' command
####################
sub _check_useradd {
    my $spec     = shift;
    my $options  = shift;
    my $username = shift;

    #
    # Home Directory : required
    #
    if (my $homedir = $options->{'home-dir'}) {
        # FIXME: is there anything to check here?
    }
    else {
        # Home directory missing.
        $spec->gripe({
            code => 'UseraddNoHomedir',
            diag => "Invocation of <tt>useradd</tt> without a home dir",
        });
    }

    #
    # Login shell
    #
    if (my $shell = $options->{shell}) {
        if ($shell ne '/sbin/nologin') {
            $spec->gripe({
                code => 'UseraddBadShell',
                diag => "Invocation of <tt>useradd</tt> with unexpected login shell <var>$shell</var> (expected <tt>/sbin/nologin</tt>)",
            });
        }
    }
    else {
        # No login shell
        $spec->gripe({
            code => 'UseraddNoShell',
            diag => "Invocation of <tt>useradd</tt> without a login shell",
        });
    }

    #
    # Userid
    #
    my $expected_uid = $UidGid{$username}{UID};

    if (my $uid = $options->{uid}) {
        if ($uid =~ /^\d+$/) {
            # Numeric. Cross-check against expectations
            if (defined $expected_uid) {
                if ($uid != $expected_uid) {
                    $spec->gripe({
                        code => 'UseraddWrongUid',
                        diag => "Invocation of <tt>useradd</tt> with incorrect UID <var>$uid</var>; $UidGid_File defines the UID for $username as <b>$expected_uid</b>"
                    });
                }
                else {
                    dprintf "Woot. UID match for $username\n";
                }
            }
            else {
                # FIXME: this may be serious, because it could collide
                # with a UID assigned later
                $spec->gripe({
                    code => 'UseraddUnknownUid',
                    diag => "Invocation of <tt>useradd</tt> with UID <var>$uid</var>, but there's no assigned UID for <var>$username</var> in $UidGid_File",
                });
            }
        }
        else {
            # UID is not a number; eg '-u '%{some_macro}'.
            # We can't reliably check. Maybe we could run rpm -q --specfile
            # and somehow extract the macro value ... but that's fragile.
            # Even worse: what if the macro is conditional? (rhel5/rhel6).
            # So ask the user to deal with it.
            my $diag = "Invocation of <tt>useradd</tt> with non-numeric UID <var>$uid</var>";

            if (defined $expected_uid) {
                $diag .= "; please verify that this =<b>$expected_uid</b>, as defined in $UidGid_File";
            }
            else {
                $diag .= "; this is probably OK, but I have no robust way of checking. Note that there is no UID defined for <var>$username</var> in $UidGid_File";
            }

            $spec->gripe({
                code => 'UseraddCheckUid',
                diag => $diag,
            });
        }
    }
    else {
        # No UID given at all.
        my $diag = "Invocation of <tt>useradd</tt> without specifying a UID";
        if (defined $expected_uid) {
            $diag .= "; $UidGid_File defines the UID for $username as <b>$expected_uid</b>";
        }
        else {
            $diag .= "; this may be OK, because $UidGid_File defines no UID for <var>$username</var>";
        }

        $spec->gripe({
            code => 'UseraddNoUid',
            diag => $diag,
        });
    }
}

#####################
#  _check_groupadd  #  Checker for 'groupadd' command
#####################
sub _check_groupadd {
    my $spec      = shift;
    my $options   = shift;
    my $groupname = shift;

    if (defined (my $expected_gid = $UidGid{$groupname}{GID})) {
        if (defined (my $actual_gid = $options->{gid})) {
            if ($actual_gid =~ /^\d+$/) {
                if ($actual_gid != $expected_gid) {
                    # Mismatch: invocation with wrong GID
                    $spec->gripe({
                        code => 'GroupaddWrongGid',
                        diag => "Invocation of <tt>groupadd</tt> with incorrect GID <var>$actual_gid</var>; $UidGid_File defines the GID for $groupname as <b>$expected_gid</b>",
                    });
                }
            }
            else {
                # Non-numeric GID
                $spec->gripe({
                    code => 'GroupaddCheckGid',
                    diag => "Invocation of <tt>groupadd</tt> with non-numeric GID <var>$actual_gid</var>; please make sure that this =<b>$expected_gid</b>, as defined in $UidGid_File",
                });
            }
        }
        else {
        }
    }
}

1;

###############################################################################
#
# Documentation
#

=head1	NAME

FIXME - FIXME

=head1	SYNOPSIS

    use Fixme::FIXME;

    ....

=head1	DESCRIPTION

FIXME fixme fixme fixme

=head1	CONSTRUCTOR

FIXME-only if OO

=over 4

=item B<new>( FIXME-args )

FIXME FIXME describe constructor

=back

=head1	METHODS

FIXME document methods

=over 4

=item	B<method1>

...

=item	B<method2>

...

=back


=head1	EXPORTED FUNCTIONS

=head1	EXPORTED CONSTANTS

=head1	EXPORTABLE FUNCTIONS

=head1	FILES

=head1	SEE ALSO

L<>

=head1	AUTHOR

Ed Santiago <santiago@redhat.com>

=cut
