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
 * Automatisierung Backup API Controller
 *
 * Handles all config backup operations:
 *  - Listing local backups per host
 *  - Downloading backup XML content (for diff / browser download)
 *  - Comparing two backups (returns both raw XMLs for client-side diff)
 *  - Deploying (restoring) a backup to a remote host
 *  - Deleting local backups
 *  - Triggering immediate backup
 */

namespace OPNsense\Automatisierung\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Automatisierung\Automatisierung;

class BackupController extends ApiControllerBase
{
    /** Local storage root for collected backups */
    const BACKUP_ROOT = '/var/db/automatisierung/backups';

    private function getModel()
    {
        return new Automatisierung();
    }

    /**
     * Ensure backup directory for a host UUID exists
     */
    private function ensureDir($uuid)
    {
        $dir = self::BACKUP_ROOT . '/' . preg_replace('/[^a-f0-9\-]/', '', $uuid);
        if (!is_dir($dir)) {
            mkdir($dir, 0750, true);
        }
        return $dir;
    }

    /**
     * Perform a curl request to a remote OPNsense API
     * Returns [http_code, data_array, raw_body]
     */
    private function remoteCall($url, $key, $secret, $endpoint,
                                $method = 'GET', $postData = null, $skipVerify = false)
    {
        $fullUrl = rtrim($url, '/') . '/api/' . ltrim($endpoint, '/');
        $ch = curl_init($fullUrl);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_USERPWD, $key . ':' . $secret);
        curl_setopt($ch, CURLOPT_TIMEOUT, 30);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, !$skipVerify);
        curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, $skipVerify ? 0 : 2);
        if ($method === 'POST') {
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, $postData ? json_encode($postData) : '{}');
            curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
        }
        $body     = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error    = curl_error($ch);
        curl_close($ch);

        if ($error) {
            return [0, ['error' => $error], ''];
        }
        $decoded = json_decode($body, true);
        return [$httpCode, $decoded ?? [], $body];
    }

    /**
     * Get host credentials by UUID (only enabled hosts)
     */
    private function getHostByUuid($uuid)
    {
        $mdl = $this->getModel();
        foreach ($mdl->hosts->host->iterateItems() as $huuid => $host) {
            if ($huuid === $uuid && (string)$host->enabled === '1') {
                return [
                    'url'         => (string)$host->url,
                    'api_key'     => (string)$host->api_key,
                    'api_secret'  => (string)$host->api_secret,
                    'skip_verify' => (string)$host->skip_verify_tls === '1',
                    'name'        => (string)$host->name,
                ];
            }
        }
        return null;
    }

    /**
     * List all local backups for a given host UUID
     * GET /api/automatisierung/backup/listBackups?uuid=...
     */
    public function listBackupsAction()
    {
        $uuid = $this->request->get('uuid', 'string', '');
        if (empty($uuid)) {
            return ['result' => 'failed', 'message' => 'uuid fehlt'];
        }

        $dir = self::BACKUP_ROOT . '/' . preg_replace('/[^a-f0-9\-]/', '', $uuid);
        if (!is_dir($dir)) {
            return ['backups' => []];
        }

        $files = glob($dir . '/*.xml');
        if (!$files) {
            return ['backups' => []];
        }

        $backups = [];
        foreach ($files as $f) {
            $fname    = basename($f);
            $mtime    = filemtime($f);
            $size     = filesize($f);
            // Extract metadata from XML revision section
            $meta     = $this->extractBackupMeta($f);
            // Read sidecar comment (our own metadata, takes priority)
            $sidecar  = [];
            $sidecarPath = $f . '.meta.json';
            if (file_exists($sidecarPath)) {
                $sidecar = json_decode(file_get_contents($sidecarPath), true) ?: [];
            }
            $comment  = isset($sidecar['comment']) && $sidecar['comment'] !== ''
                        ? $sidecar['comment']
                        : ($meta['description'] ?? '');
            $source   = $sidecar['source'] ?? 'auto';
            $backups[] = [
                'filename'      => $fname,
                'timestamp'     => date('c', $mtime),
                'timestamp_fmt' => date('d.m.Y H:i:s', $mtime),
                'size'          => $this->humanSize($size),
                'size_bytes'    => $size,
                'description'   => $comment,
                'source'        => $source,
                'revision_user' => $meta['username'] ?? '',
                'revision_time' => $meta['time'] ?? '',
            ];
        }

        // Sort newest first
        usort($backups, function($a, $b) {
            return strcmp($b['filename'], $a['filename']);
        });

        return ['backups' => $backups];
    }

    /**
     * Extract revision metadata from a backup XML file
     */
    private function extractBackupMeta($filepath)
    {
        $meta = [];
        try {
            $content = file_get_contents($filepath, false, null, 0, 4096);
            if (preg_match('/<description>(.*?)<\/description>/s', $content, $m)) {
                $meta['description'] = html_entity_decode(trim($m[1]));
            }
            if (preg_match('/<username>(.*?)<\/username>/s', $content, $m)) {
                $meta['username'] = html_entity_decode(trim($m[1]));
            }
            if (preg_match('/<time>(\d+)<\/time>/s', $content, $m)) {
                $meta['time'] = date('d.m.Y H:i:s', (int)$m[1]);
            }
        } catch (\Exception $e) {}
        return $meta;
    }

    private function humanSize($bytes)
    {
        if ($bytes > 1048576) return round($bytes / 1048576, 1) . ' MB';
        if ($bytes > 1024)    return round($bytes / 1024, 1) . ' KB';
        return $bytes . ' B';
    }

    /**
     * Get raw content of a single backup
     * GET /api/automatisierung/backup/getContent?uuid=...&filename=...
     */
    public function getContentAction()
    {
        $uuid     = $this->request->get('uuid', 'string', '');
        $filename = basename($this->request->get('filename', 'string', ''));

        if (empty($uuid) || empty($filename) || !preg_match('/^[\w\-\.]+\.xml$/', $filename)) {
            return ['result' => 'failed', 'message' => 'Ungültige Parameter'];
        }

        $path = self::BACKUP_ROOT . '/' . preg_replace('/[^a-f0-9\-]/', '', $uuid) . '/' . $filename;
        if (!file_exists($path)) {
            return ['result' => 'failed', 'message' => 'Datei nicht gefunden'];
        }

        return [
            'result'   => 'ok',
            'filename' => $filename,
            'content'  => file_get_contents($path),
        ];
    }

    /**
     * Compare two backups using server-side diff -u (handles duplicate XML lines correctly).
     * GET /api/automatisierung/backup/compareBackups?uuid=...&file_a=...&file_b=...
     */
    public function compareBackupsAction()
    {
        $uuid   = $this->request->get('uuid', 'string', '');
        $file_a = basename($this->request->get('file_a', 'string', ''));
        $file_b = basename($this->request->get('file_b', 'string', ''));

        if (empty($uuid) || empty($file_a) || empty($file_b)) {
            return ['result' => 'failed', 'message' => 'Parameter fehlen'];
        }

        $dir    = self::BACKUP_ROOT . '/' . preg_replace('/[^a-f0-9\-]/', '', $uuid) . '/';
        $path_a = $dir . $file_a;
        $path_b = $dir . $file_b;

        if (!file_exists($path_a) || !file_exists($path_b)) {
            return ['result' => 'failed', 'message' => 'Eine oder beide Dateien nicht gefunden'];
        }

        // Normalize line endings into temp files so diff works correctly
        $tmpA = tempnam(sys_get_temp_dir(), 'bkA_');
        $tmpB = tempnam(sys_get_temp_dir(), 'bkB_');
        file_put_contents($tmpA, str_replace("\r\n", "\n", file_get_contents($path_a)));
        file_put_contents($tmpB, str_replace("\r\n", "\n", file_get_contents($path_b)));

        // Run server-side diff; rc=0 identical, rc=1 differences, rc>1 error
        exec('diff -u ' . escapeshellarg($tmpA) . ' ' . escapeshellarg($tmpB) . ' 2>/dev/null', $diffLines, $rc);
        @unlink($tmpA);
        @unlink($tmpB);

        if ($rc > 1) {
            return ['result' => 'failed', 'message' => 'Diff-Fehler (rc=' . $rc . ')'];
        }

        return [
            'result'       => 'ok',
            'file_a'       => $file_a,
            'file_b'       => $file_b,
            'mtime_a'      => date('d.m.Y H:i:s', filemtime($path_a)),
            'mtime_b'      => date('d.m.Y H:i:s', filemtime($path_b)),
            'unified_diff' => implode("\n", $diffLines),
            'identical'    => ($rc === 0),
        ];
    }

    /**
     * Download a backup file directly to browser
     * GET /api/automatisierung/backup/downloadFile?uuid=...&filename=...
     */
    public function downloadFileAction()
    {
        $uuid     = $this->request->get('uuid', 'string', '');
        $filename = basename($this->request->get('filename', 'string', ''));

        if (empty($uuid) || !preg_match('/^[\w\-\.]+\.xml$/', $filename)) {
            $this->response->setStatusCode(400);
            return;
        }

        $path = self::BACKUP_ROOT . '/' . preg_replace('/[^a-f0-9\-]/', '', $uuid) . '/' . $filename;
        if (!file_exists($path)) {
            $this->response->setStatusCode(404);
            return;
        }

        $host = $this->getHostByUuid($uuid);
        $hostName = $host ? preg_replace('/[^a-zA-Z0-9_\-]/', '_', $host['name']) : $uuid;
        $dlName = 'config_' . $hostName . '_' . $filename;

        $this->response->setContentType('application/xml');
        $this->response->setHeader('Content-Disposition', 'attachment; filename="' . $dlName . '"');
        $this->response->setHeader('Content-Length', (string)filesize($path));
        $this->response->setContent(file_get_contents($path));
        return $this->response;
    }

    /**
     * Trigger immediate backup from a remote host (fetch + store locally)
     * POST /api/automatisierung/backup/triggerBackup  {uuid: ...}
     */
    /**
     * Trigger immediate backup from a remote host (fetch + store locally).
     * Uses OPNsense 26.x API: GET core/backup/download/this
     * POST /api/automatisierung/backup/triggerBackup  {uuid: ...}
     */
    public function triggerBackupAction()
    {
        $result = ['result' => 'failed', 'message' => ''];
        if (!$this->request->isPost()) {
            $result['message'] = 'POST required';
            return $result;
        }

        $uuid    = $this->request->getPost('uuid', 'string', '');
        $comment = trim($this->request->getPost('comment', 'string', ''));
        $host    = $this->getHostByUuid($uuid);
        if (!$host) {
            $result['message'] = 'Host nicht gefunden oder deaktiviert';
            return $result;
        }

        // OPNsense 26.x: core/backup/download/this → aktuellstes config.xml
        list($code, , $raw) = $this->remoteCall(
            $host['url'], $host['api_key'], $host['api_secret'],
            'core/backup/download/this', 'GET', null, $host['skip_verify']
        );

        if ($code === 200 && strpos($raw, '<?xml') !== false) {
            return $this->storeBackup($uuid, $raw, $result, $comment);
        }

        $result['message'] = 'Backup konnte nicht abgerufen werden (HTTP ' . $code . '). '
            . 'Stelle sicher dass der API-Benutzer Backup-Rechte hat.';
        return $result;
    }

    /**
     * Return true if $newContent differs from the most recent file in $dir matching $pattern.
     * Always returns true when no previous backup exists.
     */
    private function hasChanges($dir, $newContent, $pattern = '*.xml')
    {
        $files = glob($dir . '/' . $pattern) ?: [];
        if (empty($files)) {
            return true;
        }
        usort($files, function($a, $b) { return strcmp($b, $a); });
        $latestHash = md5_file($files[0]);
        return $latestHash !== md5($newContent);
    }

    /**
     * Store raw XML backup content locally, then auto-apply retention.
     */
    private function storeBackup($uuid, $rawXml, &$result, $comment = '')
    {
        $dir = $this->ensureDir($uuid);

        if (!$this->hasChanges($dir, $rawXml, '*.xml')) {
            $result['result']  = 'ok';
            $result['message'] = 'Keine Änderungen seit letztem Backup – nichts gespeichert.';
            return $result;
        }

        $filename = date('Y-m-d_His') . '.xml';
        $path     = $dir . '/' . $filename;

        if (file_put_contents($path, $rawXml) !== false) {
            // Write sidecar metadata
            $meta = ['comment' => $comment, 'source' => $comment !== '' ? 'manual' : 'auto', 'created' => date('c')];
            file_put_contents($path . '.meta.json', json_encode($meta));

            // Auto-apply retention (delete files older than configured days)
            $deleted = $this->applyRetentionToDir($dir);

            $result['result']   = 'ok';
            $result['message']  = 'Backup erstellt: ' . $filename;
            $result['filename'] = $filename;
            if ($deleted > 0) {
                $result['message'] .= ' (' . $deleted . ' alte Backups gemäss Retention entfernt)';
            }
        } else {
            $result['message'] = 'Fehler beim Schreiben der Backup-Datei.';
        }
        return $result;
    }

    /**
     * Delete XML backups in $dir older than $days days.
     * Also removes accompanying .meta.json sidecar files.
     * Returns number of deleted backup files.
     */
    private function applyRetentionToDir($dir, $days = null)
    {
        if ($days === null) {
            $mdl  = $this->getModel();
            $days = (int)(string)$mdl->general->backup_retention_days;
            if ($days < 1) $days = 30;
        }
        $cutoff  = time() - ($days * 86400);
        $deleted = 0;
        foreach (glob($dir . '/*.xml') ?: [] as $f) {
            if (filemtime($f) < $cutoff) {
                @unlink($f);
                @unlink($f . '.meta.json');
                $deleted++;
            }
        }
        return $deleted;
    }

    /**
     * Deploy (restore) a backup to a remote host
     * POST /api/automatisierung/backup/deployBackup  {uuid: ..., filename: ...}
     */
    public function deployBackupAction()
    {
        $result = ['result' => 'failed', 'message' => ''];
        if (!$this->request->isPost()) {
            $result['message'] = 'POST required';
            return $result;
        }

        $uuid     = $this->request->getPost('uuid', 'string', '');
        $filename = basename($this->request->getPost('filename', 'string', ''));

        if (!preg_match('/^[\w\-\.]+\.xml$/', $filename)) {
            $result['message'] = 'Ungültiger Dateiname';
            return $result;
        }

        $host = $this->getHostByUuid($uuid);
        if (!$host) {
            $result['message'] = 'Host nicht gefunden';
            return $result;
        }

        $path = self::BACKUP_ROOT . '/' . preg_replace('/[^a-f0-9\-]/', '', $uuid) . '/' . $filename;
        if (!file_exists($path)) {
            $result['message'] = 'Backup-Datei nicht gefunden';
            return $result;
        }

        $xmlContent = file_get_contents($path);

        // Upload via multipart POST to OPNsense restore endpoint
        $boundary = '----AutomatisierungBoundary' . md5(uniqid());
        $body = "--{$boundary}\r\n"
              . "Content-Disposition: form-data; name=\"conffile\"; filename=\"config.xml\"\r\n"
              . "Content-Type: application/xml\r\n\r\n"
              . $xmlContent . "\r\n"
              . "--{$boundary}--\r\n";

        $fullUrl = rtrim($host['url'], '/') . '/api/core/backup/restore';
        $ch = curl_init($fullUrl);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_USERPWD, $host['api_key'] . ':' . $host['api_secret']);
        curl_setopt($ch, CURLOPT_TIMEOUT, 60);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, !$host['skip_verify']);
        curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, $host['skip_verify'] ? 0 : 2);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $body);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Content-Type: multipart/form-data; boundary=' . $boundary,
            'Content-Length: ' . strlen($body),
        ]);
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curlErr  = curl_error($ch);
        curl_close($ch);

        if ($curlErr) {
            $result['message'] = 'Verbindungsfehler: ' . $curlErr;
            return $result;
        }

        if ($httpCode === 200) {
            $resp = json_decode($response, true);
            if (isset($resp['result']) && $resp['result'] === 'ok') {
                $result['result']  = 'ok';
                $result['message'] = 'Backup wurde erfolgreich auf ' . $host['name'] . ' eingespielt. Die Firewall startet neu.';
            } else {
                $result['result']  = 'ok';
                $result['message'] = 'Restore-Befehl abgesendet. Bitte Firewall-Zustand prüfen.';
            }
        } else {
            $result['message'] = 'Restore fehlgeschlagen (HTTP ' . $httpCode . '). Prüfe ob der API-Benutzer die nötigen Rechte hat.';
        }

        return $result;
    }

    /**
     * Delete a local backup file
     * POST /api/automatisierung/backup/deleteBackup  {uuid: ..., filename: ...}
     */
    public function deleteBackupAction()
    {
        $result = ['result' => 'failed', 'message' => ''];
        if (!$this->request->isPost()) {
            $result['message'] = 'POST required';
            return $result;
        }

        $uuid     = $this->request->getPost('uuid', 'string', '');
        $filename = basename($this->request->getPost('filename', 'string', ''));

        if (!preg_match('/^[\w\-\.]+\.xml$/', $filename)) {
            $result['message'] = 'Ungültiger Dateiname';
            return $result;
        }

        $path = self::BACKUP_ROOT . '/' . preg_replace('/[^a-f0-9\-]/', '', $uuid) . '/' . $filename;
        if (!file_exists($path)) {
            $result['message'] = 'Datei nicht gefunden';
            return $result;
        }

        if (unlink($path)) {
            $result['result']  = 'ok';
            $result['message'] = 'Backup gelöscht.';
        } else {
            $result['message'] = 'Löschen fehlgeschlagen.';
        }

        return $result;
    }

    /**
     * Get backup general settings
     */
    public function getSettingsAction()
    {
        $mdl = $this->getModel();
        return [
            'backup' => [
                'enabled'         => (string)$mdl->general->backup_enabled,
                'hour'            => (string)$mdl->general->backup_hour,
                'minute'          => (string)$mdl->general->backup_minute,
                'days'            => (string)$mdl->general->backup_days,
                'retention_days'  => (string)$mdl->general->backup_retention_days,
            ]
        ];
    }

    /**
     * Save backup settings + update host backup_enabled flags
     */
    public function setSettingsAction()
    {
        $result = ['result' => 'failed', 'message' => ''];
        if (!$this->request->isPost()) {
            $result['message'] = 'POST required';
            return $result;
        }

        $mdl  = $this->getModel();
        $data = $this->request->getPost('backup');
        if (!is_array($data)) {
            $result['message'] = 'Keine Daten übermittelt';
            return $result;
        }

        $gen = $mdl->general;
        if ($gen !== null) {
            if ($gen->backup_enabled        !== null) $gen->backup_enabled->setValue(isset($data['enabled'])        ? $data['enabled']        : '0');
            if ($gen->backup_hour           !== null) $gen->backup_hour->setValue(isset($data['hour'])           ? $data['hour']           : '2');
            if ($gen->backup_minute         !== null) $gen->backup_minute->setValue(isset($data['minute'])         ? $data['minute']         : '0');
            if ($gen->backup_days           !== null) $gen->backup_days->setValue(isset($data['days'])           ? $data['days']           : '*');
            if ($gen->backup_retention_days !== null) $gen->backup_retention_days->setValue(isset($data['retention_days']) ? $data['retention_days'] : '30');
        }

        // Per-host backup_enabled
        if (!empty($data['hosts']) && is_array($data['hosts'])) {
            foreach ($mdl->hosts->host->iterateItems() as $uuid => $host) {
                if ($host->backup_enabled !== null) {
                    $host->backup_enabled->setValue(
                        isset($data['hosts'][$uuid]) && $data['hosts'][$uuid] === '1' ? '1' : '0'
                    );
                }
            }
        }

        $validation = $mdl->performValidation();
        if ($validation->count() === 0) {
            $mdl->serializeToConfig();
            \OPNsense\Core\Config::getInstance()->save();
            $result['result']  = 'saved';
            $result['message'] = 'Einstellungen gespeichert.';
        } else {
            $result['validations'] = [];
            foreach ($validation as $msg) {
                $result['validations'][$msg->getField()] = $msg->getMessage();
            }
        }

        return $result;
    }

    /**
     * Get all hosts with their backup status (for the backup tab host selector)
     */
    public function getHostsAction()
    {
        $mdl   = $this->getModel();
        $hosts = [];
        foreach ($mdl->hosts->host->iterateItems() as $uuid => $host) {
            if ((string)$host->enabled !== '1') {
                continue;
            }
            $dir   = self::BACKUP_ROOT . '/' . preg_replace('/[^a-f0-9\-]/', '', $uuid);
            $count = is_dir($dir) ? count(glob($dir . '/*.xml') ?: []) : 0;
            $hosts[] = [
                'uuid'           => $uuid,
                'name'           => (string)$host->name,
                'url'            => (string)$host->url,
                'backup_enabled' => (string)$host->backup_enabled,
                'backup_count'   => $count,
            ];
        }
        return ['hosts' => $hosts];
    }

    /**
     * Trigger ZA (Zenarmor) backup on a remote host: create + fetch + store locally
     * POST /api/automatisierung/backup/triggerZaBackup  {uuid: ...}
     */
    public function triggerZaBackupAction()
    {
        $result = ['result' => 'failed', 'message' => ''];
        if (!$this->request->isPost()) {
            $result['message'] = 'POST required';
            return $result;
        }

        $uuid = $this->request->getPost('uuid', 'string', '');
        $host = $this->getHostByUuid($uuid);
        if (!$host) {
            $result['message'] = 'Host nicht gefunden oder deaktiviert';
            return $result;
        }

        // Step 1: Trigger backup creation on remote host
        list($code, $data,) = $this->remoteCall(
            $host['url'], $host['api_key'], $host['api_secret'],
            'zenarmor/backup/index', 'POST', [], $host['skip_verify']
        );

        if ($code !== 200 || !empty($data['error'])) {
            $msg = isset($data['message']) ? $data['message'] : 'HTTP ' . $code;
            $result['message'] = 'ZA-Backup konnte nicht erstellt werden: ' . $msg;
            return $result;
        }

        // Step 2: List backups to find the latest file
        list($listCode, $listData,) = $this->remoteCall(
            $host['url'], $host['api_key'], $host['api_secret'],
            'zenarmor/backup/index', 'GET', null, $host['skip_verify']
        );

        if ($listCode !== 200 || empty($listData['backupList'])) {
            $result['message'] = 'ZA-Backupliste konnte nicht abgerufen werden (HTTP ' . $listCode . ')';
            return $result;
        }

        $files = $listData['backupList'];
        usort($files, function($a, $b) { return strcmp($b['filename'], $a['filename']); });
        $latest = $files[0]['filename'];

        // Step 3: Download the backup file (binary .gz)
        list($dlCode, , $rawGz) = $this->remoteCall(
            $host['url'], $host['api_key'], $host['api_secret'],
            'zenarmor/backup/download?filename=' . rawurlencode($latest), 'GET', null, $host['skip_verify']
        );

        if ($dlCode !== 200 || empty($rawGz)) {
            $result['message'] = 'ZA-Backup-Download fehlgeschlagen (HTTP ' . $dlCode . ')';
            return $result;
        }

        // Step 4: Store locally under {uuid}/za/
        $zaDir = $this->ensureDir($uuid) . '/za';
        if (!is_dir($zaDir)) {
            mkdir($zaDir, 0750, true);
        }

        if (!$this->hasChanges($zaDir, $rawGz, '*')) {
            $result['result']  = 'ok';
            $result['message'] = 'Keine Änderungen seit letztem ZA-Backup – nichts gespeichert.';
            return $result;
        }

        $localFile = date('Y-m-d_His') . '_' . preg_replace('/[^a-zA-Z0-9_.\-]/', '', $latest);
        if (file_put_contents($zaDir . '/' . $localFile, $rawGz) !== false) {
            $result['result']   = 'ok';
            $result['message']  = 'ZA-Backup erstellt: ' . $localFile;
            $result['filename'] = $localFile;
        } else {
            $result['message'] = 'Fehler beim Speichern der ZA-Backup-Datei';
        }
        return $result;
    }

    /**
     * List local ZA backups for a host
     * GET /api/automatisierung/backup/listZaBackups?uuid=...
     */
    public function listZaBackupsAction()
    {
        $uuid = $this->request->get('uuid', 'string', '');
        if (empty($uuid)) {
            return ['result' => 'failed', 'message' => 'uuid fehlt'];
        }

        $dir = self::BACKUP_ROOT . '/' . preg_replace('/[^a-f0-9\-]/', '', $uuid) . '/za';
        if (!is_dir($dir)) {
            return ['backups' => []];
        }

        $files = glob($dir . '/*') ?: [];
        $backups = [];
        foreach ($files as $f) {
            $fname = basename($f);
            $mtime = filemtime($f);
            $backups[] = [
                'filename'      => $fname,
                'timestamp'     => date('c', $mtime),
                'timestamp_fmt' => date('d.m.Y H:i:s', $mtime),
                'size'          => $this->humanSize(filesize($f)),
                'size_bytes'    => filesize($f),
            ];
        }

        usort($backups, function($a, $b) { return strcmp($b['filename'], $a['filename']); });
        return ['backups' => $backups];
    }

    /**
     * Serve a local ZA backup file for browser download
     * GET /api/automatisierung/backup/downloadZaFile?uuid=...&filename=...
     */
    public function downloadZaFileAction()
    {
        $uuid     = $this->request->get('uuid', 'string', '');
        $filename = basename($this->request->get('filename', 'string', ''));

        if (empty($uuid) || empty($filename) || !preg_match('/^[\w\-\.]+$/', $filename)) {
            $this->response->setStatusCode(400);
            return;
        }

        $path = self::BACKUP_ROOT . '/' . preg_replace('/[^a-f0-9\-]/', '', $uuid) . '/za/' . $filename;
        if (!file_exists($path)) {
            $this->response->setStatusCode(404);
            return;
        }

        $this->response->setContentType('application/octet-stream');
        $this->response->setHeader('Content-Disposition', 'attachment; filename="' . $filename . '"');
        $this->response->setHeader('Content-Length', (string)filesize($path));
        $this->response->setContent(file_get_contents($path));
        return $this->response;
    }

    /**
     * Delete a local ZA backup file
     * POST /api/automatisierung/backup/deleteZaBackup  {uuid: ..., filename: ...}
     */
    public function deleteZaBackupAction()
    {
        $result = ['result' => 'failed', 'message' => ''];
        if (!$this->request->isPost()) {
            $result['message'] = 'POST required';
            return $result;
        }

        $uuid     = $this->request->getPost('uuid', 'string', '');
        $filename = basename($this->request->getPost('filename', 'string', ''));

        if (!preg_match('/^[\w\-\.]+$/', $filename)) {
            $result['message'] = 'Ungültiger Dateiname';
            return $result;
        }

        $path = self::BACKUP_ROOT . '/' . preg_replace('/[^a-f0-9\-]/', '', $uuid) . '/za/' . $filename;
        if (!file_exists($path)) {
            $result['message'] = 'Datei nicht gefunden';
            return $result;
        }

        if (unlink($path)) {
            $result['result']  = 'ok';
            $result['message'] = 'ZA-Backup gelöscht.';
        } else {
            $result['message'] = 'Löschen fehlgeschlagen.';
        }

        return $result;
    }

    /**
     * Run retention cleanup for a host (or all hosts if uuid empty).
     * POST /api/automatisierung/backup/runRetention  {uuid: ...}
     */
    public function runRetentionAction()
    {
        $result = ['result' => 'ok', 'deleted' => 0];
        if (!$this->request->isPost()) {
            $result['result'] = 'failed';
            return $result;
        }

        $uuid = $this->request->getPost('uuid', 'string', '');
        $mdl  = $this->getModel();
        $days = (int)(string)$mdl->general->backup_retention_days;
        if ($days < 1) $days = 30;

        $uuids = $uuid ? [$uuid] : [];
        if (empty($uuids)) {
            foreach ($mdl->hosts->host->iterateItems() as $huuid => $host) {
                $uuids[] = $huuid;
            }
        }

        foreach ($uuids as $huuid) {
            $dir = self::BACKUP_ROOT . '/' . preg_replace('/[^a-f0-9\-]/', '', $huuid);
            if (!is_dir($dir)) continue;
            $result['deleted'] += $this->applyRetentionToDir($dir, $days);
        }

        $result['message'] = $result['deleted'] . ' alte Backup(s) gelöscht (Retention: ' . $days . ' Tage).';
        return $result;
    }
}
