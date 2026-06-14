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
namespace OPNsense\Automatisierung\Api;
use OPNsense\Base\ApiControllerBase;
use OPNsense\Automatisierung\Automatisierung;
use OPNsense\Automatisierung\Logger;
use OPNsense\Core\Backend;

class ServiceController extends ApiControllerBase
{
    private function getModel() { return new Automatisierung(); }

    private function remoteApiCall($url, $key, $secret, $endpoint, $method = 'GET', $postData = null, $skipVerify = false)
    {
        $fullUrl = rtrim($url, '/') . '/api/' . ltrim($endpoint, '/');
        $ch = curl_init($fullUrl);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_USERPWD, trim($key) . ':' . trim($secret));
        curl_setopt($ch, CURLOPT_TIMEOUT, 20);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, !$skipVerify);
        curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, $skipVerify ? 0 : 2);
        if ($method === 'POST') {
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, $postData ? json_encode($postData) : '{}');
            curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
        } elseif ($method === 'PUT') {
            curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'PUT');
            curl_setopt($ch, CURLOPT_POSTFIELDS, $postData ? json_encode($postData) : '{}');
            curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
        }
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curlError = curl_error($ch);
        curl_close($ch);
        if ($curlError) return ['error' => $curlError, 'http_code' => 0];
        return ['data' => json_decode($response, true) ?? [], 'http_code' => $httpCode];
    }

    /**
     * Call zenarmor/status/service (PUT) to start/stop/restart a ZA service.
     * Returns true on success.
     */
    private function zaServiceAction($url, $key, $secret, $sv, $service, $action)
    {
        $r = $this->remoteApiCall($url, $key, $secret, 'zenarmor/status/service', 'PUT',
            ['service' => $service, 'action' => $action], $sv);
        return $r['http_code'] === 200 && isset($r['data']['Status']) && (int)$r['data']['Status'] === 0;
    }

    /**
     * Determine if the Zenarmor engine (eastpect) is running from status response data.
     * eastpect.status is a boolean in the Zenarmor API.
     */
    private function zaIsEngineRunning(array $zd)
    {
        return (bool)($zd['eastpect']['status'] ?? false);
    }

    /**
     * Read the local OPNsense version string.
     */
    private function localOpnVersion()
    {
        // opnsense-version -v returns e.g. "26.1.8_5"
        exec('/usr/local/sbin/opnsense-version -v 2>/dev/null', $out, $rc);
        if ($rc === 0 && !empty($out)) {
            return trim($out[0]);
        }
        // Fallback: read version file
        foreach (['/usr/local/opnsense/version/core', '/usr/local/etc/version'] as $f) {
            if (file_exists($f)) {
                $lines = file($f, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
                if (!empty($lines)) return trim($lines[0]);
            }
        }
        return '?';
    }

    /**
     * Build the status entry for the local firewall (no remote API call needed).
     */
    private function getLocalStatus()
    {
        $mdl = $this->getModel();
        $entry = [
            'uuid'                 => '__local__',
            'name'                 => gethostname() ?: 'Diese Firewall',
            'url'                  => 'localhost',
            'auto_update_opnsense' => (string)$mdl->general->auto_update_enabled,
            'auto_update_za'       => (string)$mdl->general->auto_update_enabled,
            'za_watchdog'          => (string)$mdl->general->za_watchdog_enabled,
            'status'               => 'online',
            'is_local'             => true,
            'opnsense_version'     => $this->localOpnVersion(),
            'opnsense_update'      => 'none',
            'za_installed'         => false,
            'za_version'           => null,
            'za_running'           => null,
            'error'                => null,
        ];

        // Check for local firmware updates (--no-repo-update = fast, uses cached catalogue)
        exec('pkg version --no-repo-update -l "<" 2>/dev/null', $pkgOut, $pkgRc);
        if ($pkgRc === 0 && !empty($pkgOut)) {
            $entry['opnsense_update']       = 'update';
            $entry['opnsense_update_count'] = count($pkgOut);
            foreach ($pkgOut as $line) {
                // ZA is packaged as os-sensei via SunnyValley repo
                if (strpos($line, 'os-sensei') !== false) {
                    $entry['za_update'] = true;
                    exec('pkg rquery -r SunnyValley "%v" os-sensei 2>/dev/null', $zaV);
                    if (!empty($zaV)) $entry['za_new_ver'] = trim($zaV[0]);
                }
            }
        }

        // Zenarmor: installed as os-sensei pkg (SunnyValley repo)
        // Use pkg for version; fall back to directory check
        exec('pkg query "%v" os-sensei 2>/dev/null', $zaVerOut, $zaVerRc);
        if ($zaVerRc === 0 && !empty($zaVerOut)) {
            $entry['za_installed'] = true;
            $entry['za_version']   = trim($zaVerOut[0]);
        } elseif (is_dir('/usr/local/zenarmor')) {
            // Fallback: directory exists but not in pkg db
            $entry['za_installed'] = true;
            $zaVerFile = '/usr/local/zenarmor/db/VERSION';
            if (file_exists($zaVerFile)) {
                $entry['za_version'] = trim(file_get_contents($zaVerFile));
            }
        }

        if ($entry['za_installed']) {
            // Running: pgrep eastpect (works regardless of installation method)
            exec('pgrep eastpect 2>/dev/null', $_pids, $pgrepRc);
            $entry['za_running']       = ($pgrepRc === 0);
            $entry['za_engine_status'] = $entry['za_running'] ? 'running' : 'stopped';
        }

        return $entry;
    }

    /**
     * Restart the local Zenarmor engine.
     * Tries multiple methods: ZA's own start script, pluginctl, service.
     */
    private function localZaRestart()
    {
        // Method 1: ZA's own service script (start|stop|restart)
        $script = '/usr/local/zenarmor/scripts/service.sh';
        if (file_exists($script)) {
            exec('sh ' . escapeshellarg($script) . ' restart 2>&1', $out, $rc);
            if ($rc === 0) return true;
        }
        // Method 2: pluginctl (OPNsense service manager)
        exec('/usr/local/sbin/pluginctl -s eastpect restart 2>&1', $out, $rc);
        if ($rc === 0) return true;
        // Method 3: BSD service
        exec('/usr/sbin/service eastpect restart 2>&1', $out, $rc);
        return $rc === 0;
    }

    public function allStatusAction()
    {
        // Always include the local firewall as the first entry
        $result = [$this->getLocalStatus()];
        $mdl = $this->getModel();
        foreach ($mdl->hosts->host->iterateItems() as $uuid => $host) {
            if ((string)$host->enabled !== '1') continue;
            $url = (string)$host->url;
            $key = (string)$host->api_key;
            $secret = (string)$host->api_secret;
            $skipVerify = (string)$host->skip_verify_tls === '1';
            $entry = [
                'uuid' => $uuid, 'name' => (string)$host->name, 'url' => $url,
                'auto_update_opnsense' => (string)$host->auto_update_opnsense,
                'auto_update_za' => (string)$host->auto_update_za,
                'za_watchdog' => (string)$host->za_watchdog,
                'status' => 'unknown', 'opnsense_version' => null,
                'opnsense_update' => null, 'za_installed' => false,
                'za_version' => null, 'za_running' => null, 'error' => null,
            ];
            $fw = $this->remoteApiCall($url, $key, $secret, 'core/firmware/info', 'GET', null, $skipVerify);
            if (!empty($fw['error']) || $fw['http_code'] !== 200) {
                $entry['status'] = 'error';
                $entry['error'] = $fw['error'] ?? 'HTTP ' . $fw['http_code'];
                $result[] = $entry; continue;
            }
            $entry['status'] = 'online';
            $d = $fw['data'];
            $entry['opnsense_version'] = $d['product_version'] ?? ($d['product']['product_version'] ?? '?');
            $fwSt = $this->remoteApiCall($url, $key, $secret, 'core/firmware/status', 'POST', [], $skipVerify);
            if ($fwSt['http_code'] === 200) {
                $entry['opnsense_update'] = $fwSt['data']['status'] ?? 'none';
                if (!empty($fwSt['data']['updates'])) {
                    $entry['opnsense_update_count'] = count($fwSt['data']['updates']);
                    foreach ($fwSt['data']['updates'] as $pkg) {
                        if (strpos($pkg['name'] ?? '', 'os-sensei') !== false) {
                            $entry['za_update']  = true;
                            $entry['za_new_ver'] = $pkg['version'] ?? '?';
                        }
                    }
                }
            }
            // Zenarmor via zenarmor/status/index (OPNsense 26.x)
            $za = $this->remoteApiCall($url, $key, $secret, 'zenarmor/status/index', 'GET', null, $skipVerify);
            if ($za['http_code'] === 200 && !empty($za['data'])) {
                $entry['za_installed'] = true;
                $zd = $za['data'];
                $av = $zd['agent_version'] ?? '?';
                $entry['za_version']       = is_array($av) ? ($av['version'] ?? '?') : (string)$av;
                // eastpect.status is a boolean in the Zenarmor API
                $entry['za_running']       = (bool)($zd['eastpect']['status'] ?? false);
                $entry['za_engine_status'] = $entry['za_running'] ? 'running' : 'stopped';
                $entry['za_needs_restart'] = !empty($zd['updateInProgress']);
            }
            $result[] = $entry;
        }
        return ['hosts' => $result];
    }

    public function updateOpnsenseAction()
    {
        if (!$this->request->isPost()) return ['result'=>'failed','message'=>'POST required'];
        $uuid = $this->request->getPost('uuid','string','');

        if ($uuid === '__local__') {
            try {
                $backend = new Backend();
                $backend->configdRun('firmware update');
                Logger::info('service', 'Lokales OPNsense-Update gestartet.');
                return ['result'=>'ok','message'=>'Lokales OPNsense-Update gestartet. Die Firewall startet danach neu — Browser-Verbindung wird kurz unterbrochen.'];
            } catch (\Exception $e) {
                Logger::error('service', 'Lokales OPNsense-Update fehlgeschlagen: ' . $e->getMessage());
                return ['result'=>'failed','message'=>'Lokales Update fehlgeschlagen: ' . $e->getMessage()];
            }
        }

        $host = $this->getHostByUuid($uuid);
        if (!$host) return ['result'=>'failed','message'=>'Host nicht gefunden'];
        list($url,$key,$secret,$sv) = $host;
        $r = $this->remoteApiCall($url,$key,$secret,'core/firmware/upgrade','POST',['mode'=>'update'],$sv);
        return $r['http_code']===200 ? ['result'=>'ok','message'=>'Update gestartet.'] : ['result'=>'failed','message'=>'HTTP '.$r['http_code']];
    }

    public function updateZaAction()
    {
        if (!$this->request->isPost()) return ['result'=>'failed','message'=>'POST required'];
        $uuid = $this->request->getPost('uuid','string','');

        if ($uuid === '__local__') {
            try {
                $backend = new Backend();
                $backend->configdRun('firmware install os-sensei');
                Logger::info('service', 'Lokales Zenarmor-Update gestartet.');
                return ['result'=>'ok','message'=>'Lokales Zenarmor-Update gestartet.'];
            } catch (\Exception $e) {
                Logger::error('service', 'Lokales ZA-Update fehlgeschlagen: ' . $e->getMessage());
                return ['result'=>'failed','message'=>'Lokales ZA-Update fehlgeschlagen: ' . $e->getMessage()];
            }
        }

        $host = $this->getHostByUuid($uuid);
        if (!$host) return ['result'=>'failed','message'=>'Host nicht gefunden'];
        list($url,$key,$secret,$sv) = $host;
        $r = $this->remoteApiCall($url,$key,$secret,'core/firmware/install/os-sensei','POST',[],$sv);
        return $r['http_code']===200 ? ['result'=>'ok','message'=>'ZA Update gestartet.'] : ['result'=>'failed','message'=>'HTTP '.$r['http_code']];
    }

    public function restartZaAction()
    {
        if (!$this->request->isPost()) return ['result'=>'failed','message'=>'POST required'];
        $uuid = $this->request->getPost('uuid','string','');

        if ($uuid === '__local__') {
            $ok = $this->localZaRestart();
            Logger::write('service', $ok ? 'info' : 'error',
                'Lokaler ZA-Neustart ' . ($ok ? 'erfolgreich' : 'fehlgeschlagen'));
            return $ok
                ? ['result'=>'ok','message'=>'Lokale ZA Engine neu gestartet.']
                : ['result'=>'failed','message'=>'Lokaler ZA-Neustart fehlgeschlagen. Prüfe ob Interfaces in Zenarmor konfiguriert sind.'];
        }

        $host = $this->getHostByUuid($uuid);
        if (!$host) return ['result'=>'failed','message'=>'Host nicht gefunden'];
        list($url,$key,$secret,$sv) = $host;
        $ok = $this->zaServiceAction($url, $key, $secret, $sv, 'eastpect', 'restart');
        Logger::write('service', $ok ? 'info' : 'error',
            'ZA-Neustart auf ' . $url . ' ' . ($ok ? 'angestossen' : 'fehlgeschlagen'));
        if ($ok) {
            return ['result'=>'ok','message'=>'ZA Engine Neustart angestossen.'];
        }
        return ['result'=>'failed','message'=>'ZA Engine Neustart fehlgeschlagen. Prüfe ob Interfaces in Zenarmor konfiguriert sind.'];
    }

    public function zaWatchdogCheckAction()
    {
        if (!$this->request->isPost()) return ['result'=>'failed'];
        $uuid = $this->request->getPost('uuid','string','');

        if ($uuid === '__local__') {
            $actions = [];
            // Zenarmor ships as the os-sensei package; fall back to the install dir.
            exec('pkg info -e os-sensei 2>/dev/null', $_d, $instRc);
            if ($instRc !== 0 && !is_dir('/usr/local/zenarmor') && !is_dir('/usr/local/sensei')) {
                return ['result'=>'ok','actions'=>['Zenarmor nicht installiert — kein Eingriff nötig.']];
            }
            exec('pgrep -x eastpect 2>/dev/null', $_d2, $pgrepRc);
            $running = ($pgrepRc === 0);
            if (!$running) {
                $actions[] = 'Lokale ZA Engine nicht aktiv — starte...';
                exec('pluginctl -s eastpect start 2>&1', $_d3, $rc);
                if ($rc !== 0) exec('service eastpect start 2>&1', $_d4, $rc);
                $actions[] = $rc === 0 ? 'Engine gestartet.' : 'Start fehlgeschlagen.';
            } else {
                $actions[] = 'Lokale ZA Engine läuft — kein Eingriff nötig.';
            }
            return ['result'=>'ok','actions'=>$actions];
        }

        $host = $this->getHostByUuid($uuid);
        if (!$host) return ['result'=>'failed','message'=>'Host nicht gefunden'];
        list($url,$key,$secret,$sv) = $host;

        $za = $this->remoteApiCall($url, $key, $secret, 'zenarmor/status/index', 'GET', null, $sv);
        if ($za['http_code'] !== 200) {
            return ['result'=>'ok','actions'=>['Status nicht abrufbar (HTTP ' . $za['http_code'] . ').']];
        }

        $zd = $za['data'];
        $running       = $this->zaIsEngineRunning($zd);
        $needsRestart  = !empty($zd['updateInProgress']);
        $actions = [];

        if (!$running) {
            $actions[] = 'ZA Engine nicht aktiv — starte...';
            $ok = $this->zaServiceAction($url, $key, $secret, $sv, 'eastpect', 'start');
            $actions[] = $ok ? 'Engine gestartet.' : 'Start fehlgeschlagen — prüfe ob Interfaces in Zenarmor konfiguriert sind.';
        } elseif ($needsRestart) {
            $actions[] = 'Engine läuft, Update ausstehend — starte neu...';
            $ok = $this->zaServiceAction($url, $key, $secret, $sv, 'eastpect', 'restart');
            $actions[] = $ok ? 'Engine neugestartet.' : 'Neustart fehlgeschlagen.';
        } else {
            $actions[] = 'ZA Engine läuft — kein Eingriff nötig.';
        }
        return ['result'=>'ok','actions'=>$actions];
    }

    private function getHostByUuid($uuid)
    {
        if (empty($uuid)) return null;
        foreach ($this->getModel()->hosts->host->iterateItems() as $huuid => $host) {
            if ($huuid===$uuid && (string)$host->enabled==='1')
                return [(string)$host->url,(string)$host->api_key,(string)$host->api_secret,(string)$host->skip_verify_tls==='1'];
        }
        return null;
    }
}
