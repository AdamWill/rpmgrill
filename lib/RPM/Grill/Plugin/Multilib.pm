# -*- perl -*-
#
# RPM::Grill::Plugin::Multilib - check for multilib conflicts
#
# $Id$
#
# Real-world packages that trigger errors in this module:
# See t/RPM::Grill/Plugin/90real-world.t
#
package RPM::Grill::Plugin::Multilib;

use base qw(RPM::Grill);

use strict;
use warnings;
our $VERSION = '0.01';

use Carp;
use RPM::Grill::Util		qw(sanitize_text);

###############################################################################
# BEGIN user-configurable section

# Order in which this plugin runs.  Set to a unique number [0 .. 99]
sub order {20}    # FIXME

# One-line description of this plugin
sub blurb { return "reports multilib conflicts" }

sub doc {
    return <<"END_DOC" }
This module tests for multilib incompatibilities, i.e. conflicts that
will prevent 32- and 64-bit versions of a package from being installed
together.

This may not be important for your package. Perhaps your package will
never be installed multilib. There is no mechanism for determining
that.
END_DOC

# END   user-configurable section
###############################################################################

# Program name of our caller
( our $ME = $0 ) =~ s|.*/||;

#
# input: a RPM::Grill object, blessed into this package.
# return value: not checked.
#
# Calls $self->gripe() with problems.  Return value is meaningless,
# but code can die/croak if necessary -- it will be trapped in an eval.
#
sub analyze {
    my $self = shift;

    # Main loop: iterate over all 64-bit RPMs
  RPM64:
    for my $rpm64 (grep { $_->is_64bit } $self->rpms ) {
        # Never check -debuginfo or kernel-headers packages
        next RPM64      if $rpm64->subpackage =~ /-debuginfo/
                        || $rpm64->subpackage =~ /^kernel-(.*-)?headers/;

        my @files64 = $rpm64->files;

        # Optimization: cache those files into a hash keyed on path.
        # On a large package such as conga-0.12.2-63.el5 (20,000+ files)
        # this reduces the inner loop time from 3 hours to ~few seconds.
        my %by_path;
        for my $f (@files64) {
            push @{ $by_path{ $f->path } }, $f;
        }

        # Secondary loop: iterate over all 32-bit peers of our 64-bit rpm
        for my $rpm32 ($rpm64->multilib_peers) {
            my @files32 = $rpm32->files;

            # Tertiary loop: for each 32-bit file that has a match (same path)
            # in the 64-bit rpm, see if there's a multilib conflict.
            for my $file32 (@files32) {
                if (my $files64 = $by_path{ $file32->path }) {
                    $self->_compare( $_, $file32 )          for @$files64;
                }
            }
        }
    }

    # Done. If we found multilib conflicts in which files are missing "color",
    # check the specfile for common causes for this.
    if ($self->{_plugin_state}{found_conflict_nocolor}) {
        $self->_check_spec_for_filters();
    }
}


sub _compare {
    my $self   = shift;
    my $file64 = shift;
    my $file32 = shift;

    return if $file32->md5sum eq $file64->md5sum;

    # md5sums differ. This means the files are different.
    # If both files have a different "rpm color", that's OK.
    if ($file64->has_color && $file32->has_color) {
        if (($file64->color & $file32->color) == 0) {
            return;
        }
    }
    else {
        # Eeek! One or both files have no RPM color. Flag that.
        $self->{_plugin_state}{found_conflict_nocolor}++;
    }

    # Files have the same (or no) rpm color. Gripe.
    my $path = $file64->path;

    my $arch64 = $file64->arch;
    my $arch32 = $file32->arch;

    $self->gripe({
        code => 'MultilibMismatch',
        diag => "Files differ: {$arch32,$arch64}$path",
        arch => $arch64,
    });
}


#############################
#  _check_spec_for_filters  #  Look for %filter_setup etc
#############################
#
# Multilib errors can be the result of %filter_setup or other ways in which
# rpm's internal dependency generator is disabled.
#
sub _check_spec_for_filters {
    my $self = shift;

    my $spec = $self->specfile;
    (my $specfile_basename = $spec->path) =~ s|^.*/||;

    for my $line ($spec->lines) {
        my $s = $line->content;

        if ($s =~ /(%filter_|_dependency_generator)/) {
            $self->gripe({
                code => 'DepGenDisabled',
                diag => "Multilib errors may be due to the dependency generator being disabled",
                context => {
                    path    => $specfile_basename,
                    lineno  => $line->lineno,
                    excerpt => sanitize_text($s)
                },
            });

            # No need to gripe for every match, e.g. multiple %filter_setup
            # lines in wkhtmltopdf-0.10.0_rc2-6.el6eng
            return;
        }
    }

    # Didn't find a matching line in the specfile.
    # FIXME: should we gripe anyway?
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

=head1  DIAGNOSTICS

=over 4

=item   MultilibMismatch

The 64- and 32-bit versions of FILE differ. This means that yum/rpm
will refuse to install both versions at once. Please don't blame
rpmgrill for this: we're just reporting a potential problem. If this
package will never ever ever be installed multilib, you can ignore
this warning.

=item   DepGenDisabled

Build has multilib errors which may be caused by having turned off
RPM's internal dependency generator. This is horrendously complicated,
but try starting here:
http://fedoraproject.org/wiki/Packaging:AutoProvidesAndRequiresFiltering#Usage

=back

=head1	SEE ALSO

L<>

=head1	AUTHOR

Ed Santiago <santiago@redhat.com>

=cut
