package FOSSCloud::Installer::Steps::UnpackStage4Tarball;

use FOSSCloud::Installer::Config;
use Modern::Perl;
use IPC::Run qw(run);
use File::Path qw(make_path);
use File::Spec;
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
    my $tarfile = C('system.stage4_tarball');

    # Expand from installer root unless file_name_is_absolutee
    $tarfile = File::Spec->catfile($params->{installer_root}, $tarfile)
    unless(File::Spec->file_name_is_absolute($tarfile));

    make_path($root);

    die "Unable to create working directory to $root"
    unless -d $root;

    say "Unpacking Stage4 tarfile ... Please stand by.";

    die "Unable to unpack stage4 tarball"
    unless system("tar -xjpf $tarfile -C $root") == 0;

    # info "Unpacking of stage4 tarball was successful"
}


1;