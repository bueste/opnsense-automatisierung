<div class="content-box" style="padding-bottom:1.5em;">

    <div class="col-xs-12">
        <h1><i class="fa fa-archive"></i> {{ lang._('Automation – Configuration Backup') }}</h1>
        <hr/>
    </div>

    <!-- ========== TABS ========== -->
    <div class="col-xs-12">
        <ul class="nav nav-tabs" id="backupMainTabs" role="tablist">
            <li class="active"><a href="#tab-compare" data-toggle="tab"><i class="fa fa-code-fork"></i> {{ lang._('Compare backups') }}</a></li>
            <li><a href="#tab-list" data-toggle="tab"><i class="fa fa-list"></i> {{ lang._('All Backups') }}</a></li>
            <li><a href="#tab-za" data-toggle="tab"><i class="fa fa-shield"></i> {{ lang._('Zenarmor Backup') }}</a></li>
            <li><a href="#tab-settings" data-toggle="tab"><i class="fa fa-cog"></i> {{ lang._('Settings') }}</a></li>
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
                <input type="text" id="cmp_comment" class="form-control input-sm"
                       placeholder="{{ lang._('Comment (optional)') }}" maxlength="120"
                       style="max-width:240px;margin-bottom:4px;"/>
                <button id="btn_cmp_backup_now" class="btn btn-primary btn-sm" disabled>
                    <i class="fa fa-camera"></i> {{ lang._('Create backup now') }}
                </button>
            </div>
        </div>

        <hr style="margin:4px 0 14px 0;"/>

        <div id="cmp_section" style="display:none;">

            <h4 style="font-weight:600;margin:0 0 10px 0;">{{ lang._('Backups (compare)') }}</h4>

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
                        <button class="btn btn-xs btn-default" id="btn_restore_a" title="{{ lang._('Restore this configuration to the firewall') }}"><i class="fa fa-reply"></i></button>
                        <button class="btn btn-xs btn-default" id="btn_delete_a" title="{{ lang._('Delete this backup') }}"><i class="fa fa-trash-o"></i></button>
                        <a id="btn_download_a" href="#" class="btn btn-xs btn-default" title="{{ lang._('Download') }}" download><i class="fa fa-download"></i></a>
                        <span id="meta_a" class="text-muted" style="margin-left:4px;font-size:0.8em;"></span>
                    </div>
                </div>
                <div class="col-xs-12 col-sm-6" style="padding-left:3px;">
                    <div id="actions_b" style="display:none;line-height:2.2;">
                        <button class="btn btn-xs btn-default" id="btn_restore_b" title="{{ lang._('Restore this configuration to the firewall') }}"><i class="fa fa-reply"></i></button>
                        <button class="btn btn-xs btn-default" id="btn_delete_b" title="{{ lang._('Delete this backup') }}"><i class="fa fa-trash-o"></i></button>
                        <a id="btn_download_b" href="#" class="btn btn-xs btn-default" title="{{ lang._('Download') }}" download><i class="fa fa-download"></i></a>
                        <span id="meta_b" class="text-muted" style="margin-left:4px;font-size:0.8em;"></span>
                    </div>
                </div>
            </div>

            <div style="margin-bottom:14px;">
                <button id="btn_run_compare" class="btn btn-default btn-sm" disabled>
                    <i class="fa fa-search"></i> {{ lang._('Compare versions') }}
                </button>
            </div>

            <div id="diff_loading" style="display:none;padding:2em 0;text-align:center;">
                <i class="fa fa-spinner fa-spin fa-2x"></i>
                <p>{{ lang._('Loading and comparing configurations...') }}</p>
            </div>

            <div id="diff_wrap" style="display:none;">
                <div style="padding:4px 0 6px 0;font-size:0.9em;color:#333;">
                    <strong>{{ lang._('Changes between selected versions') }}</strong>
                    <span id="diff_stats" style="margin-left:12px;font-size:0.9em;"></span>
                </div>
                <div id="diff_output" style="font-family:'SFMono-Regular',Consolas,'Liberation Mono',Menlo,monospace;font-size:12.5px;line-height:1.5;border:1px solid #d1d5da;border-radius:4px;overflow:auto;max-height:560px;background:#fff;padding:0;"></div>
            </div>

            <div id="diff_identical" class="text-success" style="display:none;padding:1em 0;">
                <i class="fa fa-check-circle"></i> {{ lang._('The two configurations are identical – no differences found.') }}
            </div>

            <div id="cmp_action_msg" class="alert" style="display:none;margin-top:0.8em;"></div>

        </div>

        <div id="cmp_empty_state" class="text-muted" style="padding:2em 0;">
            <i class="fa fa-arrow-up"></i> {{ lang._('Please select a host above.') }}
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
                <input type="text" id="list_comment" class="form-control input-sm"
                       placeholder="{{ lang._('Comment (optional)') }}" maxlength="120"
                       style="max-width:240px;margin-bottom:4px;"/>
                <button id="btn_list_backup_now" class="btn btn-primary btn-sm" disabled>
                    <i class="fa fa-camera"></i> {{ lang._('Create backup') }}
                </button>
                <button id="btn_list_refresh" class="btn btn-default btn-sm" disabled>
                    <i class="fa fa-refresh"></i> {{ lang._('Aktualisieren') }}
                </button>
                <button id="btn_list_retention" class="btn btn-default btn-sm" disabled title="{{ lang._('Remove old backups according to retention setting') }}">
                    <i class="fa fa-trash-o"></i> {{ lang._('Apply retention') }}
                </button>
            </div>
        </div>

        <div id="list_msg" class="alert" style="display:none;"></div>

        <div id="list_table_wrap" style="display:none;">
            <table class="table table-condensed table-hover table-striped">
                <thead>
                <tr>
                    <th style="width:2.5em;"><input type="checkbox" id="chk_all"/></th>
                    <th>{{ lang._('Timestamp') }}</th>
                    <th>{{ lang._('Description / Revision') }}</th>
                    <th>{{ lang._('User') }}</th>
                    <th style="width:5em;">{{ lang._('Size') }}</th>
                    <th style="width:10em;">{{ lang._('Actions') }}</th>
                </tr>
                </thead>
                <tbody id="backup_list_tbody"></tbody>
            </table>
            <div style="margin-top:6px;display:flex;align-items:center;gap:8px;">
                <button id="btn_compare_checked" class="btn btn-info btn-xs" disabled>
                    <i class="fa fa-code-fork"></i> {{ lang._('Compare selected (choose 2)') }}
                </button>
                <button id="btn_delete_checked" class="btn btn-danger btn-xs" disabled>
                    <i class="fa fa-trash-o"></i> {{ lang._('Delete selection') }}
                </button>
                <span id="sel_count" class="text-muted" style="font-size:0.88em;"></span>
            </div>
        </div>

        <div id="list_empty" class="text-muted" style="display:none;padding:2em 0;">
            <i class="fa fa-info-circle"></i> {{ lang._('No backups available. Create one now or enable automatic backup.') }}
        </div>

    </div><!-- /#tab-list -->


    <!-- ===================================================================
         TAB 3: ZENARMOR BACKUP
         =================================================================== -->
    <div id="tab-za" class="tab-pane fade">

        <div class="row" style="margin-bottom:1em;">
            <div class="col-xs-12 col-sm-5">
                <label>{{ lang._('Host') }}</label>
                <select id="za_host_select" class="form-control selectpicker" data-live-search="true">
                    <option value="">— Host wählen —</option>
                </select>
            </div>
            <div class="col-xs-12 col-sm-7" style="padding-top:1.6em;">
                <button id="btn_za_backup_now" class="btn btn-primary btn-sm" disabled>
                    <i class="fa fa-shield"></i> {{ lang._('Create ZA backup now') }}
                </button>
                <button id="btn_za_refresh" class="btn btn-default btn-sm" disabled>
                    <i class="fa fa-refresh"></i> {{ lang._('Aktualisieren') }}
                </button>
            </div>
        </div>

        <div class="alert alert-info" style="max-width:720px;">
            <i class="fa fa-info-circle"></i>
            {{ lang._('Zenarmor backups are created as .gz files on the remote host and stored locally. The API user needs Zenarmor backup permissions.') }}
        </div>

        <div id="za_msg" class="alert" style="display:none;max-width:720px;"></div>

        <div id="za_table_wrap" style="display:none;">
            <table class="table table-condensed table-hover table-striped" style="max-width:900px;">
                <thead>
                <tr>
                    <th>{{ lang._('Timestamp') }}</th>
                    <th>{{ lang._('Filename') }}</th>
                    <th style="width:5em;">{{ lang._('Size') }}</th>
                    <th style="width:7em;">{{ lang._('Actions') }}</th>
                </tr>
                </thead>
                <tbody id="za_list_tbody"></tbody>
            </table>
        </div>

        <div id="za_empty" class="text-muted" style="display:none;padding:2em 0;">
            <i class="fa fa-info-circle"></i> {{ lang._('No ZA backups available. Create one now.') }}
        </div>

        <div id="za_host_hint" class="text-muted" style="padding:2em 0;">
            <i class="fa fa-arrow-up"></i> {{ lang._('Please select a host above.') }}
        </div>

    </div><!-- /#tab-za -->


    <!-- ===================================================================
         TAB 4: EINSTELLUNGEN
         =================================================================== -->
    <div id="tab-settings" class="tab-pane fade">

        <h3>{{ lang._('Automatic Backup') }}</h3>
        <p class="text-muted small">
            {{ lang._('Configurations are stored locally on this OPNsense under:') }}
            <code>/var/db/automatisierung/backups/</code>
        </p>

        <table class="table table-condensed table-striped" style="max-width:720px;">
            <tbody>
            <tr>
                <td style="width:44%;"><strong>{{ lang._('Enable automatic backups') }}</strong></td>
                <td>
                    <input type="checkbox" id="bk_enabled"/>
                    <label for="bk_enabled" class="text-muted"> {{ lang._('Backups are created according to the configured schedule') }}</label>
                </td>
            </tr>
            <tr>
                <td><strong>{{ lang._('Backup schedule') }}</strong></td>
                <td>
                    <div class="row">
                        <div class="col-xs-4">
                            <label class="small">{{ lang._('Hour (0–23)') }}</label>
                            <input type="number" class="form-control input-sm" id="bk_hour" min="0" max="23" value="2"/>
                        </div>
                        <div class="col-xs-4">
                            <label class="small">{{ lang._('Minute (0–59)') }}</label>
                            <input type="number" class="form-control input-sm" id="bk_minute" min="0" max="59" value="0"/>
                        </div>
                        <div class="col-xs-4">
                            <label class="small">{{ lang._('Weekdays') }}</label>
                            <input type="text" class="form-control input-sm" id="bk_days" value="*" placeholder="*"/>
                        </div>
                    </div>
                    <span class="text-muted small">{{ lang._('* = daily | 1=Mon … 7=Sun | Ex: 1,4 = Mon+Thu') }}</span>
                </td>
            </tr>
            <tr>
                <td><strong>{{ lang._('Retention period') }}</strong></td>
                <td>
                    <div class="input-group" style="max-width:200px;">
                        <input type="number" class="form-control input-sm" id="bk_retention" min="1" max="365" value="30"/>
                        <span class="input-group-addon">{{ lang._('Days') }}</span>
                    </div>
                    <span class="text-muted small">{{ lang._('Backups older than this value are automatically deleted') }}</span>
                </td>
            </tr>
            </tbody>
        </table>

        <h3 style="margin-top:1.5em;">{{ lang._('Backup per host') }}</h3>
        <p class="text-muted small">{{ lang._('Define for which hosts configuration backups are automatically created:') }}</p>

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
            <i class="fa fa-save"></i> {{ lang._('Save settings') }}
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
                    {{ lang._('Restore backup to firewall') }}
                </h4>
            </div>
            <div class="modal-body" id="deploy_confirm_body"></div>
            <div class="modal-footer">
                <button type="button" class="btn btn-default" data-dismiss="modal">{{ lang._('Cancel') }}</button>
                <button type="button" id="btn_confirm_deploy" class="btn btn-danger">
                    <i class="fa fa-upload"></i> {{ lang._('Restore now') }}
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
        var $z = $('#za_host_select').find('option:not(:first)').remove().end();
        var $t = $('#bk_host_tbody').empty();

        $.each(hosts, function(i, h) {
            var label = esc(h.name) + ' (' + esc(h.url) + ')';
            $c.append('<option value="' + esc(h.uuid) + '">' + label + '</option>');
            $l.append('<option value="' + esc(h.uuid) + '">' + label + '</option>');
            $z.append('<option value="' + esc(h.uuid) + '">' + label + '</option>');

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
        $z.selectpicker('refresh');
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
        url: '/api/automatisierung/backup/triggerBackup', method: 'POST', data: {uuid: cmpUuid, comment: $('#cmp_comment').val()},
        success: function(resp) {
            var type = resp.result === 'ok' ? (resp.filename ? 'success' : 'info') : 'danger';
            var icon = resp.result === 'ok' ? (resp.filename ? 'check' : 'info') : 'times';
            showAlert($('#cmp_action_msg'), type, '<i class="fa fa-' + icon + '-circle"></i> ' + esc(resp.message));
            if (resp.result === 'ok' && resp.filename) fetchBackupsForCompare();
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
        if (resp.identical) { $('#diff_identical').show(); return; }
        renderUnifiedDiff(resp);
    });
}

/**
 * Parse and render the server-side unified diff (diff -u output).
 * This handles XML correctly because the server's diff utility uses
 * a proper LCS that understands duplicate lines.
 */
function renderUnifiedDiff(resp) {
    var rawLines = (resp.unified_diff || '').split('\n');
    var added = 0, removed = 0, hunks = 0;
    var ol = 1, nl = 1;

    var html = '<table class="diff-tbl">' +
               '<colgroup><col class="ln-col"/><col class="ln-col"/><col class="code-col"/></colgroup>' +
               '<tbody>';

    // Always escape file_a/file_b from the API before inserting into innerHTML.
    html += '<tr class="d-hdr-del"><td class="ln"></td><td class="ln"></td>' +
            '<td class="code">--- ' + esc(resp.file_a) + (resp.mtime_a ? '   ' + esc(resp.mtime_a) : '') + '</td></tr>';
    html += '<tr class="d-hdr-add"><td class="ln"></td><td class="ln"></td>' +
            '<td class="code">+++ ' + esc(resp.file_b) + (resp.mtime_b ? '   ' + esc(resp.mtime_b) : '') + '</td></tr>';

    for (var i = 0; i < rawLines.length; i++) {
        var line = rawLines[i];
        if (!line.length) continue;

        var ch = line.charAt(0);

        // Skip the --- / +++ header lines from diff -u (we draw our own above)
        if ((ch === '-' && line.indexOf('--- ') === 0) ||
            (ch === '+' && line.indexOf('+++ ') === 0)) {
            continue;
        }

        // Escape the raw diff line first, then restore XML character entities.
        // esc() converts < → &lt;, & → &amp; etc., making it safe for innerHTML.
        // The replace then converts &amp;lt; → &lt; (renders as <), &amp;amp; → &amp; (renders as &),
        // so XML entities in config.xml (e.g. &lt;tag&gt;) display correctly as text.
        var code = esc(line.slice(1)).replace(/&amp;/g, '&');

        if (ch === '@') {
            var m = line.match(/@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@/);
            if (m) { ol = parseInt(m[1], 10); nl = parseInt(m[2], 10); }
            hunks++;
            html += '<tr class="d-hunk"><td class="ln">···</td><td class="ln">···</td>' +
                    '<td class="code">' + line + '</td></tr>';
        } else if (ch === '-') {
            removed++;
            html += '<tr class="d-del"><td class="ln">' + ol++ + '</td><td class="ln"></td>' +
                    '<td class="code">' + code + '</td></tr>';
        } else if (ch === '+') {
            added++;
            html += '<tr class="d-add"><td class="ln"></td><td class="ln">' + nl++ + '</td>' +
                    '<td class="code">' + code + '</td></tr>';
        } else if (ch === ' ') {
            html += '<tr class="d-ctx"><td class="ln">' + ol++ + '</td><td class="ln">' + nl++ + '</td>' +
                    '<td class="code">' + code + '</td></tr>';
        } else if (ch === '\\') {
            html += '<tr class="d-ctx"><td class="ln"></td><td class="ln"></td>' +
                    '<td class="code text-muted" style="font-style:italic;">' + line + '</td></tr>';
        }
    }
    html += '</tbody></table>';

    if (added === 0 && removed === 0) { $('#diff_identical').show(); return; }

    $('#diff_stats').html(
        '<span style="color:#22863a;font-weight:600;">+' + added + '</span>&nbsp;' +
        '<span style="color:#b31d28;font-weight:600;">−' + removed + '</span>&nbsp;' +
        '<span class="text-muted">' + hunks + ' Block' + (hunks !== 1 ? 'e' : '') + '</span>'
    );
    $('#diff_output').html(html);
    $('#diff_wrap').show();
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
                '<td style="white-space:nowrap;">' + esc(ts) + '</td>' +
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
        url: '/api/automatisierung/backup/triggerBackup', method: 'POST', data: {uuid: listUuid, comment: $('#list_comment').val()},
        success: function(resp) {
            var type = resp.result === 'ok' ? (resp.filename ? 'success' : 'info') : 'danger';
            var icon = resp.result === 'ok' ? (resp.filename ? 'check' : 'info') : 'times';
            showAlert($('#list_msg'), type, '<i class="fa fa-' + icon + '-circle"></i> ' + esc(resp.message));
            if (resp.result === 'ok' && resp.filename) loadBackupList();
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
   Zenarmor (ZA) Backup Tab
   ========================================================= */
var zaUuid = '';

$('#za_host_select').on('change', function() {
    zaUuid = $(this).val();
    var has = !!zaUuid;
    $('#btn_za_backup_now, #btn_za_refresh').prop('disabled', !has);
    $('#za_host_hint').toggle(!has);
    if (has) loadZaList();
    else { $('#za_table_wrap, #za_empty').hide(); }
});

function loadZaList() {
    if (!zaUuid) return;
    $('#za_table_wrap, #za_empty').hide();
    $.get('/api/automatisierung/backup/listZaBackups', {uuid: zaUuid}, function(resp) {
        var backups = resp.backups || [];
        var $tbody = $('#za_list_tbody').empty();
        if (!backups.length) { $('#za_empty').show(); return; }
        backups.forEach(function(bk) {
            var dlUrl = '/api/automatisierung/backup/downloadZaFile?uuid=' +
                        encodeURIComponent(zaUuid) + '&filename=' + encodeURIComponent(bk.filename);
            $tbody.append(
                '<tr>' +
                '<td style="font-family:monospace;font-size:0.87em;white-space:nowrap;">' + esc(bk.timestamp_fmt) + '</td>' +
                '<td style="font-size:0.82em;word-break:break-all;">' + esc(bk.filename) + '</td>' +
                '<td><small>' + esc(bk.size) + '</small></td>' +
                '<td style="white-space:nowrap;">' +
                  '<a href="' + dlUrl + '" class="btn btn-xs btn-default bk-inline-btn" title="Herunterladen" download><i class="fa fa-download"></i></a>' +
                  '<button class="btn btn-xs btn-danger bk-inline-btn btn-za-del" data-fn="' + esc(bk.filename) + '" title="Löschen"><i class="fa fa-trash-o"></i></button>' +
                '</td></tr>'
            );
        });
        $('#za_table_wrap').show();
    });
}

$('#btn_za_refresh').on('click', loadZaList);

$('#btn_za_backup_now').on('click', function() {
    if (!zaUuid) return;
    var $btn = $(this).prop('disabled', true).html('<i class="fa fa-spinner fa-spin"></i> ...');
    $('#za_msg').hide();
    $.ajax({
        url: '/api/automatisierung/backup/triggerZaBackup', method: 'POST', data: {uuid: zaUuid},
        success: function(resp) {
            var type = resp.result === 'ok' ? (resp.filename ? 'success' : 'info') : 'danger';
            var icon = resp.result === 'ok' ? (resp.filename ? 'check' : 'info') : 'times';
            showAlert($('#za_msg'), type, '<i class="fa fa-' + icon + '-circle"></i> ' + esc(resp.message));
            if (resp.result === 'ok' && resp.filename) loadZaList();
        },
        error: function() {
            showAlert($('#za_msg'), 'danger', '<i class="fa fa-times-circle"></i> Verbindungsfehler');
        },
        complete: function() { $btn.prop('disabled', false).html('<i class="fa fa-shield"></i> ZA-Backup jetzt erstellen'); }
    });
});

$(document).on('click', '.btn-za-del', function() {
    var fn = $(this).data('fn');
    if (!confirm('ZA-Backup "' + fn + '" wirklich löschen?')) return;
    $.ajax({
        url: '/api/automatisierung/backup/deleteZaBackup', method: 'POST',
        data: {uuid: zaUuid, filename: fn},
        success: function(resp) {
            showAlert($('#za_msg'), resp.result === 'ok' ? 'success' : 'danger',
                '<i class="fa fa-' + (resp.result === 'ok' ? 'check' : 'times') + '-circle"></i> ' + esc(resp.message));
            if (resp.result === 'ok') loadZaList();
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
