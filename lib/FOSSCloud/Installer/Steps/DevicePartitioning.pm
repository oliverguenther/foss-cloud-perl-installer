package FOSSCloud::Installer::Steps::DevicePartitioning;

use FOSSCloud::Installer::Config;
use Modern::Perl;
use IPC::Run qw(run);
use feature 'switch';
use utf8;

=head1 FOSSCloud::Installer::Steps::DevicePartitioning

Creates partitions on target and data device with parted.

=cut
sub new {
	my ($class, $params) = @_;

	my $self = {};
	bless $self, $class;

	my $installpath = '/dev/' . C('system.target_device');

    # Rescan partitions
    system("partprobe 2>&1 $installpath");

    # my $commands = do { local $/; <DATA> };
    for my $command (<DATA>) {
	    chomp $command;
	    say "debug: running '$command'";
        die 'Unable to create the new partition layout'
	    unless system("parted --align=opt -- $installpath $command") == 0;
	}
}


1;

__DATA__
mklabel msdos
mkpart primary 1MiB 64MiB
mkpart primary linux-swap 64MiB 4160MiB
mkpart primary 4160MiB 8256MiB
mkpart extended 8256MiB -1
mkpart logical 8257MiB -1
set 1 boot on
set 5 LVM on