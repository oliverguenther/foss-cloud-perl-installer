package FOSSCloud::Installer::Steps::FstabCreation;

use FOSSCloud::Installer::Config;
use Modern::Perl;
use File::Path qw(make_path);
use File::Basename;
use File::Spec;
use utf8;

=head1 FOSSCloud::Installer::Steps::FstabCreation

Print node type to system.

=cut
sub new {
	my ($class, $params) = @_;

	my $self = {};
	bless $self, $class;

    my $fstab = File::Spec->catfile(C('system.root'), '/etc/fstab');

    make_path(dirname($fstab), { mode => 0644 });

    open(my $file, '>', $fstab)
    or die "Cannot open fstab file '$fstab'";

    # Header
    print $file <DATA>;

    my $fs_table = C('system.volumes');
    for my $label (keys %$fs_table) {
        my $fs = $fs_table->{$label};
        my $fs_label = C('defaults.label_prefix') . "$label";

        next unless ($fs->{type} eq 'xfs');

        say "Adding $fs_label (mountpoint $$fs{mountpoint}) to fstab";

        my $fs_opts = join(',', @{$fs->{opts}});
        print $file "LABEL=$fs_label\t$$fs{mountpoint}\txfs\t$fs_opts\t$$fs{dump} $$fs{pass}\n";
    }

    print $file "/dev/cdrom\t/mnt/cdrom\tauto\tnoauto,ro\t0 0\n";
    print $file "shm\t/dev/shm\ttmpfs\tnodev,nosuid,noexec\t0 0\n";
    
    close($file);

#     if [ ${osbdNodeType} -eq ${osbdNodeTypeDemoSystem} -o \
#          ${osbdNodeType} -eq ${osbdNodeTypeSingleServer} ]
#     then
#         debug "Creating fstab entry: /var/virtualization"

#         cat << EOF >> "${fstabPath}"
# LABEL=OSBD_virtual  /var/virtualization   xfs      noatime,nodev,nosuid         0 2
# EOF
#     fi


#     if [ ${osbdNodeType} -eq ${osbdNodeTypeStorageNode} ]; then
#         debug "Creating fstab entry: /var/data/gluster-volume-01"

#         cat << EOF >> "${fstabPath}"
# LABEL=OSBD_gfs-01     /var/data/gluster-volume-01  xfs      noatime,nodev,nosuid,rw      0 2
# EOF
#     fi


}

1;
__DATA__
# /etc/fstab: static file system information.
#
# noatime turns off atimes for increased performance (atimes normally aren't
# needed; notail increases performance of ReiserFS (at the expense of storage
# efficiency).  It's safe to drop the noatime options if you want and to
# switch between notail / tail freely.
#
# The root filesystem should have a pass number of either 0 or 1.
# All other filesystems should have a pass number of 0 or greater than 1.
#
# See the manpage fstab(5) for more information.
#

# <fs>                  <mountpoint>        <type>    <opts>              <dump/pass>
# NOTE: If your BOOT partition is ReiserFS, add the notail option to opts.
