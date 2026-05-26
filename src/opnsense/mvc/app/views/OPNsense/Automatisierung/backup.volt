<div class="content-box" style="padding-bottom:1.5em;">

    <div class="col-xs-12">
        <h1><i class="fa fa-archive"></i> {{ lang._('Automatisierung – Konfigurationsbackup') }}</h1>
        <hr/>
    </div>

    <!-- ========== TABS ========== -->
    <div class="col-xs-12">
        <ul class="nav nav-tabs" id="backupMainTabs" role="tablist">
            <li class="active"><a href="#tab-compare" data-toggle="tab"><i class="fa fa-code-fork"></i> {{ lang._('Sicherungen vergleichen') }}</a></li>
            <li><a href="#tab-list" data-toggle="tab"><i class="fa fa-list"></i> {{ lang._('Alle Sicherungen') }}</a></li>
            <li><a href="#tab-settings" data-toggle="tab"><i class="fa fa-cog"></i> {{ lang._('Einstellungen') }}</a></li>
        </ul>
    </div>

    <div class="tab-content col-xs-12" style="padding-top:1.2em;">

    <!-- ===================================================================
         TAB 1: SICHERUNGEN VERGLEICHEN
         =================================================================== -->
    <div id="tab-compare" class="tab-pane fade in active">

        <div class="form-group row" style="margin-bottom:10px;">
            <label class="col-xs-12 col-sm-2 control-label" style="text-align:left;font-weight:600;padding-top:8px;">{{ lang._('Host') }}</label>
            <div class="col-xs-12 col-sm-5">
                <select id="cmp_host_select" class="form-control selectpicker" data-live-search="true">
                    <option value="">— Host wählen —</option>
                </select>
            </div>
            <div class="col-xs-12 col-sm-5" style="padding-top:5px;">
                <button id="btn_cmp_backup_now" class="btn btn-primary btn-sm" disabled>
                    <i class="fa fa-camera"></i> {{ lang._('Backup jetzt erstellen') }}
                </button>
            </div>
        </div>

        <hr style="margin:4px 0 14px 0;"/>

        <div id="cmp_section" style="display:none;">

            <h4 style="font-weight:600;margin:0 0 10px 0;">{{ lang._('Sicherungen (vergleichen)') }}</h4>

            <div class="row" style="margin-bottom:4px;">
                <div class="col-xs-12 col-sm-6" style="padding-right:3px;">
                    <select id="cmp_file_a" class="form-control selectpicker" data-live-search="true" data-width="100%">
                        <option value="">— Sicherung A wählen —</option>
                    </select>
                </div>
                <div class="col-xs-12 col-sm-6" style="padding-left:3px;">
                    <select id="cmp_file_b" class="form-control selectpicker" data-live-search="true" data-width="100%">
                        <option value="">— Sicherung B wählen —</option>
                    </select>
                </div>
            </div>

            <div class="row" style="margin-bottom:10px;">
                <div class="col-xs-12 col-sm-6" style="padding-right:3px;">
                    <div id="actions_a" style="display:none;line-height:2.2;">
                        <button class="btn btn-xs btn-default" id="btn_restore_a" title="{{ lang._('Diese Konfiguration auf die Firewall einspielen') }}"><i class="fa fa-reply"></i></button>
                        <button class="btn btn-xs btn-default" id="btn_delete_a" title="{{ lang._('Dieses Backup löschen') }}"><i class="fa fa-trash-o"></i></button>
                        <a id="btn_download_a" href="#" class="btn btn-xs btn-default" title="{{ lang._('Herunterladen') }}" download><i class="fa fa-download"></i></a>
                        <span id="meta_a" class="text-muted" style="margin-left:4px;font-size:0.8em;"></span>
                    </div>
                </div>
                <div class="col-xs-12 col-sm-6" style="padding-left:3px;">
                    <div id="actions_b" style="display:none;line-height:2.2;">
                        <button class="btn btn-xs btn-default" id="btn_restore_b" title="{{ lang._('Diese Konfiguration auf die Firewall einspielen') }}"><i class="fa fa-reply"></i></button>
                        <button class="btn btn-xs btn-default" id="btn_delete_b" title="{{ lang._('Dieses Backup löschen') }}"><i class="fa fa-trash-o"></i></button>
                        <a id="btn_download_b" href="#" class="btn btn-xs btn-default" title="{{ lang._('Herunterladen') }}" download><i class="fa fa-download"></i></a>
                        <span id="meta_b" class="text-muted" style="margin-left:4px;font-size:0.8em;"></span>
                    </div>
                </div>
            </div>

            <div style="margin-bottom:14px;">
                <button id="btn_run_compare" class="btn btn-default btn-sm" disabled>
                    <i class="fa fa-search"></i> {{ lang._('Versionen vergleichen') }}
                </button>
            </div>

            <div id="diff_loading" style="display:none;padding:2em 0;text-align:center;">
                <i class="fa fa-spinner fa-spin fa-2x"></i>
                <p>{{ lang._('Lade und vergleiche Konfigurationen...') }}</p>
            </div>

            <div id="diff_wrap" style="display:none;">
                <div style="padding:4px 0 6px 0;font-size:0.9em;color:#333;">
                    <strong>{{ lang._('Änderungen zwischen ausgewählten Versionen') }}</strong>
                    <span id="diff_stats" style="margin-left:12px;font-size:0.9em;"></span>
                </div>
                <div id="diff_output" style="font-family:'SFMono-Regular',Consolas,'Liberation Mono',Menlo,monospace;font-size:12.5px;line-height:1.5;border:1px solid #d1d5da;border-radius:4px;overflow:auto;max-height:560px;background:#fff;padding:0;"></div>
            </div>

            <div id="diff_identical" class="text-success" style="display:none;padding:1em 0;">
                <i class="fa fa-check-circle"></i> {{ lang._('Die beiden Konfigurationen sind identisch – keine Unterschiede gefunden.') }}
            </div>

            <div id="cmp_action_msg" class="alert" style="display:none;margin-top:0.8em;"></div>

        </div>

        <div id="cmp_empty_state" class="text-muted" style="padding:2em 0;">
            <i class="fa fa-arrow-up"></i> {{ lang._('Bitte oben einen Host auswählen.') }}
        </div>

    </div><!-- /#tab-compare -->


    <!-- ===================================================================
         TAB 2: ALLE SICHERUNGEN
         =================================================================== -->
    <div id="tab-list" class="tab-pane fade">

        <div class="row" style="margin-bottom:1em;">
            <div class="col-xs-12 col-sm-5">
                <label>{{ lang._('Host') }}</label>
                <select id="list_host_select" class="form-control selectpicker" data-live-search="true">
                    <option value="">— Host wählen —</option>
                </select>
            </div>
            <div class="col-xs-12 col-sm-7" style="padding-top:1.6em;">
                <button id="btn_list_backup_now" class="btn btn-primary btn-sm" disabled>
                    <i class="fa fa-camera"></i> {{ lang._('Backup erstellen') }}
                </button>
                <button id="btn_list_refresh" class="btn btn-default btn-sm" disabled>
                    <i class="fa fa-refresh"></i> {{ lang._('Aktualisieren') }}
                </button>
                <button id="btn_list_retention" class="btn btn-default btn-sm" disabled title="{{ lang._('Alte Backups gemäss Retention-Einstellung entfernen') }}">
                    <i class="fa fa-trash-o"></i> {{ lang._('Retention anwenden') }}
                </button>
            </div>
        </div>

        <div id="list_msg" class="alert" style="display:none;"></div>

        <div id="list_table_wrap" style="display:none;">
            <table class="table table-condensed table-hover table-striped">
                <thead>
                <tr>
                    <th style="width:2.5em;"><input type="checkbox" id="chk_all"/></th>
                    <th>{{ lang._('Zeitstempel') }}</th>
                    <th>{{ lang._('Beschreibung / Revision') }}</th>
                    <th>{{ lang._('Benutzer') }}</th>
                    <th style="width:5em;">{{ lang._('Grösse') }}</th>
                    <th style="width:10em;">{{ lang._('Aktionen') }}</th>
                </tr>
                </thead>
                <tbody id="backup_list_tbody"></tbody>
            </table>
            <div style="margin-top:6px;display:flex;align-items:center;gap:8px;">
                <button id="btn_compare_checked" class="btn btn-info btn-xs" disabled>
                    <i class="fa fa-code-fork"></i> {{ lang._('Ausgewählte vergleichen (2 wählen)') }}
                </button>
                <button id="btn_delete_checked" class="btn btn-danger btn-xs" disabled>
                    <i class="fa fa-trash-o"></i> {{ lang._('Auswahl löschen') }}
                </button>
                <span id="sel_count" class="text-muted" style="font-size:0.88em;"></span>
            </div>
        </div>

        <div id="list_empty" class="text-muted" style="display:none;padding:2em 0;">
            <i class="fa fa-info-circle"></i> {{ lang._('Keine Backups vorhanden. Erstelle jetzt eines oder aktiviere die automatische Sicherung.') }}
        </div>

    </div><!-- /#tab-list -->


    <!-- ===================================================================
         TAB 3: EINSTELLUNGEN
         =================================================================== -->
    <div id="tab-settings" class="tab-pane fade">

        <h3>{{ lang._('Automatische Sicherung') }}</h3>
        <p class="text-muted small">
            {{ lang._('Konfigurationen werden lokal auf dieser OPNsense gespeichert unter:') }}
            <code>/var/db/automatisierung/backups/</code>
        </p>

        <table class="table table-condensed table-striped" style="max-width:720px;">
            <tbody>
            <tr>
                <td style="width:44%;"><strong>{{ lang._('Automatische Backups aktivieren') }}</strong></td>
                <td>
                    <input type="checkbox" id="bk_enabled"/>
                    <label for="bk_enabled" class="text-muted"> {{ lang._('Backups werden zum konfigurierten Zeitplan erstellt') }}</label>
                </td>
            </tr>
            <tr>
                <td><strong>{{ lang._('Backup-Zeitplan') }}</strong></td>
                <td>
                    <div class="row">
                        <div class="col-xs-4">
                            <label class="small">{{ lang._('Stunde (0–23)') }}</label>
                            <input type="number" class="form-control input-sm" id="bk_hour" min="0" max="23" value="2"/>
                        </div>
                        <div class="col-xs-4">
                            <label class="small">{{ lang._('Minute (0–59)') }}</label>
                            <input type="number" class="form-control input-sm" id="bk_minute" min="0" max="59" value="0"/>
                        </div>
                        <div class="col-xs-4">
                            <label class="small">{{ lang._('Wochentage') }}</label>
                            <input type="text" class="form-control input-sm" id="bk_days" value="*" placeholder="*"/>
                        </div>
                    </div>
                    <span class="text-muted small">{{ lang._('* = täglich | 1=Mo … 7=So | Bsp: 1,4 = Mo+Do') }}</span>
                </td>
            </tr>
            <tr>
                <td><strong>{{ lang._('Aufbewahrungsdauer (Retention)') }}</strong></td>
                <td>
                    <div class="input-group" style="max-width:200px;">
                        <input type="number" class="form-control input-sm" id="bk_retention" min="1" max="365" value="30"/>
                        <span class="input-group-addon">{{ lang._('Tage') }}</span>
                    </div>
                    <span class="text-muted small">{{ lang._('Backups älter als dieser Wert werden automatisch gelöscht') }}</span>
                </td>
            </tr>
            </tbody>
        </table>

        <h3 style="margin-top:1.5em;">{{ lang._('Backup pro Host') }}</h3>
        <p class="text-muted small">{{ lang._('Lege fest, für welche Hosts automatisch Konfigurationsbackups erstellt werden:') }}</p>

        <table class="table table-condensed table-striped" style="max-width:720px;">
            <thead>
            <tr>
                <th>{{ lang._('Host') }}</th>
                <th>{{ lang._('URL') }}</th>
                <th style="width:7em;">{{ lang._('Backups') }}</th>
                <th style="width:8em;">{{ lang._('Auto-Backup') }}</th>
            </tr>
            </thead>
            <tbody id="bk_host_tbody"></tbody>
        </table>

        <button id="btn_save_bk_settings" class="btn btn-primary btn-sm">
            <i class="fa fa-save"></i> {{ lang._('Einstellungen speichern') }}
        </button>
        <div id="bk_settings_msg" class="alert" style="display:none;margin-top:0.8em;"></div>

    </div><!-- /#tab-settings -->

    </div><!-- /.tab-content -->
</div><!-- /.content-box -->


<!-- ====== Deploy Confirm Modal ====== -->
<div class="modal fade" id="ModalDeploy" tabindex="-1" role="dialog">
    <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header">
                <button type="button" class="close" data-dismiss="modal"><span>&times;</span></button>
                <h4 class="modal-title">
                    <i class="fa fa-exclamation-triangle text-danger"></i>
                    {{ lang._('Backup auf Firewall einspielen') }}
                </h4>
            </div>
            <div class="modal-body" id="deploy_confirm_body"></div>
            <div class="modal-footer">
                <button type="button" class="btn btn-default" data-dismiss="modal">{{ lang._('Abbrechen') }}</button>
                <button type="button" id="btn_confirm_deploy" class="btn btn-danger">
                    <i class="fa fa-upload"></i> {{ lang._('Jetzt einspielen') }}
                </button>
            </div>
        </div>
    </div>
</div>


<style>
.diff-tbl              { width:100%; border-collapse:collapse; table-layout:fixed; }
.diff-tbl col.ln-col   { width:3.5em; }
.diff-tbl col.code-col { width:auto; }
.diff-tbl td           { padding:1px 6px; white-space:pre; overflow:hidden; vertical-align:top; }
.diff-tbl .ln          { color:#bbb; border-right:1px solid #e1e4e8; text-align:right; width:3.5em;
                          user-select:none; font-size:11px; padding-right:8px; }
.diff-tbl .code        { overflow-x:auto; }
.diff-tbl tr.d-ctx .code  { color:#24292e; }
.diff-tbl tr.d-add         { background:#e6ffed; }
.diff-tbl tr.d-add .ln     { background:#cdffd8; color:#97c083; }
.diff-tbl tr.d-add .code   { color:#22863a; }
.diff-tbl tr.d-del         { background:#ffeef0; }
.diff-tbl tr.d-del .ln     { background:#ffdce0; color:#c08080; }
.diff-tbl tr.d-del .code   { color:#b31d28; }
.diff-tbl tr.d-hunk        { background:#f1f8ff; }
.diff-tbl tr.d-hunk .ln    { background:#dbedff; color:#a0b4cc; }
.diff-tbl tr.d-hunk .code  { color:#005cc5; font-style:italic; }
.diff-tbl tr.d-hdr-del .code { color:#b31d28; background:#ffeef0; }
.diff-tbl tr.d-hdr-add .code { color:#22863a; background:#e6ffed; }
#backup_list_tbody td { vertical-align:middle; }
.bk-inline-btn { padding:1px 6px; font-size:0.8em; margin-right:2px; }
</style>


<script>
//<![CDATA[

    // CSRF-Setup — muss VOR allen POST-Requests laufen
    (function() {
        var csrfToken = "{{ csrf_token }}";
        if (csrfToken) {
            $.ajaxSetup({"beforeSend": function(xhr) { xhr.setRequestHeader("X-CSRFToken", csrfToken); }});
        }
    })();

/* =========================================================
   State
   ========================================================= */
var cmpUuid      = '';
var listUuid     = '';
var allBackups   = [];
var allBackupsList = [];
var selectedRows = [];
var pendingDeploy = null;

/* =========================================================
   Utilities
   ========================================================= */
function esc(s) {
    return String(s || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}
function showAlert($el, type, msg) {
    $el.removeClass('alert-success alert-danger alert-info alert-warning')
       .addClass('alert-' + type).html(msg).show();
    setTimeout(function() { $el.fadeOut(); }, 5000);
}

/* =========================================================
   Load hosts into selects and settings table
   ========================================================= */
function loadHosts(cb) {
    $.get('/api/automatisierung/backup/getHosts', function(resp) {
        if (!resp.hosts) return;
        var hosts = resp.hosts;
        var $c = $('#cmp_host_select').find('option:not(:first)').remove().end();
        var $l = $('#list_host_select').find('option:not(:first)').remove().end();
        var $t = $('#bk_host_tbody').empty();

        $.each(hosts, function(i, h) {
            var label = esc(h.name) + ' (' + esc(h.url) + ')';
            $c.append('<option value="' + esc(h.uuid) + '">' + label + '</option>');
            $l.append('<option value="' + esc(h.uuid) + '">' + label + '</option>');

            var cnt = h.backup_count ? '<span class="badge">' + h.backup_count + '</span>' : '—';
            $t.append(
                '<tr>' +
                '<td>' + esc(h.name) + '</td>' +
                '<td><small class="text-muted">' + esc(h.url) + '</small></td>' +
                '<td id="cnt_' + esc(h.uuid) + '">' + cnt + '</td>' +
                '<td><input type="checkbox" class="bk_host_cb" data-uuid="' + esc(h.uuid) + '"' +
                     (h.backup_enabled === '1' ? ' checked' : '') + '/></td>' +
                '</tr>'
            );
        });
        $c.selectpicker('refresh');
        $l.selectpicker('refresh');
        if (cb) cb(hosts);
    });
}

/* =========================================================
   Compare Tab – Host selection
   ========================================================= */
$('#cmp_host_select').on('change', function() {
    cmpUuid = $(this).val();
    $('#btn_cmp_backup_now').prop('disabled', !cmpUuid);
    resetDiffArea();
    if (cmpUuid) {
        $('#cmp_empty_state').hide();
        $('#cmp_section').hide();
        fetchBackupsForCompare();
    } else {
        $('#cmp_section').hide();
        $('#cmp_empty_state').show();
    }
});

function fetchBackupsForCompare() {
    $.get('/api/automatisierung/backup/listBackups', {uuid: cmpUuid}, function(resp) {
        allBackups = resp.backups || [];
        populateCmpSelects();
        $('#cmp_section').toggle(allBackups.length > 0);
        if (allBackups.length === 0) {
            $('#cmp_empty_state').html('<i class="fa fa-info-circle"></i> Noch keine Backups für diesen Host. Erstelle jetzt eines.').show();
        }
    });
}

function populateCmpSelects(preA, preB) {
    var $a = $('#cmp_file_a').find('option:not(:first)').remove().end();
    var $b = $('#cmp_file_b').find('option:not(:first)').remove().end();

    $.each(allBackups, function(i, bk) {
        var ts   = bk.timestamp_fmt || bk.filename;
        var user = bk.revision_user ? ' (' + bk.revision_user + ')' : '';
        var desc = bk.description   ? ' – ' + bk.description     : '';
        var label = ts + user + desc;
        var opt = '<option value="' + esc(bk.filename) + '" ' +
                  'data-ts="' + esc(ts) + '" ' +
                  'data-user="' + esc(bk.revision_user || '') + '" ' +
                  'data-desc="' + esc(bk.description || '') + '">' +
                  esc(label) + '</option>';
        $a.append(opt);
        $b.append(opt);
    });

    $a.val(preA || (allBackups.length >= 2 ? allBackups[1].filename : ''));
    $b.val(preB || (allBackups.length >= 1 ? allBackups[0].filename : ''));
    $a.selectpicker('refresh');
    $b.selectpicker('refresh');
    onCmpChange();
}

function onCmpChange() {
    var fa = $('#cmp_file_a').val(), fb = $('#cmp_file_b').val();
    $('#btn_run_compare').prop('disabled', !fa || !fb || fa === fb);
    updateSideActions('a', fa);
    updateSideActions('b', fb);
}

function updateSideActions(side, filename) {
    var $act = $('#actions_' + side);
    if (!filename) { $act.hide(); return; }
    var bk = allBackups.find(function(b) { return b.filename === filename; }) || {};
    var meta = [];
    if (bk.revision_user) meta.push(bk.revision_user);
    if (bk.description)   meta.push(bk.description);
    $('#meta_' + side).text(meta.join(' – '));
    var dlUrl = '/api/automatisierung/backup/downloadFile?uuid=' +
                encodeURIComponent(cmpUuid) + '&filename=' + encodeURIComponent(filename);
    $('#btn_download_' + side).attr('href', dlUrl);
    $act.show();
}

$('#cmp_file_a, #cmp_file_b').on('change', function() { onCmpChange(); resetDiffArea(); });

$('#btn_restore_a').on('click', function() { confirmDeploy($('#cmp_file_a').val()); });
$('#btn_restore_b').on('click', function() { confirmDeploy($('#cmp_file_b').val()); });
$('#btn_delete_a').on('click', function() { deleteFileCmp($('#cmp_file_a').val()); });
$('#btn_delete_b').on('click', function() { deleteFileCmp($('#cmp_file_b').val()); });

function confirmDeploy(filename) {
    var bk   = allBackups.find(function(b) { return b.filename === filename; }) || {};
    var ts   = bk.timestamp_fmt || filename;
    var host = $('#cmp_host_select option:selected').text();
    pendingDeploy = {uuid: cmpUuid, filename: filename};
    $('#deploy_confirm_body').html(
        '<p>Backup vom <strong>' + esc(ts) + '</strong> auf <strong>' + esc(host) + '</strong> einspielen?</p>' +
        '<div class="alert alert-danger" style="margin-bottom:0;">' +
        '<i class="fa fa-exclamation-triangle"></i> <strong>Achtung:</strong> ' +
        'Die aktuelle Konfiguration wird überschrieben. Die Firewall startet danach neu.</div>'
    );
    $('#ModalDeploy').modal('show');
}

function deleteFileCmp(filename) {
    if (!filename || !confirm('Backup "' + filename + '" wirklich löschen?')) return;
    $.ajax({
        url: '/api/automatisierung/backup/deleteBackup', method: 'POST',
        data: {uuid: cmpUuid, filename: filename},
        success: function(resp) {
            showAlert($('#cmp_action_msg'), resp.result === 'ok' ? 'success' : 'danger',
                '<i class="fa fa-' + (resp.result === 'ok' ? 'check' : 'times') + '-circle"></i> ' + esc(resp.message));
            if (resp.result === 'ok') { fetchBackupsForCompare(); resetDiffArea(); }
        }
    });
}

/* =========================================================
   Backup now
   ========================================================= */
$('#btn_cmp_backup_now').on('click', function() {
    if (!cmpUuid) return;
    var $btn = $(this).prop('disabled', true).html('<i class="fa fa-spinner fa-spin"></i> ...');
    $.ajax({
        url: '/api/automatisierung/backup/triggerBackup', method: 'POST', data: {uuid: cmpUuid},
        success: function(resp) {
            showAlert($('#cmp_action_msg'), resp.result === 'ok' ? 'success' : 'danger',
                '<i class="fa fa-' + (resp.result === 'ok' ? 'check' : 'times') + '-circle"></i> ' + esc(resp.message));
            if (resp.result === 'ok') fetchBackupsForCompare();
        },
        complete: function() { $btn.prop('disabled', false).html('<i class="fa fa-camera"></i> Backup jetzt erstellen'); }
    });
});

/* =========================================================
   Deploy confirm modal
   ========================================================= */
$('#btn_confirm_deploy').on('click', function() {
    if (!pendingDeploy) return;
    $('#ModalDeploy').modal('hide');
    showAlert($('#cmp_action_msg'), 'info', '<i class="fa fa-spinner fa-spin"></i> Deploye Konfiguration...');
    $.ajax({
        url: '/api/automatisierung/backup/deployBackup', method: 'POST', data: pendingDeploy,
        success: function(resp) {
            showAlert($('#cmp_action_msg'), resp.result === 'ok' ? 'success' : 'danger',
                '<i class="fa fa-' + (resp.result === 'ok' ? 'check' : 'times') + '-circle"></i> ' + esc(resp.message));
        }
    });
});

/* =========================================================
   DIFF ENGINE
   ========================================================= */
$('#btn_run_compare').on('click', runCompare);

function resetDiffArea() {
    $('#diff_wrap, #diff_identical').hide();
    $('#diff_stats').html('');
}

function runCompare() {
    var fa = $('#cmp_file_a').val();
    var fb = $('#cmp_file_b').val();
    if (!fa || !fb || !cmpUuid) return;

    resetDiffArea();
    $('#diff_loading').show();

    $.get('/api/automatisierung/backup/compareBackups',
          {uuid: cmpUuid, file_a: fa, file_b: fb}, function(resp) {
        $('#diff_loading').hide();
        if (resp.result !== 'ok') {
            showAlert($('#cmp_action_msg'), 'danger', 'Fehler: ' + esc(resp.message || 'Unbekannt'));
            return;
        }
        var linesA = resp.content_a.split('\n');
        var linesB = resp.content_b.split('\n');
        var patch  = computeDiff(linesA, linesB);

        if (!patch.hunks.length) { $('#diff_identical').show(); return; }
        renderDiff(patch, linesA, linesB, resp);
    });
}

function renderDiff(patch, linesA, linesB, resp) {
    var added = 0, removed = 0;
    var html = '<table class="diff-tbl"><colgroup><col class="ln-col"/><col class="ln-col"/><col class="code-col"/></colgroup><tbody>';

    html += '<tr class="d-hdr-del"><td class="ln"></td><td class="ln"></td>' +
            '<td class="code">--- ' + esc(resp.file_a) + (resp.mtime_a ? '   ' + esc(resp.mtime_a) : '') + '</td></tr>';
    html += '<tr class="d-hdr-add"><td class="ln"></td><td class="ln"></td>' +
            '<td class="code">+++ ' + esc(resp.file_b) + (resp.mtime_b ? '   ' + esc(resp.mtime_b) : '') + '</td></tr>';

    for (var h = 0; h < patch.hunks.length; h++) {
        var hunk = patch.hunks[h];
        html += '<tr class="d-hunk"><td class="ln">...</td><td class="ln">...</td>' +
                '<td class="code">@@ -' + hunk.oldStart + ',' + hunk.oldLines +
                ' +' + hunk.newStart + ',' + hunk.newLines + ' @@</td></tr>';

        var ol = hunk.oldStart, nl = hunk.newStart;
        for (var l = 0; l < hunk.lines.length; l++) {
            var line = hunk.lines[l];
            var type = line[0], text = line.slice(1);
            var cls = type === '-' ? 'd-del' : type === '+' ? 'd-add' : 'd-ctx';
            var lnA = type !== '+' ? ol++ : '';
            var lnB = type !== '-' ? nl++ : '';
            if (type === '-') removed++;
            if (type === '+') added++;
            html += '<tr class="' + cls + '"><td class="ln">' + lnA + '</td><td class="ln">' + lnB + '</td>' +
                    '<td class="code">' + esc(text) + '</td></tr>';
        }
    }
    html += '</tbody></table>';

    $('#diff_stats').html(
        '<span style="color:#22863a;font-weight:600;">+' + added + '</span>&nbsp;' +
        '<span style="color:#b31d28;font-weight:600;">−' + removed + '</span>&nbsp;' +
        '<span class="text-muted">' + patch.hunks.length + ' Block' + (patch.hunks.length !== 1 ? 'e' : '') + '</span>'
    );
    $('#diff_output').html(html);
    $('#diff_wrap').show();
}

function computeDiff(oldL, newL) {
    var lcs = buildLCS(oldL, newL);
    return {hunks: buildHunks(oldL, newL, lcs, 3)};
}

function buildLCS(a, b) {
    if (a.length > 3000 || b.length > 3000) return buildGreedyLCS(a, b);
    var n = a.length, m = b.length;
    var dp = [];
    for (var i = 0; i <= n; i++) dp[i] = new Int32Array(m + 1);
    for (var i = 1; i <= n; i++)
        for (var j = 1; j <= m; j++)
            dp[i][j] = a[i-1] === b[j-1] ? dp[i-1][j-1] + 1 : Math.max(dp[i-1][j], dp[i][j-1]);
    var res = [], i = n, j = m;
    while (i > 0 && j > 0) {
        if (a[i-1] === b[j-1]) { res.unshift([i-1, j-1]); i--; j--; }
        else if (dp[i-1][j] >= dp[i][j-1]) i--;
        else j--;
    }
    return res;
}

function buildGreedyLCS(a, b) {
    var bMap = {}, res = [], jLast = 0;
    for (var j = 0; j < b.length; j++) if (!bMap[b[j]]) bMap[b[j]] = j;
    for (var i = 0; i < a.length; i++)
        if (bMap[a[i]] !== undefined && bMap[a[i]] >= jLast) { res.push([i, bMap[a[i]]]); jLast = bMap[a[i]] + 1; }
    return res;
}

function buildHunks(oldL, newL, lcs, ctx) {
    var edits = [], pi = 0, pj = 0;
    for (var k = 0; k < lcs.length; k++) {
        while (pi < lcs[k][0]) edits.push({t: '-', oi: pi++, nj: -1});
        while (pj < lcs[k][1]) edits.push({t: '+', oi: -1, nj: pj++});
        edits.push({t: '=', oi: pi++, nj: pj++});
    }
    while (pi < oldL.length) edits.push({t: '-', oi: pi++, nj: -1});
    while (pj < newL.length) edits.push({t: '+', oi: -1, nj: pj++});

    var groups = [], grp = null, lastC = -9999;
    for (var i = 0; i < edits.length; i++) {
        var chg = edits[i].t !== '=';
        if (chg || i - lastC <= ctx) {
            if (grp === null || i - lastC > ctx * 2 + 2) { grp = []; groups.push(grp); }
            if (chg) lastC = i;
        }
        if (grp !== null && (chg || Math.abs(i - lastC) <= ctx)) grp.push(edits[i]);
    }

    return groups.map(function(g) {
        var lines = [], oc = 0, nc = 0, firstOi = -1, firstNj = -1;
        g.forEach(function(e) {
            if (e.oi >= 0 && firstOi < 0) firstOi = e.oi;
            if (e.nj >= 0 && firstNj < 0) firstNj = e.nj;
            if (e.t === '-') { lines.push('-' + oldL[e.oi]); oc++; }
            else if (e.t === '+') { lines.push('+' + newL[e.nj]); nc++; }
            else { lines.push(' ' + oldL[e.oi]); oc++; nc++; }
        });
        return {oldStart: firstOi >= 0 ? firstOi + 1 : 1, oldLines: oc,
                newStart: firstNj >= 0 ? firstNj + 1 : 1, newLines: nc, lines: lines};
    }).filter(function(h) { return h.lines.some(function(l) { return l[0] !== '' && l[0] !== ' '; }); });
}

/* =========================================================
   List Tab
   ========================================================= */
$('#list_host_select').on('change', function() {
    listUuid = $(this).val();
    var has = !!listUuid;
    $('#btn_list_backup_now,#btn_list_refresh,#btn_list_retention').prop('disabled', !has);
    if (has) loadBackupList();
    else { $('#list_table_wrap,#list_empty').hide(); }
    selectedRows = [];
    updateListBtns();
});

function loadBackupList() {
    if (!listUuid) return;
    $('#list_table_wrap,#list_empty').hide();
    selectedRows = [];
    updateListBtns();
    $.get('/api/automatisierung/backup/listBackups', {uuid: listUuid}, function(resp) {
        allBackupsList = resp.backups || [];
        var $tbody = $('#backup_list_tbody').empty();
        if (!allBackupsList.length) { $('#list_empty').show(); return; }
        allBackupsList.forEach(function(bk) {
            var ts   = bk.timestamp_fmt || bk.filename;
            var desc = bk.description || '—';
            var user = bk.revision_user || '—';
            var dlUrl = '/api/automatisierung/backup/downloadFile?uuid=' +
                        encodeURIComponent(listUuid) + '&filename=' + encodeURIComponent(bk.filename);
            $tbody.append(
                '<tr><td><input type="checkbox" class="row_chk" data-fn="' + esc(bk.filename) + '"/></td>' +
                '<td style="font-family:monospace;font-size:0.87em;white-space:nowrap;">' + esc(ts) + '</td>' +
                '<td style="font-size:0.88em;">' + esc(desc) + '</td>' +
                '<td><small>' + esc(user) + '</small></td>' +
                '<td><small>' + esc(bk.size) + '</small></td>' +
                '<td style="white-space:nowrap;">' +
                  '<button class="btn btn-xs btn-default bk-inline-btn btn-lr" data-fn="' + esc(bk.filename) + '" data-ts="' + esc(ts) + '" title="Einspielen"><i class="fa fa-reply"></i></button>' +
                  '<a href="' + dlUrl + '" class="btn btn-xs btn-default bk-inline-btn" title="Herunterladen" download><i class="fa fa-download"></i></a>' +
                  '<button class="btn btn-xs btn-danger bk-inline-btn btn-ld" data-fn="' + esc(bk.filename) + '" title="Löschen"><i class="fa fa-trash-o"></i></button>' +
                '</td></tr>'
            );
        });
        $('#list_table_wrap').show();
    });
}

$(document).on('change', '.row_chk', function() {
    var fn = $(this).data('fn');
    if ($(this).is(':checked')) { if (selectedRows.indexOf(fn) < 0) selectedRows.push(fn); }
    else { selectedRows = selectedRows.filter(function(f) { return f !== fn; }); }
    updateListBtns();
    $('#sel_count').text(selectedRows.length ? selectedRows.length + ' ausgewählt' : '');
});

$('#chk_all').on('change', function() {
    var c = $(this).is(':checked'); selectedRows = [];
    $('.row_chk').each(function() { $(this).prop('checked', c); if (c) selectedRows.push($(this).data('fn')); });
    updateListBtns();
    $('#sel_count').text(selectedRows.length ? selectedRows.length + ' ausgewählt' : '');
});

function updateListBtns() {
    $('#btn_compare_checked').prop('disabled', selectedRows.length !== 2);
    $('#btn_delete_checked').prop('disabled', selectedRows.length === 0);
}

$('#btn_list_refresh').on('click', loadBackupList);

$('#btn_list_backup_now').on('click', function() {
    if (!listUuid) return;
    var $btn = $(this).prop('disabled', true).html('<i class="fa fa-spinner fa-spin"></i>');
    $.ajax({
        url: '/api/automatisierung/backup/triggerBackup', method: 'POST', data: {uuid: listUuid},
        success: function(resp) {
            showAlert($('#list_msg'), resp.result === 'ok' ? 'success' : 'danger',
                '<i class="fa fa-' + (resp.result === 'ok' ? 'check' : 'times') + '-circle"></i> ' + esc(resp.message));
            if (resp.result === 'ok') loadBackupList();
        },
        complete: function() { $btn.prop('disabled', false).html('<i class="fa fa-camera"></i> Backup erstellen'); }
    });
});

$('#btn_list_retention').on('click', function() {
    $.ajax({
        url: '/api/automatisierung/backup/runRetention', method: 'POST', data: {uuid: listUuid},
        success: function(resp) {
            showAlert($('#list_msg'), 'info', '<i class="fa fa-info-circle"></i> ' + esc(resp.message));
            loadBackupList();
        }
    });
});

$('#btn_compare_checked').on('click', function() {
    if (selectedRows.length !== 2) return;
    cmpUuid = listUuid;
    $('#cmp_host_select').val(listUuid).selectpicker('refresh');
    $('a[href="#tab-compare"]').tab('show');
    setTimeout(function() {
        fetchBackupsForCompare();
        var fnA = selectedRows[1], fnB = selectedRows[0];
        setTimeout(function() {
            populateCmpSelects(fnA, fnB);
            setTimeout(runCompare, 200);
        }, 600);
    }, 200);
});

$('#btn_delete_checked').on('click', function() {
    if (!confirm(selectedRows.length + ' Backup(s) wirklich löschen?')) return;
    var done = 0, total = selectedRows.length;
    selectedRows.forEach(function(fn) {
        $.ajax({
            url: '/api/automatisierung/backup/deleteBackup', method: 'POST',
            data: {uuid: listUuid, filename: fn},
            complete: function() {
                if (++done === total) { loadBackupList(); selectedRows = []; updateListBtns(); }
            }
        });
    });
});

$(document).on('click', '.btn-lr', function() {
    var fn = $(this).data('fn'), ts = $(this).data('ts');
    var host = $('#list_host_select option:selected').text();
    pendingDeploy = {uuid: listUuid, filename: fn};
    $('#deploy_confirm_body').html(
        '<p>Backup vom <strong>' + esc(ts) + '</strong> auf <strong>' + esc(host) + '</strong> einspielen?</p>' +
        '<div class="alert alert-danger" style="margin-bottom:0;"><i class="fa fa-exclamation-triangle"></i> ' +
        '<strong>Achtung:</strong> Die aktuelle Konfiguration wird überschrieben. Die Firewall startet danach neu.</div>'
    );
    $('#ModalDeploy').modal('show');
});

$(document).on('click', '.btn-ld', function() {
    var fn = $(this).data('fn');
    if (!confirm('Backup "' + fn + '" wirklich löschen?')) return;
    $.ajax({
        url: '/api/automatisierung/backup/deleteBackup', method: 'POST',
        data: {uuid: listUuid, filename: fn},
        success: function(resp) {
            showAlert($('#list_msg'), resp.result === 'ok' ? 'success' : 'danger',
                '<i class="fa fa-' + (resp.result === 'ok' ? 'check' : 'times') + '-circle"></i> ' + esc(resp.message));
            if (resp.result === 'ok') loadBackupList();
        }
    });
});

/* =========================================================
   Settings Tab
   ========================================================= */
function loadBackupSettings() {
    $.get('/api/automatisierung/backup/getSettings', function(resp) {
        if (!resp.backup) return;
        var b = resp.backup;
        $('#bk_enabled').prop('checked', b.enabled === '1');
        $('#bk_hour').val(b.hour || 2);
        $('#bk_minute').val(b.minute || 0);
        $('#bk_days').val(b.days || '*');
        $('#bk_retention').val(b.retention_days || 30);
    });
}

$('#btn_save_bk_settings').on('click', function() {
    var hosts = {};
    $('.bk_host_cb').each(function() { hosts[$(this).data('uuid')] = $(this).is(':checked') ? '1' : '0'; });
    $.ajax({
        url: '/api/automatisierung/backup/setSettings', method: 'POST',
        data: {backup: {
            enabled:        $('#bk_enabled').is(':checked') ? '1' : '0',
            hour:           $('#bk_hour').val(),
            minute:         $('#bk_minute').val(),
            days:           $('#bk_days').val(),
            retention_days: $('#bk_retention').val(),
            hosts:          hosts,
        }},
        success: function(resp) {
            var ok = resp.result === 'saved';
            showAlert($('#bk_settings_msg'), ok ? 'success' : 'danger',
                '<i class="fa fa-' + (ok ? 'check' : 'times') + '-circle"></i> ' +
                esc(resp.message || JSON.stringify(resp.validations || {})));
        }
    });
});

/* =========================================================
   Init
   ========================================================= */
$(document).ready(function() {
    loadHosts();
    loadBackupSettings();
});

//]]>
</script>
