<?php
/*
 * Copyright (C) 2024 Automatisierung Plugin Contributors
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 * OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
/**
 * Automatisierung Settings API Controller
 * Handles CRUD for host configurations
 */

namespace OPNsense\Automatisierung\Api;

use OPNsense\Base\ApiMutableModelControllerBase;
use OPNsense\Core\Config;

class SettingsController extends ApiMutableModelControllerBase
{
    protected static $internalModelClass = '\OPNsense\Automatisierung\Automatisierung';
    protected static $internalModelName = 'automatisierung';

    /**
     * Search hosts
     */
    public function searchHostsAction()
    {
        return $this->searchBase('hosts.host', ['enabled', 'name', 'url', 'api_key',
            'auto_update_opnsense', 'auto_update_za', 'za_watchdog', 'skip_verify_tls']);
    }

    /**
     * Get single host
     */
    public function getHostAction($uuid = null)
    {
        return $this->getBase('host', 'hosts.host', $uuid);
    }

    /**
     * Add host
     */
    public function addHostAction()
    {
        return $this->addBase('host', 'hosts.host');
    }

    /**
     * Update host
     */
    public function setHostAction($uuid = null)
    {
        return $this->setBase('host', 'hosts.host', $uuid);
    }

    /**
     * Delete host
     */
    public function delHostAction($uuid)
    {
        return $this->delBase('hosts.host', $uuid);
    }

    /**
     * Toggle host enabled/disabled
     */
    public function toggleHostAction($uuid)
    {
        return $this->toggleBase('hosts.host', $uuid);
    }

    /**
     * Get general settings
     */
    public function getGeneralAction()
    {
        $mdl = $this->getModel();
        return [
            'general' => [
                'update_hour'         => (string)$mdl->general->update_hour,
                'update_minute'       => (string)$mdl->general->update_minute,
                'update_days'         => (string)$mdl->general->update_days,
                'za_check_interval'   => (string)$mdl->general->za_check_interval,
                'auto_update_enabled' => (string)$mdl->general->auto_update_enabled,
                'za_watchdog_enabled' => (string)$mdl->general->za_watchdog_enabled,
            ]
        ];
    }

    /**
     * Save general settings
     */
    public function setGeneralAction()
    {
        $result = ['result' => 'failed'];
        if ($this->request->isPost()) {
            $mdl = $this->getModel();
            $data = $this->request->getPost('general');
            if (is_array($data)) {
                $mdl->general->update_hour->setValue(isset($data['update_hour']) ? $data['update_hour'] : '3');
                $mdl->general->update_minute->setValue(isset($data['update_minute']) ? $data['update_minute'] : '0');
                $mdl->general->update_days->setValue(isset($data['update_days']) ? $data['update_days'] : '*');
                $mdl->general->za_check_interval->setValue(!empty($data['za_check_interval']) ? $data['za_check_interval'] : '15');
                $mdl->general->auto_update_enabled->setValue(isset($data['auto_update_enabled']) ? $data['auto_update_enabled'] : '0');
                $mdl->general->za_watchdog_enabled->setValue(isset($data['za_watchdog_enabled']) ? $data['za_watchdog_enabled'] : '0');
                $validation = $mdl->performValidation();
                if ($validation->count() === 0) {
                    $mdl->serializeToConfig();
                    Config::getInstance()->save();
                    $result['result'] = 'saved';
                } else {
                    $result['validations'] = [];
                    foreach ($validation as $msg) {
                        $result['validations'][$msg->getField()] = $msg->getMessage();
                    }
                }
            }
        }
        return $result;
    }

    /**
     * Test connection to a host
     */
    public function testConnectionAction()
    {
        $result = ['result' => 'failed', 'message' => ''];
        if ($this->request->isPost()) {
            $url    = trim($this->request->getPost('url', 'string', ''));
            $key    = trim($this->request->getPost('api_key', 'string', ''));
            $secret = trim($this->request->getPost('api_secret', 'string', ''));
            $skipVerify = (bool)$this->request->getPost('skip_verify_tls', 'string', '0');

            if (empty($url) || empty($key) || empty($secret)) {
                $result['message'] = 'URL, API Key und Secret sind erforderlich.';
                return $result;
            }

            $url = rtrim($url, '/');
            $ch = curl_init($url . '/api/core/firmware/info');
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_USERPWD, $key . ':' . $secret);
            curl_setopt($ch, CURLOPT_TIMEOUT, 10);
            curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, !$skipVerify);
            curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, $skipVerify ? 0 : 2);
            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            $curlError = curl_error($ch);
            curl_close($ch);

            if ($curlError) {
                $result['message'] = 'Verbindungsfehler: ' . $curlError;
            } elseif ($httpCode === 200) {
                $data = json_decode($response, true);
                $result['result']  = 'ok';
                $result['message'] = 'Verbindung erfolgreich!';
                if (isset($data['product_version'])) {
                    $result['version'] = $data['product_version'];
                }
            } elseif ($httpCode === 401 || $httpCode === 403) {
                $result['message'] = 'Authentifizierung fehlgeschlagen (HTTP ' . $httpCode . '). API Key/Secret prüfen.';
            } else {
                $result['message'] = 'HTTP Fehler: ' . $httpCode;
            }
        }
        return $result;
    }
}
