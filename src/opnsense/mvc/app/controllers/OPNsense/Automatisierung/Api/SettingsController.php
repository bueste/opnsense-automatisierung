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
use OPNsense\Core\Backend;
use OPNsense\Automatisierung\Logger;

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

            // Only allow https:// and http:// schemes to prevent file://, gopher:// SSRF
            if (!preg_match('/^https?:\/\/.+/', $url)) {
                $result['message'] = 'URL muss mit https:// oder http:// beginnen.';
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

    /**
     * Get notification settings
     */
    public function getNotificationsAction()
    {
        $g = $this->getModel()->general;
        return ['notify' => [
            'enabled'           => (string)$g->notify_enabled,
            'telegram_enabled'  => (string)$g->notify_telegram_enabled,
            'telegram_token'    => (string)$g->notify_telegram_token,
            'telegram_chatid'   => (string)$g->notify_telegram_chatid,
            'pushover_enabled'  => (string)$g->notify_pushover_enabled,
            'pushover_token'    => (string)$g->notify_pushover_token,
            'pushover_user'     => (string)$g->notify_pushover_user,
            'matrix_enabled'    => (string)$g->notify_matrix_enabled,
            'matrix_homeserver' => (string)$g->notify_matrix_homeserver,
            'matrix_token'      => (string)$g->notify_matrix_token,
            'matrix_room'       => (string)$g->notify_matrix_room,
        ]];
    }

    /**
     * Save notification settings
     */
    public function setNotificationsAction()
    {
        $result = ['result' => 'failed'];
        if (!$this->request->isPost()) {
            $result['message'] = 'POST required';
            return $result;
        }
        $data = $this->request->getPost('notify');
        if (!is_array($data)) {
            $result['message'] = 'Keine Daten übermittelt';
            return $result;
        }
        $g = $this->getModel()->general;
        $map = [
            'enabled'           => 'notify_enabled',
            'telegram_enabled'  => 'notify_telegram_enabled',
            'telegram_token'    => 'notify_telegram_token',
            'telegram_chatid'   => 'notify_telegram_chatid',
            'pushover_enabled'  => 'notify_pushover_enabled',
            'pushover_token'    => 'notify_pushover_token',
            'pushover_user'     => 'notify_pushover_user',
            'matrix_enabled'    => 'notify_matrix_enabled',
            'matrix_homeserver' => 'notify_matrix_homeserver',
            'matrix_token'      => 'notify_matrix_token',
            'matrix_room'       => 'notify_matrix_room',
        ];
        foreach ($map as $key => $field) {
            if ($g->$field !== null) {
                $g->$field->setValue(isset($data[$key]) ? $data[$key] : '');
            }
        }
        $validation = $this->getModel()->performValidation();
        if ($validation->count() === 0) {
            $this->getModel()->serializeToConfig();
            Config::getInstance()->save();
            Logger::info('notify', 'Benachrichtigungs-Einstellungen gespeichert.');
            $result['result'] = 'saved';
        } else {
            $result['validations'] = [];
            foreach ($validation as $msg) {
                $result['validations'][$msg->getField()] = $msg->getMessage();
            }
        }
        return $result;
    }

    /**
     * Send a test notification through all enabled channels (uses saved settings).
     */
    public function testNotificationAction()
    {
        $result = ['result' => 'failed', 'message' => ''];
        if (!$this->request->isPost()) {
            $result['message'] = 'POST required';
            return $result;
        }
        try {
            $backend = new Backend();
            $raw = trim($backend->configdRun('automatisierung notify-test'));
            $channels = json_decode($raw, true);
            Logger::info('notify', 'Testbenachrichtigung ausgelöst: ' . $raw);
            if (!is_array($channels) || count($channels) === 0) {
                $result['result']  = 'ok';
                $result['message'] = 'Kein Kanal aktiv/vollständig konfiguriert – nichts gesendet. '
                    . 'Bitte zuerst speichern und einen Kanal aktivieren.';
                return $result;
            }
            $okCh = array_keys(array_filter($channels));
            $failCh = array_keys(array_filter($channels, function ($v) { return !$v; }));
            $result['result']   = empty($failCh) ? 'ok' : 'partial';
            $result['channels'] = $channels;
            $msg = [];
            if ($okCh)   $msg[] = 'OK: ' . implode(', ', $okCh);
            if ($failCh) $msg[] = 'Fehlgeschlagen: ' . implode(', ', $failCh);
            $result['message'] = implode(' | ', $msg);
        } catch (\Exception $e) {
            $result['message'] = 'Testversand fehlgeschlagen: ' . $e->getMessage();
            Logger::error('notify', $result['message']);
        }
        return $result;
    }

    /**
     * Get self-healing settings
     */
    public function getHealingAction()
    {
        $g = $this->getModel()->general;
        return ['healing' => [
            'check_interval'  => (string)$g->heal_check_interval,
            'ram_enabled'     => (string)$g->heal_ram_enabled,
            'ram_threshold'   => (string)$g->heal_ram_threshold,
            'disk_enabled'    => (string)$g->heal_disk_enabled,
            'disk_threshold'  => (string)$g->heal_disk_threshold,
            'ifreset_enabled' => (string)$g->heal_ifreset_enabled,
            'ifreset_target'  => (string)$g->heal_ifreset_target,
        ]];
    }

    /**
     * Save self-healing settings
     */
    public function setHealingAction()
    {
        $result = ['result' => 'failed'];
        if (!$this->request->isPost()) {
            $result['message'] = 'POST required';
            return $result;
        }
        $data = $this->request->getPost('healing');
        if (!is_array($data)) {
            $result['message'] = 'Keine Daten übermittelt';
            return $result;
        }
        $g = $this->getModel()->general;
        $map = [
            'check_interval'  => 'heal_check_interval',
            'ram_enabled'     => 'heal_ram_enabled',
            'ram_threshold'   => 'heal_ram_threshold',
            'disk_enabled'    => 'heal_disk_enabled',
            'disk_threshold'  => 'heal_disk_threshold',
            'ifreset_enabled' => 'heal_ifreset_enabled',
            'ifreset_target'  => 'heal_ifreset_target',
        ];
        foreach ($map as $key => $field) {
            if ($g->$field !== null && isset($data[$key])) {
                $g->$field->setValue($data[$key]);
            }
        }
        $validation = $this->getModel()->performValidation();
        if ($validation->count() === 0) {
            $this->getModel()->serializeToConfig();
            Config::getInstance()->save();
            Logger::info('selfheal', 'Self-Healing-Einstellungen gespeichert.');
            $result['result'] = 'saved';
        } else {
            $result['validations'] = [];
            foreach ($validation as $msg) {
                $result['validations'][$msg->getField()] = $msg->getMessage();
            }
        }
        return $result;
    }

    /**
     * Run the self-healing checks now (manual trigger).
     */
    public function runHealingAction()
    {
        $result = ['result' => 'failed', 'message' => ''];
        if (!$this->request->isPost()) {
            $result['message'] = 'POST required';
            return $result;
        }
        try {
            $backend = new Backend();
            $out = trim($backend->configdRun('automatisierung self-healing'));
            Logger::info('selfheal', 'Self-Healing manuell ausgelöst.');
            $result['result']  = 'ok';
            $result['message'] = 'Self-Healing-Lauf ausgelöst. Details im Log-Tab (Quelle: Self-Healing).';
            $result['output']  = $out;
        } catch (\Exception $e) {
            $result['message'] = 'Lauf fehlgeschlagen: ' . $e->getMessage();
            Logger::error('selfheal', $result['message']);
        }
        return $result;
    }
}
