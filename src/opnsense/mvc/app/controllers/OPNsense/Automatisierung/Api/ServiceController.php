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
        if ($method === 'POST') { curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']); }
        if ($method === 'POST') {
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, $postData ? json_encode($postData) : '{}');
        }
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curlError = curl_error($ch);
        curl_close($ch);
        if ($curlError) return ['error' => $curlError, 'http_code' => 0];
        return ['data' => json_decode($response, true) ?? [], 'http_code' => $httpCode];
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
                if (!empty($fwSt['data']['updates'])) $entry['opnsense_update_count'] = count($fwSt['data']['updates']);
            }
            // Zenarmor via zenarmor/status/index (OPNsense 26.x)
            $za = $this->remoteApiCall($url, $key, $secret, 'zenarmor/status/index', 'GET', null, $skipVerify);
            if ($za['http_code'] === 200 && !empty($za['data'])) {
                $entry['za_installed'] = true;
                $zd = $za['data'];
                // Korrekte Felder aus zenarmor/status/index
                $av = $zd['agent_version'] ?? '?';
                $entry['za_version'] = is_array($av) ? ($av['version'] ?? '?') : (string)$av;
                $entry['za_running'] = (bool)($zd['agent_status'] ?? false);
                $agentStatus              = strtolower($zd['agent_status'] ?? '');
                $entry['za_running']       = in_array($agentStatus, ['running','active','started','1','true']);
                $entry['za_engine_status'] = $agentStatus ?: 'unknown';
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
        // Zenarmor restart via configd-style reconfigure
        $r = $this->remoteApiCall($url,$key,$secret,'zenarmor/status/index','GET',null,$sv);
        if ($r['http_code']===200) {
            return ['result'=>'ok','message'=>'ZA Engine läuft. Direkter Neustart via API nicht verfügbar — bitte über Zenarmor-Interface.'];
        }
        return ['result'=>'failed','message'=>'ZA Status nicht abrufbar.'];
    }

    public function zaWatchdogCheckAction()
    {
        if (!$this->request->isPost()) return ['result'=>'failed'];
        $host = $this->getHostByUuid($this->request->getPost('uuid','string',''));
        if (!$host) return ['result'=>'failed','message'=>'Host nicht gefunden'];
        list($url,$key,$secret,$sv) = $host;
        $za = $this->remoteApiCall($url,$key,$secret,'zenarmor/status/index','GET',null,$sv);
        if ($za['http_code']!==200) return ['result'=>'ok','actions'=>['Status nicht abrufbar.']];
        $running = in_array(strtolower($za['data']['status']??''),['running','active']);
        $needsRestart = !empty($za['data']['needs_restart']);
        $actions = [];
        if (!$running) {
            $actions[] = 'ZA nicht aktiv — starte...';
            $s = $this->remoteApiCall($url,$key,$secret,'zenarmor/service/start','POST',[],$sv);
            $actions[] = $s['http_code']===200 ? 'Gestartet.' : 'Start fehlgeschlagen.';
        } elseif ($needsRestart) {
            $actions[] = 'Neustart erforderlich...';
            $r = $this->remoteApiCall($url,$key,$secret,'zenarmor/service/restart','POST',[],$sv);
            $actions[] = $r['http_code']===200 ? 'Neugestartet.' : 'Fehlgeschlagen.';
        } else {
            $actions[] = 'ZA läuft — kein Eingriff nötig.';
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
