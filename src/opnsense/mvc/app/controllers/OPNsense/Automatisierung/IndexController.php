<?php

namespace OPNsense\Automatisierung;

class IndexController extends \OPNsense\Base\IndexController
{
    public function indexAction()
    {
        $this->view->title = gettext('Konfiguration');
        $this->view->pick('OPNsense/Automatisierung/config');
    }

    public function statusAction()
    {
        $this->view->title = gettext('Status & Updates');
        $this->view->pick('OPNsense/Automatisierung/status');
    }

    public function backupAction()
    {
        $this->view->title = gettext('Konfigurationsbackup');
        $this->view->pick('OPNsense/Automatisierung/backup');
    }
}
