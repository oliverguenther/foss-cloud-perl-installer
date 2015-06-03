package FOSSCloud::Installer::Steps::UnpackStage4Tarball;

use FOSSCloud::Installer::Config;
use Modern::Perl;
use IPC::Run qw(run);
use File::Path qw(make_path);
use feature 'switch';
use utf8;

=head1 FOSSCloud::Installer::Steps::UnpackStage4Tarball

Unpack FOSS stage 4 package.

=cut
sub new {
	my ($class, $params) = @_;

	my $self = {};
	bless $self, $class;

    # info "Unpacking stage4 tarball"
    # info "This will take a while - please be patient"

    my $root = C('system.root');
    my $tarfile = File::Spec->catfile($params->{installer_root}, C('defaults.stage4_tarball'));

    make_path($root);

    die "Unable to change working directory to $root"
    unless chdir $root;

    say "Unpacking Stage4 tarfile ... Please stand by.";

    die "Unable to unpack stage4 tarball"
    unless system("tar -xjpf $tarfile") == 0;

    # info "Unpacking of stage4 tarball was successful"
}


1;