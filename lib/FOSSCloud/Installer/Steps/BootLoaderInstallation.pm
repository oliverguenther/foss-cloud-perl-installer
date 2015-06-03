package FOSSCloud::Installer::Steps::BootLoaderInstallation;

use FOSSCloud::Installer::Config;
use Modern::Perl;
use File::Path qw(make_path);
use File::Basename;
use File::Spec;
use String::Util 'trim';
use utf8;

=head1 FOSSCloud::Installer::Steps::BootLoaderInstallation

Installs grub.

=cut
sub new {
	my ($class, $params) = @_;

	my $self = {};
	bless $self, $class;

    say "== Boot Loader Installation ==";

    $self->{boot_partition} = $self->detect_partition;
    $self->{setup_partition} = C('system.grub.setup_partition'); # (hd0)
    
    say "[debug] Grub boot partition name: $$self{boot_partition}";

    say "Installing grub into master boot record";
    $self->setup_grub;

    # info "Boot loader installation was successful"
}

sub detect_partition {
	my ($self) = @_;

	my $magic = C('system.grub.partition_magic_file');

    my $partition = `echo "find $magic" | \
        grub --batch --no-floppy 2>/dev/null | \
		grep -E '^ \(hd[0-9],[0-9]\)\$'`;


   	die "Unable to detect the grub boot partition name"
   	unless defined $partition;

    return trim($partition);
}

sub setup_grub {
	my ($self) = @_;

    my $code = system(qq(echo -e "root $$self{boot_partition}}\nsetup $$self{setup_partition}\nquit" | \
        grub --batch 2>&1 | grep --color=never "Error"));

    die "Unable to install grub into MBR"
    if $code == 0; # If grep matches error, returns 0

	my $grub_config = File::Spec->catfile(C('system.root'), '/boot/grub/grub.conf');
    $code = system(qq(sed -i -e "s:(hd[0-9],[0-9]):$$self{boot_partition}:" $grub_config));

	die "Unable to change the grub root partition in the grub config"
	unless $code == 0;

}

1;