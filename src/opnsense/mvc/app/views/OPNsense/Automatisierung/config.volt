{{ partial("layout_partials/base_form",['fields':form_fields,'id':'frm_GeneralSettings','apply_btn_id':'btn_apply_general'])}}

<div class="content-box" style="padding-bottom: 1.5em;">

    <!-- ====== Header ====== -->
    <div class="col-xs-12">
        <h1><i class="fa fa-cogs"></i> {{ lang._('Automation – Configuration') }}</h1>
        <hr/>
    </div>

    <!-- ====== Hosts Tabelle ====== -->
    <div class="col-xs-12">
        <h2>{{ lang._('OPNsense Instances') }}</h2>
        <p class="text-muted">{{ lang._('Manage connection data for all OPNsense instances. API credentials can be found under System → User Management → API Keys.') }}</p>
    </div>

    <div class="col-xs-12">
        <div class="tab-content">
            <div id="grid-hosts"></div>
            <table id="tbl-hosts" class="table table-condensed table-hover table-striped" data-editDialog="DialogHost" data-editAlert="hostChangeMessage">
                <thead>
                <tr>
                    <th data-column-id="enabled" data-width="6em" data-type="boolean" data-formatter="rowtoggle">{{ lang._('Active') }}</th>
                    <th data-column-id="name" data-type="string">{{ lang._('Name') }}</th>
                    <th data-column-id="url" data-type="string">{{ lang._('URL') }}</th>
                    <th data-column-id="auto_update_opnsense" data-type="boolean" data-formatter="boolean" data-width="8em">{{ lang._('Auto OPNsense') }}</th>
                    <th data-column-id="auto_update_za" data-type="boolean" data-formatter="boolean" data-width="8em">{{ lang._('Auto ZA') }}</th>
                    <th data-column-id="za_watchdog" data-type="boolean" data-formatter="boolean" data-width="8em">{{ lang._('ZA Watchdog') }}</th>
                    <th data-column-id="commands" data-width="7em" data-formatter="commands" data-sortable="false">{{ lang._('Actions') }}</th>
                </tr>
                </thead>
                <tbody>
                </tbody>
                <tfoot>
                <tr>
                    <td></td>
                    <td>
                        <button data-action="add" type="button" class="btn btn-xs btn-default"><span class="fa fa-plus"></span></button>
                        <button data-action="deleteSelected" type="button" class="btn btn-xs btn-default"><span class="fa fa-trash-o"></span></button>
                    </td>
                </tr>
                </tfoot>
            </table>
        </div>

        <div id="hostChangeMessage" class="alert alert-info" style="display:none">
            {{ lang._('Hinweis: Änderungen werden sofort gespeichert. Für Automatisierungen ggf. unter "Allgemein" die Zeitplanung anpassen.') }}
        </div>
    </div>

    <!-- ====== Allgemeine Einstellungen ====== -->
    <div class="col-xs-12" style="margin-top:2em;">
        <h2>{{ lang._('General Settings') }}</h2>
    </div>

    <div class="col-xs-12">
        <form id="frm_general">
            <div class="table-responsive">
                <table class="table table-striped table-condensed">
                    <tbody>
                    <tr>
                        <td style="width:30%"><strong>{{ lang._('Enable automatic updates') }}</strong></td>
                        <td>
                            <input type="checkbox" id="auto_update_enabled" name="general[auto_update_enabled]" value="1"/>
                            <label for="auto_update_enabled" class="text-muted">{{ lang._('Updates are automatically applied at the configured time') }}</label>
                        </td>
                    </tr>
                    <tr>
                        <td><strong>{{ lang._('Update schedule') }}</strong></td>
                        <td>
                            <div class="row">
                                <div class="col-xs-4">
                                    <label>{{ lang._('Hour (0-23)') }}</label>
                                    <input type="number" class="form-control" id="update_hour" name="general[update_hour]" min="0" max="23" value="3"/>
                                </div>
                                <div class="col-xs-4">
                                    <label>{{ lang._('Minute (0-59)') }}</label>
                                    <input type="number" class="form-control" id="update_minute" name="general[update_minute]" min="0" max="59" value="0"/>
                                </div>
                                <div class="col-xs-4">
                                    <label>{{ lang._('Weekdays (*, 1-7)') }}</label>
                                    <input type="text" class="form-control" id="update_days" name="general[update_days]" value="*" placeholder="* = täglich"/>
                                </div>
                            </div>
                            <span class="text-muted small">{{ lang._('* = every day, 1 = Monday, 7 = Sunday (Example: 1,3,5 = Mon,Wed,Fri)') }}</span>
                        </td>
                    </tr>
                    <tr>
                        <td><strong>{{ lang._('Enable ZA Watchdog') }}</strong></td>
                        <td>
                            <input type="checkbox" id="za_watchdog_enabled" name="general[za_watchdog_enabled]" value="1"/>
                            <label for="za_watchdog_enabled" class="text-muted">{{ lang._('Periodically checks if Zenarmor is running and restarts it if necessary') }}</label>
                        </td>
                    </tr>
                    <tr>
                        <td><strong>{{ lang._('ZA check interval') }}</strong></td>
                        <td>
                            <div id="za_check_interval_radios">
                                <label style="margin-right:12px;font-weight:normal"><input type="radio" name="za_iv" value="5"> {{ lang._('5 Min') }}</label>
                                <label style="margin-right:12px;font-weight:normal"><input type="radio" name="za_iv" value="10"> {{ lang._('10 Min') }}</label>
                                <label style="margin-right:12px;font-weight:normal"><input type="radio" name="za_iv" value="15"> {{ lang._('15 Min') }}</label>
                                <label style="margin-right:12px;font-weight:normal"><input type="radio" name="za_iv" value="30"> {{ lang._('30 Min') }}</label>
                                <label style="font-weight:normal"><input type="radio" name="za_iv" value="60"> {{ lang._('60 Min') }}</label>
                            </div>
                        </td>
                    </tr>
                    </tbody>
                </table>
            </div>
            <button id="btn_save_general" class="btn btn-primary" type="button">
                <span class="fa fa-save"></span> {{ lang._('Save settings') }}
            </button>
        </form>
    </div>

    <div class="col-xs-12" style="margin-top:2em;">
        <div id="general_save_result" class="alert" style="display:none;"></div>
    </div>

    <!-- ====== Benachrichtigungen ====== -->
    <div class="col-xs-12" style="margin-top:2em;">
        <h2>{{ lang._('Notifications') }}</h2>
        <p class="text-muted">{{ lang._('Get a push message when the Zenarmor watchdog restarts the engine or a backup fails. Save first, then send a test.') }}</p>
    </div>

    <div class="col-xs-12">
        <form id="frm_notify">
            <div class="table-responsive">
                <table class="table table-striped table-condensed">
                    <tbody>
                    <tr>
                        <td style="width:30%"><strong>{{ lang._('Enable notifications') }}</strong></td>
                        <td>
                            <input type="checkbox" id="notify_enabled" name="notify[enabled]" value="1"/>
                            <label for="notify_enabled" class="text-muted">{{ lang._('Master switch for all channels') }}</label>
                        </td>
                    </tr>

                    <tr>
                        <td><strong><i class="fa fa-telegram"></i> {{ lang._('Telegram') }}</strong></td>
                        <td>
                            <label style="font-weight:normal;display:block;">
                                <input type="checkbox" id="notify_telegram_enabled" name="notify[telegram_enabled]" value="1"/>
                                {{ lang._('Enable Telegram') }}
                            </label>
                            <input type="text" class="form-control input-sm" style="max-width:420px;margin-top:4px;" id="notify_telegram_token" name="notify[telegram_token]" placeholder="{{ lang._('Bot token (123456:ABC-DEF...)') }}" autocomplete="off"/>
                            <input type="text" class="form-control input-sm" style="max-width:420px;margin-top:4px;" id="notify_telegram_chatid" name="notify[telegram_chatid]" placeholder="{{ lang._('Chat ID (e.g. 123456789)') }}" autocomplete="off"/>
                        </td>
                    </tr>

                    <tr>
                        <td><strong><i class="fa fa-mobile"></i> {{ lang._('Pushover') }}</strong></td>
                        <td>
                            <label style="font-weight:normal;display:block;">
                                <input type="checkbox" id="notify_pushover_enabled" name="notify[pushover_enabled]" value="1"/>
                                {{ lang._('Enable Pushover') }}
                            </label>
                            <input type="text" class="form-control input-sm" style="max-width:420px;margin-top:4px;" id="notify_pushover_token" name="notify[pushover_token]" placeholder="{{ lang._('Application API token') }}" autocomplete="off"/>
                            <input type="text" class="form-control input-sm" style="max-width:420px;margin-top:4px;" id="notify_pushover_user" name="notify[pushover_user]" placeholder="{{ lang._('User key') }}" autocomplete="off"/>
                        </td>
                    </tr>

                    <tr>
                        <td><strong><i class="fa fa-comments"></i> {{ lang._('Matrix') }}</strong></td>
                        <td>
                            <label style="font-weight:normal;display:block;">
                                <input type="checkbox" id="notify_matrix_enabled" name="notify[matrix_enabled]" value="1"/>
                                {{ lang._('Enable Matrix') }}
                            </label>
                            <input type="text" class="form-control input-sm" style="max-width:420px;margin-top:4px;" id="notify_matrix_homeserver" name="notify[matrix_homeserver]" placeholder="{{ lang._('Homeserver URL (https://matrix.org)') }}" autocomplete="off"/>
                            <input type="text" class="form-control input-sm" style="max-width:420px;margin-top:4px;" id="notify_matrix_token" name="notify[matrix_token]" placeholder="{{ lang._('Access token') }}" autocomplete="off"/>
                            <input type="text" class="form-control input-sm" style="max-width:420px;margin-top:4px;" id="notify_matrix_room" name="notify[matrix_room]" placeholder="{{ lang._('Room ID (!abc:server.tld)') }}" autocomplete="off"/>
                        </td>
                    </tr>
                    </tbody>
                </table>
            </div>
            <button id="btn_save_notify" class="btn btn-primary" type="button">
                <span class="fa fa-save"></span> {{ lang._('Save settings') }}
            </button>
            <button id="btn_test_notify" class="btn btn-default" type="button">
                <span class="fa fa-paper-plane"></span> {{ lang._('Send test notification') }}
            </button>
            <span id="notify_test_spinner" style="display:none;margin-left:8px;"><i class="fa fa-spinner fa-spin"></i></span>
        </form>
    </div>

    <div class="col-xs-12" style="margin-top:1em;">
        <div id="notify_save_result" class="alert" style="display:none;"></div>
    </div>

    <!-- ====== Self-Healing ====== -->
    <div class="col-xs-12" style="margin-top:2em;">
        <h2>{{ lang._('Self-Healing') }}</h2>
        <p class="text-muted">{{ lang._('Local automatic recovery for the Zenarmor engine. Every action is OFF by default — enable only what you need. A notification is always sent when an action runs.') }}</p>
    </div>

    <div class="col-xs-12">
        <form id="frm_healing">
            <div class="table-responsive">
                <table class="table table-striped table-condensed">
                    <tbody>
                    <tr>
                        <td style="width:30%"><strong>{{ lang._('Check interval') }}</strong></td>
                        <td>
                            <div id="heal_interval_radios">
                                <label style="margin-right:12px;font-weight:normal"><input type="radio" name="heal_iv" value="5"> {{ lang._('5 Min') }}</label>
                                <label style="margin-right:12px;font-weight:normal"><input type="radio" name="heal_iv" value="10"> {{ lang._('10 Min') }}</label>
                                <label style="margin-right:12px;font-weight:normal"><input type="radio" name="heal_iv" value="15"> {{ lang._('15 Min') }}</label>
                                <label style="margin-right:12px;font-weight:normal"><input type="radio" name="heal_iv" value="30"> {{ lang._('30 Min') }}</label>
                                <label style="font-weight:normal"><input type="radio" name="heal_iv" value="60"> {{ lang._('60 Min') }}</label>
                            </div>
                        </td>
                    </tr>
                    <tr>
                        <td><strong><i class="fa fa-microchip"></i> {{ lang._('RAM rebooter') }}</strong></td>
                        <td>
                            <label style="font-weight:normal;">
                                <input type="checkbox" id="heal_ram_enabled" value="1"/>
                                {{ lang._('Gently restart the engine when its RAM usage exceeds') }}
                            </label>
                            <input type="number" class="form-control input-sm" style="width:80px;display:inline-block;" id="heal_ram_threshold" min="50" max="99" value="85"/> %
                        </td>
                    </tr>
                    <tr>
                        <td><strong><i class="fa fa-database"></i> {{ lang._('Reporting database (mongod/elasticsearch)') }}</strong></td>
                        <td>
                            <label style="font-weight:normal;">
                                <input type="checkbox" id="heal_db_enabled" value="1"/>
                                {{ lang._('Restart the reporting DB when its RAM usage exceeds') }}
                            </label>
                            <input type="number" class="form-control input-sm" style="width:80px;display:inline-block;" id="heal_db_threshold" min="50" max="99" value="80"/> %
                        </td>
                    </tr>
                    <tr>
                        <td><strong><i class="fa fa-hdd-o"></i> {{ lang._('Disk protection') }}</strong></td>
                        <td>
                            <label style="font-weight:normal;">
                                <input type="checkbox" id="heal_disk_enabled" value="1"/>
                                {{ lang._('Run cleanup (ZA logs/datastore, trim large logs) when / exceeds') }}
                            </label>
                            <input type="number" class="form-control input-sm" style="width:80px;display:inline-block;" id="heal_disk_threshold" min="50" max="99" value="90"/> %
                        </td>
                    </tr>
                    <tr>
                        <td><strong><i class="fa fa-plug"></i> {{ lang._('Interface reset on packet loss') }}</strong></td>
                        <td>
                            <label style="font-weight:normal;display:block;">
                                <input type="checkbox" id="heal_ifreset_enabled" value="1"/>
                                {{ lang._('Restart the engine on 100% packet loss to the probe target (netmap/inline)') }}
                            </label>
                            <input type="text" class="form-control input-sm" style="max-width:280px;margin-top:4px;" id="heal_ifreset_target" placeholder="{{ lang._('Probe target (IP behind the firewall)') }}"/>
                        </td>
                    </tr>
                    </tbody>
                </table>
            </div>
            <button id="btn_save_healing" class="btn btn-primary" type="button">
                <span class="fa fa-save"></span> {{ lang._('Save settings') }}
            </button>
            <button id="btn_run_healing" class="btn btn-default" type="button">
                <span class="fa fa-heartbeat"></span> {{ lang._('Run check now') }}
            </button>
            <span id="heal_run_spinner" style="display:none;margin-left:8px;"><i class="fa fa-spinner fa-spin"></i></span>
        </form>
    </div>

    <div class="col-xs-12" style="margin-top:1em;">
        <div id="healing_save_result" class="alert" style="display:none;"></div>
    </div>

</div>

<!-- ====== Host Edit Dialog ====== -->
<div class="modal fade" id="DialogHost" tabindex="-1" role="dialog" aria-labelledby="DialogHostLabel">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header">
                <button type="button" class="close" data-dismiss="modal"><span>&times;</span></button>
                <h4 class="modal-title" id="DialogHostLabel"><i class="fa fa-server"></i> {{ lang._('Configure OPNsense instance') }}</h4>
            </div>
            <div class="modal-body">
                <form id="frm_DialogHost" action="#">
                    <ul class="nav nav-tabs" role="tablist">
                        <li class="active"><a href="#tab_host_basic" role="tab" data-toggle="tab">{{ lang._('Connection') }}</a></li>
                        <li><a href="#tab_host_automation" role="tab" data-toggle="tab">{{ lang._('Automation') }}</a></li>
                    </ul>
                    <div class="tab-content content-box" style="padding:1em;">
                        <!-- Verbindung Tab -->
                        <div id="tab_host_basic" class="tab-pane fade in active">
                            <table class="table table-condensed table-striped">
                                <tbody>
                                <tr>
                                    <td style="width:35%"><strong>{{ lang._('Active') }}</strong></td>
                                    <td><input type="checkbox" id="host.enabled" data-field="enabled"/></td>
                                </tr>
                                <tr>
                                    <td><strong>{{ lang._('Name / Description') }}</strong> <span class="text-danger">*</span></td>
                                    <td><input type="text" class="form-control" id="host.name" data-field="name" placeholder="{{ lang._('e.g. Main site firewall') }}"/></td>
                                </tr>
                                <tr>
                                    <td><strong>{{ lang._('URL') }}</strong> <span class="text-danger">*</span></td>
                                    <td>
                                        <input type="url" class="form-control" id="host.url" data-field="url" placeholder="https://192.168.1.1"/>
                                        <span class="text-muted small">{{ lang._('Base URL of OPNsense (without /api)') }}</span>
                                    </td>
                                </tr>
                                <tr>
                                    <td><strong>{{ lang._('API Key') }}</strong> <span class="text-danger">*</span></td>
                                    <td><input type="text" class="form-control" id="host.api_key" data-field="api_key" autocomplete="off"/></td>
                                </tr>
                                <tr>
                                    <td><strong>{{ lang._('API Secret') }}</strong> <span class="text-danger">*</span></td>
                                    <td><input type="password" class="form-control" id="host.api_secret" data-field="api_secret" autocomplete="off"/></td>
                                </tr>
                                <tr>
                                    <td><strong>{{ lang._('Do not verify TLS certificate') }}</strong></td>
                                    <td>
                                        <input type="checkbox" id="host.skip_verify_tls" data-field="skip_verify_tls"/>
                                        <label for="host.skip_verify_tls" class="text-warning"> {{ lang._('Only for self-signed certificates – insecure!') }}</label>
                                    </td>
                                </tr>
                                <tr>
                                    <td colspan="2">
                                        <button id="btn_test_connection" class="btn btn-default btn-sm" type="button">
                                            <span class="fa fa-plug"></span> {{ lang._('Test connection') }}
                                        </button>
                                        <span id="test_connection_result" style="margin-left:1em;"></span>
                                    </td>
                                </tr>
                                </tbody>
                            </table>
                        </div>
                        <!-- Automatisierung Tab -->
                        <div id="tab_host_automation" class="tab-pane fade">
                            <table class="table table-condensed table-striped">
                                <tbody>
                                <tr>
                                    <td style="width:50%">
                                        <strong>{{ lang._('Update OPNsense automatically') }}</strong><br/>
                                        <span class="text-muted small">{{ lang._('Automatically applies firmware updates at the configured schedule') }}</span>
                                    </td>
                                    <td><input type="checkbox" id="host.auto_update_opnsense" data-field="auto_update_opnsense"/></td>
                                </tr>
                                <tr>
                                    <td>
                                        <strong>{{ lang._('Update Zenarmor automatically') }}</strong><br/>
                                        <span class="text-muted small">{{ lang._('Automatically updates Zenarmor packages') }}</span>
                                    </td>
                                    <td><input type="checkbox" id="host.auto_update_za" data-field="auto_update_za"/></td>
                                </tr>
                                <tr>
                                    <td>
                                        <strong>{{ lang._('Zenarmor Watchdog') }}</strong><br/>
                                        <span class="text-muted small">{{ lang._('Monitors whether Zenarmor is running and restarts the engine if necessary') }}</span>
                                    </td>
                                    <td><input type="checkbox" id="host.za_watchdog" data-field="za_watchdog"/></td>
                                </tr>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </form>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-default" data-dismiss="modal">{{ lang._('Cancel') }}</button>
                <button id="btn_host_save" type="button" class="btn btn-primary">
                    <span class="fa fa-save"></span> {{ lang._('Save') }}
                </button>
            </div>
        </div>
    </div>
</div>

<script>
//<![CDATA[

    // CSRF-Setup — muss VOR UIBootgrid laufen (IIFE außerhalb document.ready)
    (function() {
        var csrfToken = "{{ csrf_token }}";
        if (csrfToken) {
            $.ajaxSetup({"beforeSend": function(xhr) { xhr.setRequestHeader("X-CSRFToken", csrfToken); }});
        }
    })();

    // ====== UIBootgrid für Hosts ======
    var gridHosts = $("#tbl-hosts").UIBootgrid({
        search:'/api/automatisierung/settings/searchHosts',
        get:   '/api/automatisierung/settings/getHost/',
        set:   '/api/automatisierung/settings/setHost/',
        add:   '/api/automatisierung/settings/addHost/',
        del:   '/api/automatisierung/settings/delHost/',
        toggle:'/api/automatisierung/settings/toggleHost/',
    });

    // ====== Dialog State ======
    var _dlgUuid = null;

    $(document).on("click", ".command-edit", function() {
        _dlgUuid = $(this).data("rowId") || $(this).attr("data-row-id") || null;
    });

    $(document).on("click", ".command-add, [data-action=add]", function() {
        _dlgUuid = null;
        try { document.getElementById("frm_DialogHost").reset(); } catch(e) {}
        var en = document.getElementById("host.enabled");
        if (en) en.checked = true;
        $("#test_connection_result").html("");
    });

    // ====== Verbindung testen ======
    $("#btn_test_connection").on("click", function() {
        var $sp = $("#test_connection_result").html('<i class="fa fa-spinner fa-spin"></i> {{ lang._("Testing...") }}');
        $.ajax({
            url:    "/api/automatisierung/settings/testConnection",
            method: "POST",
            data: {
                url:            document.getElementById("host.url").value,
                api_key:        document.getElementById("host.api_key").value,
                api_secret:     document.getElementById("host.api_secret").value,
                skip_verify_tls: document.getElementById("host.skip_verify_tls").checked ? "1" : "0",
            },
            success: function(r) {
                if (r.result === "ok") {
                    $sp.html('<span class="text-success"><i class="fa fa-check-circle"></i> ' + r.message + (r.version ? ' (v' + r.version + ')' : '') + '</span>');
                } else {
                    $sp.html('<span class="text-danger"><i class="fa fa-times-circle"></i> ' + r.message + '</span>');
                }
            }
        });
    });

    // ====== Host speichern ======
    $("#btn_host_save").on("click", function() {
        var $btn = $(this).prop("disabled", true);
        var g = function(id) { return document.getElementById(id); };
        var sec = g("host.api_secret").value;
        var pd = {host: {
            enabled:              g("host.enabled").checked ? "1" : "0",
            name:                 g("host.name").value,
            url:                  g("host.url").value,
            api_key:              g("host.api_key").value,
            skip_verify_tls:      g("host.skip_verify_tls").checked ? "1" : "0",
            auto_update_opnsense: g("host.auto_update_opnsense").checked ? "1" : "0",
            auto_update_za:       g("host.auto_update_za").checked ? "1" : "0",
            za_watchdog:          g("host.za_watchdog").checked ? "1" : "0",
        }};
        if (sec) pd.host.api_secret = sec;
        var url = _dlgUuid
            ? "/api/automatisierung/settings/setHost/" + _dlgUuid
            : "/api/automatisierung/settings/addHost/";
        $.ajax({
            url: url, method: "POST", data: pd,
            success: function(r) {
                if (r.result === "saved" || r.uuid) {
                    $("#DialogHost").modal("hide");
                    $("#tbl-hosts").bootgrid("reload");
                } else {
                    alert("{{ lang._('Error') }}: " + JSON.stringify(r.validations || r));
                }
            },
            complete: function() { $btn.prop("disabled", false); }
        });
    });

    // ====== General Settings laden ======
    function loadGeneralSettings() {
        $.ajax('/api/automatisierung/settings/getGeneral', {success: function(data) {
            if (!data.general) return;
            var g = data.general;
            $('#update_hour').val(g.update_hour || 3);
            $('#update_minute').val(g.update_minute || 0);
            $('#update_days').val(g.update_days || '*');
            var iv = g.za_check_interval || '15';
            $('input[name="za_iv"][value="' + iv + '"]').prop('checked', true);
            $('#auto_update_enabled').prop('checked', g.auto_update_enabled == '1');
            $('#za_watchdog_enabled').prop('checked', g.za_watchdog_enabled == '1');
        }});
    }

    // ====== General Settings speichern ======
    $('#btn_save_general').on('click', function() {
        var $btn = $(this).prop('disabled', true);
        $.ajax({
            url:    '/api/automatisierung/settings/setGeneral',
            method: 'POST',
            data: {general: {
                update_hour:         $('#update_hour').val(),
                update_minute:       $('#update_minute').val(),
                update_days:         $('#update_days').val(),
                za_check_interval:   $('input[name="za_iv"]:checked').val() || '15',
                auto_update_enabled: $('#auto_update_enabled').is(':checked') ? '1' : '0',
                za_watchdog_enabled: $('#za_watchdog_enabled').is(':checked') ? '1' : '0',
            }},
            success: function(resp) {
                var $alert = $('#general_save_result');
                var ok = resp.result === 'saved';
                $alert.removeClass('alert-danger alert-success')
                    .addClass(ok ? 'alert-success' : 'alert-danger')
                    .html('<i class="fa fa-' + (ok ? 'check' : 'times') + '-circle"></i> ' +
                          (ok ? '{{ lang._("Saved.") }}' : JSON.stringify(resp.validations || resp)))
                    .show();
                setTimeout(function() { $alert.fadeOut(); }, 4000);
            },
            complete: function() { $btn.prop('disabled', false); }
        });
    });

    // ====== Notifications laden ======
    function loadNotifications() {
        $.ajax('/api/automatisierung/settings/getNotifications', {success: function(data) {
            if (!data.notify) return;
            var n = data.notify;
            $('#notify_enabled').prop('checked', n.enabled == '1');
            $('#notify_telegram_enabled').prop('checked', n.telegram_enabled == '1');
            $('#notify_telegram_token').val(n.telegram_token || '');
            $('#notify_telegram_chatid').val(n.telegram_chatid || '');
            $('#notify_pushover_enabled').prop('checked', n.pushover_enabled == '1');
            $('#notify_pushover_token').val(n.pushover_token || '');
            $('#notify_pushover_user').val(n.pushover_user || '');
            $('#notify_matrix_enabled').prop('checked', n.matrix_enabled == '1');
            $('#notify_matrix_homeserver').val(n.matrix_homeserver || '');
            $('#notify_matrix_token').val(n.matrix_token || '');
            $('#notify_matrix_room').val(n.matrix_room || '');
        }});
    }

    function notifyPayload() {
        return {notify: {
            enabled:           $('#notify_enabled').is(':checked') ? '1' : '0',
            telegram_enabled:  $('#notify_telegram_enabled').is(':checked') ? '1' : '0',
            telegram_token:    $('#notify_telegram_token').val(),
            telegram_chatid:   $('#notify_telegram_chatid').val(),
            pushover_enabled:  $('#notify_pushover_enabled').is(':checked') ? '1' : '0',
            pushover_token:    $('#notify_pushover_token').val(),
            pushover_user:     $('#notify_pushover_user').val(),
            matrix_enabled:    $('#notify_matrix_enabled').is(':checked') ? '1' : '0',
            matrix_homeserver: $('#notify_matrix_homeserver').val(),
            matrix_token:      $('#notify_matrix_token').val(),
            matrix_room:       $('#notify_matrix_room').val(),
        }};
    }

    function showNotifyResult(type, html) {
        $('#notify_save_result').removeClass('alert-danger alert-success alert-warning alert-info')
            .addClass('alert-' + type).html(html).show();
        setTimeout(function() { $('#notify_save_result').fadeOut(); }, 6000);
    }

    // ====== Notifications speichern ======
    $('#btn_save_notify').on('click', function() {
        var $btn = $(this).prop('disabled', true);
        $.ajax({
            url: '/api/automatisierung/settings/setNotifications', method: 'POST',
            data: notifyPayload(),
            success: function(resp) {
                var ok = resp.result === 'saved';
                showNotifyResult(ok ? 'success' : 'danger',
                    '<i class="fa fa-' + (ok ? 'check' : 'times') + '-circle"></i> ' +
                    (ok ? '{{ lang._("Saved.") }}' : JSON.stringify(resp.validations || resp)));
            },
            complete: function() { $btn.prop('disabled', false); }
        });
    });

    // ====== Testbenachrichtigung (nutzt gespeicherte Einstellungen) ======
    $('#btn_test_notify').on('click', function() {
        var $btn = $(this).prop('disabled', true);
        $('#notify_test_spinner').show();
        $.ajax({
            url: '/api/automatisierung/settings/testNotification', method: 'POST',
            success: function(resp) {
                var type = resp.result === 'ok' ? 'success' : (resp.result === 'partial' ? 'warning' : 'info');
                showNotifyResult(type, '<i class="fa fa-paper-plane"></i> ' + (resp.message || ''));
            },
            error: function() { showNotifyResult('danger', '{{ lang._("Test failed.") }}'); },
            complete: function() { $btn.prop('disabled', false); $('#notify_test_spinner').hide(); }
        });
    });

    // ====== Self-Healing laden ======
    function loadHealing() {
        $.ajax('/api/automatisierung/settings/getHealing', {success: function(data) {
            if (!data.healing) return;
            var h = data.healing;
            $('input[name="heal_iv"][value="' + (h.check_interval || '15') + '"]').prop('checked', true);
            $('#heal_ram_enabled').prop('checked', h.ram_enabled == '1');
            $('#heal_ram_threshold').val(h.ram_threshold || 85);
            $('#heal_db_enabled').prop('checked', h.db_enabled == '1');
            $('#heal_db_threshold').val(h.db_threshold || 80);
            $('#heal_disk_enabled').prop('checked', h.disk_enabled == '1');
            $('#heal_disk_threshold').val(h.disk_threshold || 90);
            $('#heal_ifreset_enabled').prop('checked', h.ifreset_enabled == '1');
            $('#heal_ifreset_target').val(h.ifreset_target || '');
        }});
    }

    function healingPayload() {
        return {healing: {
            check_interval:  $('input[name="heal_iv"]:checked').val() || '15',
            ram_enabled:     $('#heal_ram_enabled').is(':checked') ? '1' : '0',
            ram_threshold:   $('#heal_ram_threshold').val() || '85',
            db_enabled:      $('#heal_db_enabled').is(':checked') ? '1' : '0',
            db_threshold:    $('#heal_db_threshold').val() || '80',
            disk_enabled:    $('#heal_disk_enabled').is(':checked') ? '1' : '0',
            disk_threshold:  $('#heal_disk_threshold').val() || '90',
            ifreset_enabled: $('#heal_ifreset_enabled').is(':checked') ? '1' : '0',
            ifreset_target:  $('#heal_ifreset_target').val(),
        }};
    }

    function showHealResult(type, html) {
        $('#healing_save_result').removeClass('alert-danger alert-success alert-warning alert-info')
            .addClass('alert-' + type).html(html).show();
        setTimeout(function() { $('#healing_save_result').fadeOut(); }, 6000);
    }

    $('#btn_save_healing').on('click', function() {
        var $btn = $(this).prop('disabled', true);
        $.ajax({
            url: '/api/automatisierung/settings/setHealing', method: 'POST',
            data: healingPayload(),
            success: function(resp) {
                var ok = resp.result === 'saved';
                showHealResult(ok ? 'success' : 'danger',
                    '<i class="fa fa-' + (ok ? 'check' : 'times') + '-circle"></i> ' +
                    (ok ? '{{ lang._("Saved.") }}' : JSON.stringify(resp.validations || resp)));
            },
            complete: function() { $btn.prop('disabled', false); }
        });
    });

    $('#btn_run_healing').on('click', function() {
        var $btn = $(this).prop('disabled', true);
        $('#heal_run_spinner').show();
        $.ajax({
            url: '/api/automatisierung/settings/runHealing', method: 'POST',
            success: function(resp) {
                showHealResult(resp.result === 'ok' ? 'info' : 'danger',
                    '<i class="fa fa-heartbeat"></i> ' + (resp.message || ''));
            },
            error: function() { showHealResult('danger', '{{ lang._("Run failed.") }}'); },
            complete: function() { $btn.prop('disabled', false); $('#heal_run_spinner').hide(); }
        });
    });

    $(document).ready(function() {
        loadGeneralSettings();
        loadNotifications();
        loadHealing();
    });

//]]>
</script>
