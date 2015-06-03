package FOSSCloud::Installer::Steps::CheckSelectedDevice;

use FOSSCloud::Installer::Config;
use Modern::Perl;
use IPC::Run qw(run);
use feature 'switch';
use utf8;

=head1 FOSSCloud::Installer::Steps::CheckSelectedDevice

Ensures, that the selected device has enough space.

=cut
sub new {
	my ($class, $params) = @_;

	my $self = {};
	bless $self, $class;

    return if ($params->{'skip-checks'});

    # Install device
    $self->check(C('system.target_device'), 'target device');

    # Optioanl data device
    $self->check(C('system.data_device'), 'data device')
    if (defined C('system')->{data_device});
}

=head2 check

Runs the device checks.

=cut
sub check {
    my ($self, $device, $name) = @_;

    if (!defined $device) {
        die "$name missing from configuration";
    }

    my $available = $self->get_size("/sys/block/$device/size");

    if (!defined $available) {
        die "Cannot read free blocks from $device";
    }

    elsif ($available < C('defaults.requirements.diskspace')) {
        die "You don't have enough memory ($available GB).";
    }

    say "'/dev/$device' will be used as the $name.";

}

=head2 get_size

Returns free space in GB from device.

=cut
sub get_size {
    my ($self, $device_path) = @_;

    die "Device does not exist"
    unless -e $device_path;

    my $out;
    run ['cat', $device_path], \undef, \$out;
    chomp $out;

    return sprintf("%.2f", $out / (2 * 1024 * 1024))
    if ($out);
}

1;