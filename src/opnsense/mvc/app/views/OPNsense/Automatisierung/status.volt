<div class="content-box" style="padding-bottom: 1.5em;">

    <!-- ====== Header ====== -->
    <div class="col-xs-12">
        <h1><i class="fa fa-dashboard"></i> {{ lang._('Automatisierung – Status & Updates') }}</h1>
        <hr/>
        <p class="text-muted">{{ lang._('Übersicht aller konfigurierten OPNsense Instanzen mit aktuellen Versionsinformationen und Update-Optionen.') }}</p>
    </div>

    <!-- ====== Aktions-Toolbar ====== -->
    <div class="col-xs-12" style="margin-bottom:1em;">
        <div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap;">
            <button id="btn_refresh_all" class="btn btn-default">
                <i class="fa fa-refresh"></i> {{ lang._('Alle Status aktualisieren') }}
            </button>
            <select id="refresh_interval" class="form-control" style="width:auto;height:34px;">
                <option value="0">{{ lang._('Manuell') }}</option>
                <option value="30000">30 Sek.</option>
                <option value="60000">1 Min.</option>
                <option value="180000" selected>3 Min.</option>
                <option value="300000">5 Min.</option>
            </select>
            <label id="lbl_select_all" style="display:none;margin:0;font-weight:normal;cursor:pointer;white-space:nowrap;">
                <input type="checkbox" id="chk_select_all" style="margin-right:4px;">
                {{ lang._('Alle auswählen') }}
            </label>
            <span id="last_refresh" class="text-muted" style="font-size:0.9em;"></span>
        </div>
        <div id="global_message" class="alert" style="display:none;margin-top:0.5em;"></div>
    </div>

    <!-- ====== Host-Karten Container ====== -->
    <div class="col-xs-12" id="hosts_container">
        <div id="loading_indicator" class="text-center" style="padding:3em;">
            <i class="fa fa-spinner fa-spin fa-3x"></i>
            <p style="margin-top:1em;">{{ lang._('Lade Statusinformationen...') }}</p>
        </div>
    </div>

    <!-- ====== Bottom Action Bar ====== -->
    <div class="col-xs-12" id="bottom_action_bar" style="display:none;margin-top:0.5em;padding:12px 0;border-top:2px solid #e0e0e0;">
        <div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap;">
            <strong class="text-muted" style="margin-right:4px;"><i class="fa fa-check-square-o"></i> <span id="bottom_sel_count"></span></strong>
            <button id="btn_bulk_opnsense" class="btn btn-warning" style="display:none;">
                <i class="fa fa-download"></i> <span id="bulk_opnsense_label">{{ lang._('OPNsense aktualisieren') }}</span>
            </button>
            <button id="btn_bulk_za" class="btn btn-warning" style="display:none;">
                <i class="fa fa-shield"></i> <span id="bulk_za_label">{{ lang._('ZA aktualisieren') }}</span>
            </button>
        </div>
    </div>

</div>

<!-- ====== Update Confirm Modal ====== -->
<div class="modal fade" id="ConfirmUpdateModal" tabindex="-1" role="dialog">
    <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header">
                <button type="button" class="close" data-dismiss="modal"><span>&times;</span></button>
                <h4 class="modal-title"><i class="fa fa-warning text-warning"></i> {{ lang._('Update bestätigen') }}</h4>
            </div>
            <div class="modal-body" id="confirm_update_body"></div>
            <div class="modal-footer">
                <button type="button" class="btn btn-default" data-dismiss="modal">{{ lang._('Abbrechen') }}</button>
                <button type="button" id="btn_confirm_update" class="btn btn-primary">{{ lang._('Update starten') }}</button>
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
.host-card-local { border-color: #0069d9; }
.host-card-local .host-header.status-online { background: #f0f7ff; border-left: 4px solid #0069d9; }
.badge-local { background: #0069d9; color:#fff; padding:3px 8px; border-radius:10px; font-size:0.82em; }
</style>

<script>
//<![CDATA[

    (function() {
        var csrfToken = "{{ csrf_token }}";
        if (csrfToken) {
            $.ajaxSetup({"beforeSend": function(xhr) { xhr.setRequestHeader("X-CSRFToken", csrfToken); }});
        }
    })();

// i18n strings used in JS (rendered server-side by Volt)
var i18n = {
    noHostsMsg:     "{{ lang._('Keine aktiven Instanzen konfiguriert. Bitte unter') }}",
    noHostsLink:    "{{ lang._('Konfiguration') }}",
    noHostsEnd:     "{{ lang._('Instanzen hinzufügen.') }}",
    lastRefresh:    "{{ lang._('Letzte Aktualisierung') }}",
    loadError:      "{{ lang._('Fehler beim Laden der Statusdaten.') }}",
    connError:      "{{ lang._('Verbindungsfehler') }}",
    unknown:        "{{ lang._('Unbekannt') }}",
    zaRunning:      "{{ lang._('Läuft') }}",
    zaStopped:      "{{ lang._('Gestoppt') }}",
    zaRestart:      "{{ lang._('Engine Neustart empfohlen') }}",
    zaNotInstalled: "{{ lang._('Zenarmor nicht installiert') }}",
    autoNone:       "{{ lang._('Keine aktiv') }}",
    autoOpn:        "{{ lang._('OPNsense Auto-Update') }}",
    autoZa:         "{{ lang._('ZA Auto-Update') }}",
    autoWd:         "{{ lang._('ZA Watchdog') }}",
    updAvail:       "{{ lang._('Update verfügbar') }}",
    updCurrent:     "{{ lang._('Aktuell') }}",
    updOn:          "{{ lang._('Update auf') }}",
    upd:            "{{ lang._('Update') }}",
    networkError:   "{{ lang._('Netzwerkfehler bei') }}",
    autoLabel:      "{{ lang._('Automatisierung') }}",
    testing:        "{{ lang._('Teste...') }}",
    pkgs:           "{{ lang._('Paket(e)') }}",
    pkg:            "{{ lang._('Paket') }}",
    pkgs_pl:        "{{ lang._('Pakete') }}",
    current:        "{{ lang._('aktuell') }}",
    updateBtn:      "{{ lang._('aktualisieren') }}",
    zaReloadNow:    "{{ lang._('ZA Engine neu starten') }}",
    zaWdCheck:      "{{ lang._('ZA Watchdog jetzt prüfen') }}",
    bulkOPNLabel:   "{{ lang._('OPNsense aktualisieren') }}",
    bulkOPNAll:     "{{ lang._('OPNsense (alle aktuell)') }}",
    bulkZALabel:    "{{ lang._('ZA aktualisieren') }}",
    bulkZAAll:      "{{ lang._('ZA (alle aktuell)') }}",
    selCount:       "{{ lang._('ausgewählt') }}",
    confirmOPNMsg:  "{{ lang._('OPNsense Firmware-Update auf') }}",
    confirmOPNWarn: "{{ lang._('Die Firewall wird nach dem Update neu gestartet.') }}",
    confirmLocal:   "{{ lang._('Achtung – Diese Firewall') }}",
    confirmLocalTxt:"{{ lang._('Die Browser-Verbindung wird während des Updates und Neustarts kurz unterbrochen. Die Seite lädt sich danach automatisch neu.') }}",
    confirmZAMsg:   "{{ lang._('Zenarmor Update auf') }}",
    confirmZAFw:    "{{ lang._('starten') }}",
    bulkOPNConfirm: "{{ lang._('OPNsense-Update starten auf') }}",
    bulkOPNReboot:  "{{ lang._('Die Firewalls werden danach neu gestartet. Fortfahren?') }}",
    bulkZAConfirm:  "{{ lang._('ZA-Update starten auf') }}",
    bulkZAConf2:    "{{ lang._('Fortfahren?') }}",
};

var pendingAction = null;
var isLoading = false;
var refreshTimer = null;
var allHostsData = {};

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
                    '<div class="alert alert-info"><i class="fa fa-info-circle"></i> ' + i18n.noHostsMsg + ' ' +
                    '<a href="/automatisierung/index/index">' + i18n.noHostsLink + '</a> ' + i18n.noHostsEnd + '</div>'
                );
                return;
            }

            allHostsData = {};
            $.each(resp.hosts, function(i, host) {
                $('#hosts_container').append(buildHostCard(host));
                if (host.status === 'online') {
                    allHostsData[host.uuid] = host;
                }
            });

            bindActionButtons();
            updateSelectedButton();
            $('#last_refresh').text(i18n.lastRefresh + ': ' + new Date().toLocaleTimeString());
        },
        error: function() {
            isLoading = false;
            $('#loading_indicator').hide();
            $('#hosts_container').append('<div class="alert alert-danger"><i class="fa fa-times-circle"></i> ' + i18n.loadError + '</div>');
        }
    });
}

// ====== Host-Karte aufbauen ======
function buildHostCard(host) {
    var statusClass = 'status-' + (host.status || 'unknown');
    var statusIcon  = host.status === 'online' ? '<i class="fa fa-check-circle text-success"></i>'
                    : host.status === 'error'  ? '<i class="fa fa-times-circle text-danger"></i>'
                    :                            '<i class="fa fa-question-circle text-muted"></i>';

    var isLocal = (host.uuid === '__local__');
    var html = '<div class="host-card' + (isLocal ? ' host-card-local' : '') + '" data-uuid="' + escHtml(host.uuid) + '">';
    html += '<div class="host-header ' + statusClass + '">';
    html += '<div style="display:flex;align-items:center;gap:8px;">';
    if (host.status === 'online' && !isLocal) {
        html += '<input type="checkbox" class="host-select-cb" data-uuid="' + escHtml(host.uuid) + '" style="margin:0;cursor:pointer;" title="Host für Sammelupdate auswählen">';
    }
    if (isLocal) {
        html += '<span class="badge-local"><i class="fa fa-home"></i> Diese Firewall</span> ';
    }
    html += '<span class="host-name">' + statusIcon + ' ' + escHtml(host.name) + '</span> ';
    if (!isLocal) html += '<span class="host-url">' + escHtml(host.url) + '</span>';
    html += '</div>';
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
            html += ' <span class="badge-update"><i class="fa fa-arrow-up"></i> ' + i18n.updAvail;
            if (host.opnsense_update_count) html += ' (' + host.opnsense_update_count + ' ' + (host.opnsense_update_count !== 1 ? i18n.pkgs_pl : i18n.pkg) + ')';
            html += '</span>';
        } else if (updStatus === 'none') {
            html += ' <span class="badge-ok"><i class="fa fa-check"></i> ' + i18n.updCurrent + '</span>';
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
                (opnHasUpdate ? ' ' + i18n.updateBtn + ' (' + (host.opnsense_update_count || '?') + ' ' + (host.opnsense_update_count !== 1 ? i18n.pkgs_pl : i18n.pkg) + ')' : ' (' + i18n.current + ')') +
                '</button> ';
        if (host.za_installed) {
            html += '<button class="btn btn-sm btn-action btn-update-za ' + (zaHasUpdate ? 'btn-warning' : 'btn-default') + '" ' +
                    'data-uuid="' + escHtml(host.uuid) + '" data-name="' + escHtml(host.name) + '"' +
                    (zaHasUpdate ? '' : ' disabled') + '>';
            html += '<i class="fa fa-shield"></i> ZA' +
                    (zaHasUpdate ? ' ' + i18n.updateBtn + (host.za_new_ver ? ' → ' + escHtml(host.za_new_ver) : '') : ' (' + i18n.current + ')') +
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
                html += ' <span class="badge-update"><i class="fa fa-arrow-up"></i> ' + i18n.updOn + ' ' + escHtml(host.za_new_ver) + '</span>';
            } else {
                html += ' <span class="badge-ok"><i class="fa fa-check"></i> ' + i18n.updCurrent + '</span>';
            }
            html += '</div>';

            html += '<div class="info-row">';
            html += '<span class="info-label"><i class="fa fa-heartbeat"></i> ZA Engine Status:</span>';
            var zaRunning = host.za_running;
            if (zaRunning === true) {
                html += '<span class="badge-ok"><i class="fa fa-play-circle"></i> ' + i18n.zaRunning + '</span>';
            } else if (zaRunning === false) {
                html += '<span class="badge-error"><i class="fa fa-stop-circle"></i> ' + i18n.zaStopped + '</span>';
            } else {
                html += '<span class="badge-warn">' + i18n.unknown + '</span>';
            }
            if (host.za_needs_restart) {
                html += ' <span class="badge-warn"><i class="fa fa-exclamation"></i> ' + i18n.zaRestart + '</span>';
            }
            html += '</div>';

            html += '<div style="margin-top:8px;">';
            html += '<button class="btn btn-sm btn-default btn-action btn-restart-za" data-uuid="' + escHtml(host.uuid) + '" data-name="' + escHtml(host.name) + '">';
            html += '<i class="fa fa-refresh"></i> ' + i18n.zaReloadNow + '</button>';
            html += '<button class="btn btn-sm btn-info btn-action btn-watchdog-check" data-uuid="' + escHtml(host.uuid) + '" data-name="' + escHtml(host.name) + '">';
            html += '<i class="fa fa-search"></i> ' + i18n.zaWdCheck + '</button>';
            html += '</div>';

        } else {
            html += '<div class="info-row"><span class="text-muted"><i class="fa fa-shield"></i> ' + i18n.zaNotInstalled + '</span></div>';
        }
        html += '</div>'; // za-section

        // ---- Automatisierungs-Status ----
        html += '<div style="margin-top:14px;padding-top:10px;border-top:1px solid #f0f0f0;font-size:0.88em;color:#888;">';
        html += '<i class="fa fa-clock-o"></i> Automatisierung: ';
        var autoFlags = [];
        if (host.auto_update_opnsense == '1') autoFlags.push(i18n.autoOpn);
        if (host.auto_update_za == '1')       autoFlags.push(i18n.autoZa);
        if (host.za_watchdog == '1')           autoFlags.push(i18n.autoWd);
        html += autoFlags.length ? autoFlags.join(', ') : i18n.autoNone;
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
        var isLocal = (uuid === '__local__');
        pendingAction = {type: 'opnsense_update', uuid: uuid};
        var body = '<p>' + i18n.confirmOPNMsg + ' <strong>' + escHtml(name) + '</strong> ' + i18n.confirmZAFw + '?</p>' +
            '<p class="text-warning"><i class="fa fa-warning"></i> ' + i18n.confirmOPNWarn + '</p>';
        if (isLocal) {
            body += '<div class="alert alert-danger" style="margin-top:8px;margin-bottom:0;">' +
                '<i class="fa fa-home"></i> <strong>' + i18n.confirmLocal + ':</strong> ' +
                i18n.confirmLocalTxt + '</div>';
        }
        $('#confirm_update_body').html(body);
        $('#btn_confirm_update').off('click').on('click', function() {
            $('#ConfirmUpdateModal').modal('hide');
            triggerAction('/api/automatisierung/service/updateOpnsense', {uuid: uuid}, i18n.upd + ' ' + name);
            if (isLocal) {
                // Attempt page reload after ~90s (firewall needs time to update + reboot)
                setTimeout(function() { location.reload(); }, 90000);
            }
        });
        $('#ConfirmUpdateModal').modal('show');
    });

    // Zenarmor Update
    $(document).off('click', '.btn-update-za').on('click', '.btn-update-za', function() {
        var uuid = $(this).data('uuid');
        var name = $(this).data('name');
        $('#confirm_update_body').html('<p>' + i18n.confirmZAMsg + ' <strong>' + escHtml(name) + '</strong> ' + i18n.confirmZAFw + '?</p>');
        $('#btn_confirm_update').off('click').on('click', function() {
            $('#ConfirmUpdateModal').modal('hide');
            triggerAction('/api/automatisierung/service/updateZa', {uuid: uuid}, i18n.upd + ' ZA ' + name);
        });
        $('#ConfirmUpdateModal').modal('show');
    });

    // ZA Restart
    $(document).off('click', '.btn-restart-za').on('click', '.btn-restart-za', function() {
        var uuid = $(this).data('uuid');
        var name = $(this).data('name');
        triggerAction('/api/automatisierung/service/restartZa', {uuid: uuid}, i18n.zaReloadNow + ' ' + name);
    });

    // ZA Watchdog Check
    $(document).off('click', '.btn-watchdog-check').on('click', '.btn-watchdog-check', function() {
        var uuid = $(this).data('uuid');
        var name = $(this).data('name');
        triggerAction('/api/automatisierung/service/zaWatchdogCheck', {uuid: uuid}, i18n.zaWdCheck + ' ' + name);
    });

    // Host-Auswahl Checkbox
    $(document).off('change', '.host-select-cb').on('change', '.host-select-cb', updateSelectedButton);
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
                .html('<i class="fa fa-times-circle"></i> ' + i18n.networkError + ': ' + escHtml(label));
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

// ====== Ausgewählte Hosts ermitteln ======
function getSelectedHosts() {
    var selected = [];
    $('.host-select-cb:checked').each(function() {
        var uuid = $(this).data('uuid');
        if (allHostsData[uuid]) selected.push(allHostsData[uuid]);
    });
    return selected;
}

// ====== Toolbar + Bottom-Bar aktualisieren ======
function updateSelectedButton() {
    var selected    = getSelectedHosts();
    var total       = $('.host-select-cb').length;
    var checkedCnt  = selected.length;
    var opnUpdates  = selected.filter(function(h) { return h.opnsense_update === 'update' || h.opnsense_update_count > 0; });
    var zaUpdates   = selected.filter(function(h) { return h.za_update === true; });

    // Select-all checkbox sichtbar machen wenn Hosts da sind
    if (total > 0) {
        $('#lbl_select_all').show();
        // Indeterminate-Zustand
        var allChecked = ($('.host-select-cb:checked').length === total);
        $('#chk_select_all').prop('checked', allChecked)
                            .prop('indeterminate', checkedCnt > 0 && !allChecked);
    } else {
        $('#lbl_select_all').hide();
    }

    // Bottom-Bar
    if (checkedCnt === 0) {
        $('#bottom_action_bar').hide();
        return;
    }
    $('#bottom_sel_count').text(checkedCnt + ' Host' + (checkedCnt !== 1 ? 's' : '') + ' ' + i18n.selCount);
    $('#bottom_action_bar').show();

    // OPNsense-Button — immer sichtbar, nur disabled wenn kein Update ausstehend
    if (opnUpdates.length > 0) {
        $('#bulk_opnsense_label').text(i18n.bulkOPNLabel + ' (' + opnUpdates.length + '×)');
        $('#btn_bulk_opnsense').prop('disabled', false).removeClass('btn-default').addClass('btn-warning').show();
    } else {
        $('#bulk_opnsense_label').text(i18n.bulkOPNAll);
        $('#btn_bulk_opnsense').prop('disabled', true).removeClass('btn-warning').addClass('btn-default').show();
    }

    // ZA-Button — immer sichtbar, nur disabled wenn kein Update ausstehend
    if (zaUpdates.length > 0) {
        $('#bulk_za_label').text(i18n.bulkZALabel + ' (' + zaUpdates.length + '×)');
        $('#btn_bulk_za').prop('disabled', false).removeClass('btn-default').addClass('btn-warning').show();
    } else {
        $('#bulk_za_label').text(i18n.bulkZAAll);
        $('#btn_bulk_za').prop('disabled', true).removeClass('btn-warning').addClass('btn-default').show();
    }
}

// ====== Select-All Handler ======
$('#chk_select_all').on('change', function() {
    var checked = $(this).is(':checked');
    $('.host-select-cb').prop('checked', checked);
    updateSelectedButton();
});

// ====== Bulk OPNsense Update ======
$('#btn_bulk_opnsense').on('click', function() {
    var hostsOpn = getSelectedHosts().filter(function(h) {
        return h.opnsense_update === 'update' || h.opnsense_update_count > 0;
    });
    if (!hostsOpn.length) return;
    var names = hostsOpn.map(function(h) { return h.name; });
    if (!confirm(i18n.bulkOPNConfirm + ':\n• ' + names.join('\n• ') +
                 '\n\n' + i18n.bulkOPNReboot)) return;
    var queue = hostsOpn.map(function(h) {
        return {url: '/api/automatisierung/service/updateOpnsense', data: {uuid: h.uuid}, label: i18n.upd + ' OPNsense ' + h.name};
    });
    (function runNext(i) {
        if (i >= queue.length) { setTimeout(loadAllStatus, 3000); return; }
        triggerAction(queue[i].url, queue[i].data, queue[i].label);
        setTimeout(function() { runNext(i + 1); }, 2000);
    })(0);
});

// ====== Bulk ZA Update ======
$('#btn_bulk_za').on('click', function() {
    var hostsZa = getSelectedHosts().filter(function(h) { return h.za_update === true; });
    if (!hostsZa.length) return;
    var names = hostsZa.map(function(h) { return h.name; });
    if (!confirm(i18n.bulkZAConfirm + ':\n• ' + names.join('\n• ') + '\n\n' + i18n.bulkZAConf2)) return;
    var queue = hostsZa.map(function(h) {
        return {url: '/api/automatisierung/service/updateZa', data: {uuid: h.uuid}, label: i18n.upd + ' ZA ' + h.name};
    });
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
