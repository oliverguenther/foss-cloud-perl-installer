package FOSSCloud::Installer::Steps::FinishMessage;

use FOSSCloud::Installer::Config;
use Modern::Perl;
use IPC::Run qw(run);
use feature 'switch';
use utf8;

sub new {
    # header "Installation Complete"

    # info "Congratulation! You have finished the installation of ${osbdProjectName}"
    # info "Now all you need to do is reboot the system and remove the CD-ROM"
    # info ""
}

1;