<?php
namespace OPNsense\Automatisierung\Api;
use OPNsense\Base\ApiControllerBase;
use OPNsense\Automatisierung\Automatisierung;

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
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 0);
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

    public function allStatusAction()
    {
        $result = [];
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
                        if (strpos($pkg['name'] ?? '', 'os-zenarmor') !== false) {
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
        $host = $this->getHostByUuid($this->request->getPost('uuid','string',''));
        if (!$host) return ['result'=>'failed','message'=>'Host nicht gefunden'];
        list($url,$key,$secret,$sv) = $host;
        $r = $this->remoteApiCall($url,$key,$secret,'core/firmware/upgrade','POST',['mode'=>'update'],$sv);
        return $r['http_code']===200 ? ['result'=>'ok','message'=>'Update gestartet.'] : ['result'=>'failed','message'=>'HTTP '.$r['http_code']];
    }

    public function updateZaAction()
    {
        if (!$this->request->isPost()) return ['result'=>'failed','message'=>'POST required'];
        $host = $this->getHostByUuid($this->request->getPost('uuid','string',''));
        if (!$host) return ['result'=>'failed','message'=>'Host nicht gefunden'];
        list($url,$key,$secret,$sv) = $host;
        $r = $this->remoteApiCall($url,$key,$secret,'core/firmware/install/os-zenarmor','POST',[],$sv);
        return $r['http_code']===200 ? ['result'=>'ok','message'=>'ZA Update gestartet.'] : ['result'=>'failed','message'=>'HTTP '.$r['http_code']];
    }

    public function restartZaAction()
    {
        if (!$this->request->isPost()) return ['result'=>'failed','message'=>'POST required'];
        $host = $this->getHostByUuid($this->request->getPost('uuid','string',''));
        if (!$host) return ['result'=>'failed','message'=>'Host nicht gefunden'];
        list($url,$key,$secret,$sv) = $host;
        $ok = $this->zaServiceAction($url, $key, $secret, $sv, 'eastpect', 'restart');
        if ($ok) {
            return ['result'=>'ok','message'=>'ZA Engine Neustart angestossen.'];
        }
        return ['result'=>'failed','message'=>'ZA Engine Neustart fehlgeschlagen. Prüfe ob Interfaces in Zenarmor konfiguriert sind.'];
    }

    public function zaWatchdogCheckAction()
    {
        if (!$this->request->isPost()) return ['result'=>'failed'];
        $host = $this->getHostByUuid($this->request->getPost('uuid','string',''));
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
