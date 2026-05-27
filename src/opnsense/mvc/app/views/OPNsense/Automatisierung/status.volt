<div class="content-box" style="padding-bottom: 1.5em;">

    <!-- ====== Header ====== -->
    <div class="col-xs-12">
        <h1><i class="fa fa-dashboard"></i> {{ lang._('Automatisierung – Status & Updates') }}</h1>
        <hr/>
        <p class="text-muted">{{ lang._('Übersicht aller konfigurierten OPNsense Instanzen mit aktuellen Versionsinformationen und Update-Optionen.') }}</p>
    </div>

    <!-- ====== Aktions-Toolbar ====== -->
    <div class="col-xs-12" style="margin-bottom:1em;">
        <button id="btn_refresh_all" class="btn btn-default">
            <i class="fa fa-refresh"></i> {{ lang._('Alle Status aktualisieren') }}
        </button>
        <select id="refresh_interval" class="form-control input-sm" style="width:auto;display:inline-block;margin-left:0.5em;">
            <option value="0">{{ lang._('Manuell') }}</option>
            <option value="30000">30 Sek.</option>
            <option value="60000" selected>1 Min.</option>
            <option value="300000">5 Min.</option>
        </select>
        <button id="btn_update_all" class="btn btn-warning" style="display:none;margin-left:1em;">
            <i class="fa fa-download"></i> <span id="update_all_label">{{ lang._('Alle aktualisieren') }}</span>
        </button>
        <span id="last_refresh" class="text-muted" style="margin-left:1em;font-size:0.9em;"></span>
        <div id="global_message" class="alert" style="display:none;margin-top:0.5em;"></div>
    </div>

    <!-- ====== Host-Karten Container ====== -->
    <div class="col-xs-12" id="hosts_container">
        <div id="loading_indicator" class="text-center" style="padding:3em;">
            <i class="fa fa-spinner fa-spin fa-3x"></i>
            <p style="margin-top:1em;">{{ lang._('Lade Statusinformationen...') }}</p>
        </div>
    </div>

</div>

<!-- ====== Update Confirm Modal ====== -->
<div class="modal fade" id="ConfirmUpdateModal" tabindex="-1" role="dialog">
    <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header">
                <button type="button" class="close" data-dismiss="modal"><span>&times;</span></button>
                <h4 class="modal-title"><i class="fa fa-warning text-warning"></i> Update bestätigen</h4>
            </div>
            <div class="modal-body" id="confirm_update_body"></div>
            <div class="modal-footer">
                <button type="button" class="btn btn-default" data-dismiss="modal">Abbrechen</button>
                <button type="button" id="btn_confirm_update" class="btn btn-primary">Update starten</button>
            </div>
        </div>
    </div>
</div>

<style>
.host-card {
    border: 1px solid #ddd;
    border-radius: 6px;
    margin-bottom: 1.5em;
    background: #fff;
    box-shadow: 0 1px 3px rgba(0,0,0,.08);
}
.host-card .host-header {
    padding: 12px 16px;
    border-bottom: 1px solid #eee;
    border-radius: 6px 6px 0 0;
    display: flex;
    align-items: center;
    justify-content: space-between;
}
.host-card .host-header.status-online  { background: #f0fff4; border-left: 4px solid #28a745; }
.host-card .host-header.status-error   { background: #fff5f5; border-left: 4px solid #dc3545; }
.host-card .host-header.status-unknown { background: #f8f9fa; border-left: 4px solid #aaa; }
.host-card .host-body { padding: 16px; }
.host-card .host-name { font-size: 1.1em; font-weight: 600; }
.host-card .host-url  { font-size: 0.85em; color: #888; }
.badge-version { background: #0069d9; color:#fff; padding:3px 8px; border-radius:10px; font-size:0.82em; }
.badge-update  { background: #fd7e14; color:#fff; padding:3px 8px; border-radius:10px; font-size:0.82em; }
.badge-ok      { background: #28a745; color:#fff; padding:3px 8px; border-radius:10px; font-size:0.82em; }
.badge-warn    { background: #ffc107; color:#333; padding:3px 8px; border-radius:10px; font-size:0.82em; }
.badge-error   { background: #dc3545; color:#fff; padding:3px 8px; border-radius:10px; font-size:0.82em; }
.info-row { display:flex; align-items:center; margin-bottom:8px; gap:8px; }
.info-label { min-width:180px; font-weight:500; color:#555; }
.btn-action { margin-right:6px; margin-bottom:6px; }
.za-section { margin-top:14px; padding-top:14px; border-top:1px dashed #e0e0e0; }
.spinner-inline { display:inline-block; }
</style>

<script>
//<![CDATA[

    (function() {
        var csrfToken = "{{ csrf_token }}";
        if (csrfToken) {
            $.ajaxSetup({"beforeSend": function(xhr) { xhr.setRequestHeader("X-CSRFToken", csrfToken); }});
        }
    })();


var pendingAction = null;
var isLoading = false;
var refreshTimer = null;

// ====== Host-Status laden ======
function loadAllStatus() {
    if (isLoading) return;
    isLoading = true;

    var $loader = $('#loading_indicator').detach();
    $('#hosts_container').empty().append($loader);
    $loader.show();
    $('#last_refresh').text('');

    $.ajax({
        url: '/api/automatisierung/service/allStatus',
        method: 'GET',
        success: function(resp) {
            isLoading = false;
            $('#loading_indicator').hide();

            if (!resp.hosts || resp.hosts.length === 0) {
                $('#hosts_container').append(
                    '<div class="alert alert-info"><i class="fa fa-info-circle"></i> Keine aktiven Instanzen konfiguriert. ' +
                    'Bitte unter <a href="/automatisierung/index/index">Konfiguration</a> Instanzen hinzufügen.</div>'
                );
                return;
            }

            var hostsOpnUpdate = [], hostsZaUpdate = [];
            $.each(resp.hosts, function(i, host) {
                $('#hosts_container').append(buildHostCard(host));
                if (host.status === 'online') {
                    if (host.opnsense_update === 'update' || host.opnsense_update_count > 0) hostsOpnUpdate.push(host);
                    if (host.za_update === true) hostsZaUpdate.push(host);
                }
            });

            // "Alle aktualisieren" Toolbar-Button
            var totalUpdates = hostsOpnUpdate.length + hostsZaUpdate.length;
            if (totalUpdates > 1) {
                var parts = [];
                if (hostsOpnUpdate.length) parts.push(hostsOpnUpdate.length + '× OPNsense');
                if (hostsZaUpdate.length)  parts.push(hostsZaUpdate.length + '× ZA');
                $('#update_all_label').text('Alle aktualisieren (' + parts.join(', ') + ')');
                $('#btn_update_all').show().data('opn', hostsOpnUpdate).data('za', hostsZaUpdate);
            } else {
                $('#btn_update_all').hide();
            }

            bindActionButtons();
            $('#last_refresh').text('Letzte Aktualisierung: ' + new Date().toLocaleTimeString('de-CH'));
        },
        error: function() {
            isLoading = false;
            $('#loading_indicator').hide();
            $('#hosts_container').append('<div class="alert alert-danger"><i class="fa fa-times-circle"></i> Fehler beim Laden der Statusdaten.</div>');
        }
    });
}

// ====== Host-Karte aufbauen ======
function buildHostCard(host) {
    var statusClass = 'status-' + (host.status || 'unknown');
    var statusIcon  = host.status === 'online' ? '<i class="fa fa-check-circle text-success"></i>'
                    : host.status === 'error'  ? '<i class="fa fa-times-circle text-danger"></i>'
                    :                            '<i class="fa fa-question-circle text-muted"></i>';

    var html = '<div class="host-card" data-uuid="' + escHtml(host.uuid) + '">';
    html += '<div class="host-header ' + statusClass + '">';
    html += '<div><span class="host-name">' + statusIcon + ' ' + escHtml(host.name) + '</span> ';
    html += '<span class="host-url">' + escHtml(host.url) + '</span></div>';
    html += '<div>';
    if (host.status === 'online') {
        html += '<span class="badge-version">OPNsense ' + escHtml(host.opnsense_version || '?') + '</span> ';
    }
    html += '</div></div>';

    html += '<div class="host-body">';

    if (host.status === 'error') {
        html += '<div class="alert alert-danger" style="margin:0;"><i class="fa fa-exclamation-triangle"></i> ' +
                'Verbindungsfehler: ' + escHtml(host.error || 'Unbekannt') + '</div>';
    } else if (host.status === 'online') {

        // ---- OPNsense Versions- und Update-Info ----
        html += '<div class="info-row">';
        html += '<span class="info-label"><i class="fa fa-server"></i> OPNsense Version:</span>';
        html += '<span class="badge-version">' + escHtml(host.opnsense_version || '?') + '</span>';
        var updStatus = host.opnsense_update || 'none';
        if (updStatus === 'update' || (host.opnsense_update_count && host.opnsense_update_count > 0)) {
            html += ' <span class="badge-update"><i class="fa fa-arrow-up"></i> Update verfügbar';
            if (host.opnsense_update_count) html += ' (' + host.opnsense_update_count + ' Paket(e))';
            html += '</span>';
        } else if (updStatus === 'none') {
            html += ' <span class="badge-ok"><i class="fa fa-check"></i> Aktuell</span>';
        } else {
            html += ' <span class="badge-warn">' + escHtml(updStatus) + '</span>';
        }
        html += '</div>';

        // ---- Update Buttons (immer sichtbar, ausgegraut wenn kein Update) ----
        var opnHasUpdate = (updStatus === 'update' || (host.opnsense_update_count > 0));
        var zaHasUpdate  = (host.za_update === true);
        html += '<div style="margin-bottom:10px;">';
        html += '<button class="btn btn-sm btn-action btn-update-opnsense ' + (opnHasUpdate ? 'btn-warning' : 'btn-default') + '" ' +
                'data-uuid="' + escHtml(host.uuid) + '" data-name="' + escHtml(host.name) + '"' +
                (opnHasUpdate ? '' : ' disabled') + '>';
        html += '<i class="fa fa-download"></i> OPNsense' +
                (opnHasUpdate ? ' aktualisieren (' + (host.opnsense_update_count || '?') + ' Paket' + (host.opnsense_update_count !== 1 ? 'e' : '') + ')' : ' (aktuell)') +
                '</button> ';
        if (host.za_installed) {
            html += '<button class="btn btn-sm btn-action btn-update-za ' + (zaHasUpdate ? 'btn-warning' : 'btn-default') + '" ' +
                    'data-uuid="' + escHtml(host.uuid) + '" data-name="' + escHtml(host.name) + '"' +
                    (zaHasUpdate ? '' : ' disabled') + '>';
            html += '<i class="fa fa-shield"></i> ZA' +
                    (zaHasUpdate ? ' aktualisieren' + (host.za_new_ver ? ' → ' + escHtml(host.za_new_ver) : '') : ' (aktuell)') +
                    '</button>';
        }
        html += '</div>';

        // ---- Zenarmor Sektion ----
        html += '<div class="za-section">';
        if (host.za_installed) {
            html += '<div class="info-row">';
            html += '<span class="info-label"><i class="fa fa-shield"></i> Zenarmor Version:</span>';
            html += '<span class="badge-version">' + escHtml(host.za_version || '?') + '</span>';
            if (zaHasUpdate && host.za_new_ver) {
                html += ' <span class="badge-update"><i class="fa fa-arrow-up"></i> Update auf ' + escHtml(host.za_new_ver) + '</span>';
            } else {
                html += ' <span class="badge-ok"><i class="fa fa-check"></i> Aktuell</span>';
            }
            html += '</div>';

            html += '<div class="info-row">';
            html += '<span class="info-label"><i class="fa fa-heartbeat"></i> ZA Engine Status:</span>';
            var zaRunning = host.za_running;
            if (zaRunning === true) {
                html += '<span class="badge-ok"><i class="fa fa-play-circle"></i> Läuft</span>';
            } else if (zaRunning === false) {
                html += '<span class="badge-error"><i class="fa fa-stop-circle"></i> Gestoppt</span>';
            } else {
                html += '<span class="badge-warn">Unbekannt</span>';
            }
            if (host.za_needs_restart) {
                html += ' <span class="badge-warn"><i class="fa fa-exclamation"></i> Engine Neustart empfohlen</span>';
            }
            html += '</div>';

            html += '<div style="margin-top:8px;">';
            html += '<button class="btn btn-sm btn-default btn-action btn-restart-za" data-uuid="' + escHtml(host.uuid) + '" data-name="' + escHtml(host.name) + '">';
            html += '<i class="fa fa-refresh"></i> ZA Engine neu starten</button>';
            html += '<button class="btn btn-sm btn-info btn-action btn-watchdog-check" data-uuid="' + escHtml(host.uuid) + '" data-name="' + escHtml(host.name) + '">';
            html += '<i class="fa fa-search"></i> ZA Watchdog jetzt prüfen</button>';
            html += '</div>';

        } else {
            html += '<div class="info-row"><span class="text-muted"><i class="fa fa-shield"></i> Zenarmor nicht installiert</span></div>';
        }
        html += '</div>'; // za-section

        // ---- Automatisierungs-Status ----
        html += '<div style="margin-top:14px;padding-top:10px;border-top:1px solid #f0f0f0;font-size:0.88em;color:#888;">';
        html += '<i class="fa fa-clock-o"></i> Automatisierung: ';
        var autoFlags = [];
        if (host.auto_update_opnsense == '1') autoFlags.push('OPNsense Auto-Update');
        if (host.auto_update_za == '1')       autoFlags.push('ZA Auto-Update');
        if (host.za_watchdog == '1')           autoFlags.push('ZA Watchdog');
        html += autoFlags.length ? autoFlags.join(', ') : 'Keine aktiv';
        html += '</div>';
    }

    html += '</div></div>'; // host-body + host-card
    return html;
}

// ====== Action Button Bindings ======
function bindActionButtons() {

    // OPNsense Update
    $(document).off('click', '.btn-update-opnsense').on('click', '.btn-update-opnsense', function() {
        var uuid = $(this).data('uuid');
        var name = $(this).data('name');
        pendingAction = {type: 'opnsense_update', uuid: uuid};
        $('#confirm_update_body').html(
            '<p>OPNsense Firmware-Update auf <strong>' + escHtml(name) + '</strong> starten?</p>' +
            '<p class="text-warning"><i class="fa fa-warning"></i> Die Firewall wird nach dem Update ggf. neu gestartet.</p>'
        );
        $('#btn_confirm_update').off('click').on('click', function() {
            $('#ConfirmUpdateModal').modal('hide');
            triggerAction('/api/automatisierung/service/updateOpnsense', {uuid: uuid}, 'OPNsense Update auf ' + name);
        });
        $('#ConfirmUpdateModal').modal('show');
    });

    // Zenarmor Update
    $(document).off('click', '.btn-update-za').on('click', '.btn-update-za', function() {
        var uuid = $(this).data('uuid');
        var name = $(this).data('name');
        $('#confirm_update_body').html('<p>Zenarmor Update auf <strong>' + escHtml(name) + '</strong> starten?</p>');
        $('#btn_confirm_update').off('click').on('click', function() {
            $('#ConfirmUpdateModal').modal('hide');
            triggerAction('/api/automatisierung/service/updateZa', {uuid: uuid}, 'Zenarmor Update auf ' + name);
        });
        $('#ConfirmUpdateModal').modal('show');
    });

    // ZA Restart
    $(document).off('click', '.btn-restart-za').on('click', '.btn-restart-za', function() {
        var uuid = $(this).data('uuid');
        var name = $(this).data('name');
        triggerAction('/api/automatisierung/service/restartZa', {uuid: uuid}, 'ZA Engine Neustart auf ' + name);
    });

    // ZA Watchdog Check
    $(document).off('click', '.btn-watchdog-check').on('click', '.btn-watchdog-check', function() {
        var uuid = $(this).data('uuid');
        var name = $(this).data('name');
        triggerAction('/api/automatisierung/service/zaWatchdogCheck', {uuid: uuid}, 'ZA Watchdog auf ' + name);
    });
}

// ====== Generischer API-Aufruf mit Feedback ======
function triggerAction(url, data, label) {
    var $msg = $('#global_message');
    $msg.removeClass('alert-success alert-danger alert-info')
        .addClass('alert-info')
        .html('<i class="fa fa-spinner fa-spin"></i> ' + escHtml(label) + '...')
        .show();

    $.ajax({
        url:    url,
        method: 'POST',
        data:   data,
        success: function(resp) {
            var ok  = resp.result === 'ok';
            var msg = resp.message || (resp.actions ? resp.actions.join('<br>') : '');
            $msg.removeClass('alert-info')
                .addClass(ok ? 'alert-success' : 'alert-danger')
                .html('<i class="fa fa-' + (ok ? 'check' : 'times') + '-circle"></i> <strong>' + escHtml(label) + ':</strong> ' + msg);
            if (ok) {
                setTimeout(function() { $msg.fadeOut(); loadAllStatus(); }, 4000);
            }
        },
        error: function() {
            $msg.removeClass('alert-info').addClass('alert-danger')
                .html('<i class="fa fa-times-circle"></i> Netzwerkfehler bei: ' + escHtml(label));
        }
    });
}

function escHtml(s) {
    if (s === null || s === undefined) return '';
    return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

// ====== Auto-Refresh ======
function startAutoRefresh() {
    if (refreshTimer) clearInterval(refreshTimer);
    var interval = parseInt($('#refresh_interval').val(), 10);
    if (interval > 0) {
        refreshTimer = setInterval(loadAllStatus, interval);
    }
}

// ====== Alle aktualisieren ======
$('#btn_update_all').on('click', function() {
    var hostsOpn = $(this).data('opn') || [];
    var hostsZa  = $(this).data('za')  || [];
    var names = [];
    hostsOpn.forEach(function(h) { names.push(h.name + ' (OPNsense)'); });
    hostsZa.forEach(function(h)  { names.push(h.name + ' (ZA)'); });
    if (!confirm('Updates starten auf:\n• ' + names.join('\n• ') + '\n\nFortfahren?')) return;

    var queue = [];
    hostsOpn.forEach(function(h) { queue.push({url: '/api/automatisierung/service/updateOpnsense', data: {uuid: h.uuid}, label: 'OPNsense Update auf ' + h.name}); });
    hostsZa.forEach(function(h)  { queue.push({url: '/api/automatisierung/service/updateZa',       data: {uuid: h.uuid}, label: 'ZA Update auf '       + h.name}); });

    (function runNext(i) {
        if (i >= queue.length) { setTimeout(loadAllStatus, 3000); return; }
        triggerAction(queue[i].url, queue[i].data, queue[i].label);
        setTimeout(function() { runNext(i + 1); }, 2000);
    })(0);
});

// ====== Init ======
$('#btn_refresh_all').on('click', loadAllStatus);
$('#refresh_interval').on('change', startAutoRefresh);

$(document).ready(function() {
    loadAllStatus();
    startAutoRefresh();
});

//]]>
</script>
