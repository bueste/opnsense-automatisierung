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
 * Automatisierung Log API Controller
 *
 * Read-only (plus clear) access to the plugin's log files, aggregated for the
 * Log tab. Only a fixed whitelist of files can ever be touched.
 */

namespace OPNsense\Automatisierung\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Automatisierung\Logger;

class LogController extends ApiControllerBase
{
    /** Whitelist: source key => [label, absolute path]. */
    private function sources()
    {
        return [
            'watchdog' => ['Zenarmor Watchdog', '/var/log/automatisierung_watchdog.log'],
            'backup'   => ['Backup',            '/var/log/automatisierung_backup.log'],
            'update'   => ['Auto-Update',       '/var/log/automatisierung_update.log'],
            'ui'       => ['UI / API',          Logger::LOG_FILE],
        ];
    }

    private function humanSize($bytes)
    {
        if ($bytes > 1048576) return round($bytes / 1048576, 1) . ' MB';
        if ($bytes > 1024)    return round($bytes / 1024, 1) . ' KB';
        return $bytes . ' B';
    }

    /**
     * Parse a raw log line into [time, level, source, message].
     * Handles both the Python format (… ,ms [LEVEL] msg) and the UI format
     * (… [LEVEL] [source] msg). Unparseable lines are returned as-is.
     */
    private function parseLine($line, $defaultSource)
    {
        $entry = ['time' => '', 'level' => '', 'source' => $defaultSource, 'message' => $line];
        if (preg_match('/^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})(?:,\d+)?\s+\[([A-Z]+)\]\s*(.*)$/s', $line, $m)) {
            $entry['time']    = $m[1];
            $entry['level']   = $m[2];
            $rest             = $m[3];
            // UI lines carry an extra [source] tag right after the level.
            if (preg_match('/^\[([^\]]+)\]\s*(.*)$/s', $rest, $m2)) {
                $entry['source']  = $m2[1];
                $entry['message'] = $m2[2];
            } else {
                $entry['message'] = $rest;
            }
        }
        return $entry;
    }

    /**
     * Read the last $lines of a file efficiently via tail.
     */
    private function tail($path, $lines)
    {
        if (!is_file($path)) {
            return [];
        }
        $out = [];
        exec('/usr/bin/tail -n ' . escapeshellarg((string)$lines) . ' ' . escapeshellarg($path) . ' 2>/dev/null', $out);
        return $out;
    }

    /**
     * GET /api/automatisierung/log/sources
     * List available logs with size / mtime.
     */
    public function sourcesAction()
    {
        $result = [];
        foreach ($this->sources() as $key => $info) {
            $path = $info[1];
            $exists = is_file($path);
            $result[] = [
                'key'       => $key,
                'label'     => $info[0],
                'exists'    => $exists,
                'size'      => $exists ? $this->humanSize(filesize($path)) : '–',
                'size_bytes'=> $exists ? filesize($path) : 0,
                'mtime'     => $exists ? date('d.m.Y H:i:s', filemtime($path)) : '',
            ];
        }
        return ['sources' => $result];
    }

    /**
     * GET /api/automatisierung/log/get?source=all&lines=200&level=&q=
     * Return parsed, newest-first log entries.
     */
    public function getAction()
    {
        $source = $this->request->get('source', 'string', 'all');
        $lines  = (int)$this->request->get('lines', 'string', '200');
        $level  = strtoupper(trim($this->request->get('level', 'string', '')));
        $query  = trim($this->request->get('q', 'string', ''));

        if ($lines < 1)    $lines = 200;
        if ($lines > 5000) $lines = 5000;

        $all = $this->sources();
        $selected = ($source === 'all') ? array_keys($all) : (isset($all[$source]) ? [$source] : []);
        if (empty($selected)) {
            return ['result' => 'failed', 'message' => 'Unbekannte Log-Quelle'];
        }

        $entries = [];
        foreach ($selected as $key) {
            foreach ($this->tail($all[$key][1], $lines) as $raw) {
                if ($raw === '') continue;
                $entries[] = $this->parseLine($raw, $key);
            }
        }

        // Newest first (by timestamp string; falls back to file order otherwise).
        usort($entries, function ($a, $b) {
            return strcmp($b['time'], $a['time']);
        });

        // Filters
        if ($level !== '' || $query !== '') {
            $q = mb_strtolower($query);
            $entries = array_values(array_filter($entries, function ($e) use ($level, $q) {
                if ($level !== '' && $e['level'] !== $level) return false;
                if ($q !== '' && mb_strpos(mb_strtolower($e['message'] . ' ' . $e['source']), $q) === false) return false;
                return true;
            }));
        }

        if (count($entries) > $lines) {
            $entries = array_slice($entries, 0, $lines);
        }

        return ['result' => 'ok', 'count' => count($entries), 'entries' => $entries];
    }

    /**
     * GET /api/automatisierung/log/download?source=watchdog
     */
    public function downloadAction()
    {
        $source = $this->request->get('source', 'string', '');
        $all = $this->sources();
        if (!isset($all[$source]) || !is_file($all[$source][1])) {
            $this->response->setStatusCode(404);
            return;
        }
        $path = $all[$source][1];
        $this->response->setContentType('text/plain');
        $this->response->setHeader('Content-Disposition', 'attachment; filename="automatisierung_' . $source . '.log"');
        $this->response->setHeader('Content-Length', (string)filesize($path));
        $this->response->setContent(file_get_contents($path));
        return $this->response;
    }

    /**
     * POST /api/automatisierung/log/clear  {source: ...}
     */
    public function clearAction()
    {
        if (!$this->request->isPost()) {
            return ['result' => 'failed', 'message' => 'POST required'];
        }
        $source = $this->request->getPost('source', 'string', '');
        $all = $this->sources();
        if (!isset($all[$source])) {
            return ['result' => 'failed', 'message' => 'Unbekannte Log-Quelle'];
        }
        $path = $all[$source][1];
        if (is_file($path)) {
            @file_put_contents($path, '');
        }
        Logger::info('log', 'Log "' . $source . '" geleert (UI).');
        return ['result' => 'ok', 'message' => 'Log geleert.'];
    }
}
