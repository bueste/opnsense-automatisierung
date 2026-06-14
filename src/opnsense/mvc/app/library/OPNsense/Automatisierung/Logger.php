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

namespace OPNsense\Automatisierung;

/**
 * Lightweight file logger for the UI / API side of the plugin.
 *
 * Writes to /var/log/automatisierung_ui.log in the same line format the Python
 * jobs use, so the Log tab can parse all sources uniformly:
 *   YYYY-MM-DD HH:MM:SS [LEVEL] [source] message
 *
 * The file is size-capped (best effort) so it can never grow unbounded.
 */
class Logger
{
    const LOG_FILE = '/var/log/automatisierung_ui.log';
    const MAX_BYTES = 1048576; // 1 MB, then truncate to the last half

    public static function write($source, $level, $message)
    {
        $line = sprintf(
            "%s [%s] [%s] %s\n",
            date('Y-m-d H:i:s'),
            strtoupper((string)$level),
            (string)$source,
            str_replace(["\r", "\n"], ' ', (string)$message)
        );
        self::rotateIfNeeded();
        @file_put_contents(self::LOG_FILE, $line, FILE_APPEND | LOCK_EX);
    }

    public static function info($source, $message)
    {
        self::write($source, 'info', $message);
    }

    public static function warning($source, $message)
    {
        self::write($source, 'warning', $message);
    }

    public static function error($source, $message)
    {
        self::write($source, 'error', $message);
    }

    /**
     * Keep the UI log from growing without bound: once it exceeds MAX_BYTES,
     * keep only the most recent half.
     */
    private static function rotateIfNeeded()
    {
        if (!file_exists(self::LOG_FILE) || filesize(self::LOG_FILE) < self::MAX_BYTES) {
            return;
        }
        $data = @file_get_contents(self::LOG_FILE);
        if ($data === false) {
            return;
        }
        $half = substr($data, intval(strlen($data) / 2));
        // Drop the first (likely partial) line after the cut.
        $nl = strpos($half, "\n");
        if ($nl !== false) {
            $half = substr($half, $nl + 1);
        }
        @file_put_contents(self::LOG_FILE, $half, LOCK_EX);
    }
}
