package FOSSCloud::Installer::Common::LVM;

use utf8;

=head1 FOSSCloud::Installer::Common::LVM

=cut
sub update_filter_string {
    my ($filter) = @_;

    my $sedstr = 's:^  filter =.*$:   filter = [ \"a|'.$filter.'|\", \"r/.*/\" ]:g';
    
    die "Cannot update LVM filter to '$filter' in '/etc/lvm/lvm.conf'"
    unless system("sed -i -e \"$sedstr\" /etc/lvm/lvm.conf") == 0;
}

1;
