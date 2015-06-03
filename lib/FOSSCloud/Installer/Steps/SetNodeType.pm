package FOSSCloud::Installer::Steps::SetNodeType;

use FOSSCloud::Installer::Config;
use Modern::Perl;
use File::Path qw(make_path);
use File::Basename;
use File::Spec;
use utf8;

=head1 FOSSCloud::Installer::Steps::SetNodeType

Print node type to system.

=cut
sub new {
	my ($class, $params) = @_;

	my $self = {};
	bless $self, $class;

    my $root = C('system.root');
    my $nodetype = C('system.nodetype');

    my $target_file = File::Spec->catfile($root, 'etc/foss-cloud/foss-cloud_node-type');
    make_path(basename($target_file));

    open(my $file, '>', $target_file)
    or die "Cannot open node type file '$target_file'";

    print $file $nodetype;

    close($file);
}


1;