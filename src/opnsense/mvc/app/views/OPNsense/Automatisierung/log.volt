<div class="content-box" style="padding-bottom:1.5em;">

    <div class="col-xs-12">
        <h1><i class="fa fa-file-text-o"></i> {{ lang._('Automation – Log') }}</h1>
        <hr/>
    </div>

    <div class="col-xs-12">

        <!-- Controls -->
        <div class="row" style="margin-bottom:10px;">
            <div class="col-xs-6 col-sm-3" style="margin-bottom:6px;">
                <label style="font-weight:600;font-size:0.85em;">{{ lang._('Source') }}</label>
                <select id="log_source" class="form-control input-sm">
                    <option value="all">{{ lang._('All sources') }}</option>
                </select>
            </div>
            <div class="col-xs-6 col-sm-2" style="margin-bottom:6px;">
                <label style="font-weight:600;font-size:0.85em;">{{ lang._('Level') }}</label>
                <select id="log_level" class="form-control input-sm">
                    <option value="">{{ lang._('All') }}</option>
                    <option value="INFO">INFO</option>
                    <option value="WARNING">WARNING</option>
                    <option value="ERROR">ERROR</option>
                </select>
            </div>
            <div class="col-xs-6 col-sm-2" style="margin-bottom:6px;">
                <label style="font-weight:600;font-size:0.85em;">{{ lang._('Lines') }}</label>
                <select id="log_lines" class="form-control input-sm">
                    <option value="100">100</option>
                    <option value="200" selected>200</option>
                    <option value="500">500</option>
                    <option value="1000">1000</option>
                </select>
            </div>
            <div class="col-xs-6 col-sm-5" style="margin-bottom:6px;">
                <label style="font-weight:600;font-size:0.85em;">{{ lang._('Search') }}</label>
                <input type="text" id="log_search" class="form-control input-sm" placeholder="{{ lang._('Filter messages...') }}"/>
            </div>
        </div>

        <div class="row" style="margin-bottom:10px;">
            <div class="col-xs-12">
                <button id="log_refresh" class="btn btn-default btn-sm"><i class="fa fa-refresh"></i> {{ lang._('Refresh') }}</button>
                <label class="checkbox-inline" style="margin-left:10px;">
                    <input type="checkbox" id="log_autorefresh"/> {{ lang._('Auto-refresh (10s)') }}
                </label>
                <a id="log_download" class="btn btn-default btn-sm" href="#" style="margin-left:10px;" download><i class="fa fa-download"></i> {{ lang._('Download') }}</a>
                <button id="log_clear" class="btn btn-default btn-sm"><i class="fa fa-trash-o"></i> {{ lang._('Clear') }}</button>
                <span id="log_meta" class="text-muted" style="margin-left:12px;font-size:0.85em;"></span>
            </div>
        </div>

        <div id="log_msg" class="alert" style="display:none;"></div>

        <!-- Log output -->
        <div id="log_loading" style="display:none;padding:1.5em 0;text-align:center;">
            <i class="fa fa-spinner fa-spin fa-2x"></i>
        </div>

        <div style="border:1px solid #d1d5da;border-radius:4px;overflow:auto;max-height:620px;background:#fff;">
            <table class="table table-condensed" style="margin-bottom:0;font-family:'SFMono-Regular',Consolas,Menlo,monospace;font-size:12px;">
                <thead>
                    <tr style="background:#f6f8fa;">
                        <th style="width:155px;white-space:nowrap;">{{ lang._('Time') }}</th>
                        <th style="width:80px;">{{ lang._('Level') }}</th>
                        <th style="width:120px;">{{ lang._('Source') }}</th>
                        <th>{{ lang._('Message') }}</th>
                    </tr>
                </thead>
                <tbody id="log_body">
                    <tr><td colspan="4" class="text-muted" style="padding:1.2em;">{{ lang._('No entries.') }}</td></tr>
                </tbody>
            </table>
        </div>

    </div>
</div>

<script>
//<![CDATA[
(function() {
    // CSRF for POST requests (set before any AJAX, mirrors the other tabs).
    var csrfToken = "{{ csrf_token }}";
    if (csrfToken) {
        $.ajaxSetup({"beforeSend": function(xhr) { xhr.setRequestHeader("X-CSRFToken", csrfToken); }});
    }
})();

var autoTimer = null;

function escHtml(s) {
    return $('<div>').text(s == null ? '' : s).html();
}

function levelClass(lvl) {
    if (lvl === 'ERROR')   return 'text-danger';
    if (lvl === 'WARNING') return 'text-warning';
    if (lvl === 'INFO')    return 'text-muted';
    return '';
}

function showMsg(type, html) {
    $('#log_msg').attr('class', 'alert alert-' + type).html(html).show();
    setTimeout(function() { $('#log_msg').fadeOut(); }, 4000);
}

function loadSources() {
    $.ajax({ url: '/api/automatisierung/log/sources', method: 'GET' })
     .done(function(resp) {
        var $sel = $('#log_source');
        (resp.sources || []).forEach(function(s) {
            var label = s.label + (s.exists ? ' (' + s.size + ')' : ' — leer');
            $sel.append($('<option>').val(s.key).text(label));
        });
     });
}

function updateDownloadLink() {
    var src = $('#log_source').val();
    var $dl = $('#log_download');
    if (src === 'all') { $dl.addClass('disabled').attr('href', '#'); }
    else { $dl.removeClass('disabled').attr('href', '/api/automatisierung/log/download?source=' + encodeURIComponent(src)); }
}

function loadLog() {
    var params = {
        source: $('#log_source').val(),
        level:  $('#log_level').val(),
        lines:  $('#log_lines').val(),
        q:      $('#log_search').val()
    };
    $('#log_loading').show();
    $.ajax({ url: '/api/automatisierung/log/get', method: 'GET', data: params })
     .done(function(resp) {
        var $b = $('#log_body').empty();
        if (!resp.entries || resp.entries.length === 0) {
            $b.append('<tr><td colspan="4" class="text-muted" style="padding:1.2em;">{{ lang._('No entries.') }}</td></tr>');
            $('#log_meta').text('0 ' + '{{ lang._('entries') }}');
        } else {
            resp.entries.forEach(function(e) {
                $b.append(
                    '<tr>' +
                    '<td style="white-space:nowrap;color:#888;">' + escHtml(e.time) + '</td>' +
                    '<td class="' + levelClass(e.level) + '" style="font-weight:600;">' + escHtml(e.level) + '</td>' +
                    '<td><span class="label label-default">' + escHtml(e.source) + '</span></td>' +
                    '<td style="white-space:pre-wrap;word-break:break-word;">' + escHtml(e.message) + '</td>' +
                    '</tr>'
                );
            });
            $('#log_meta').text(resp.count + ' ' + '{{ lang._('entries') }}' + ' · ' + new Date().toLocaleTimeString());
        }
     })
     .fail(function() { showMsg('danger', '{{ lang._('Failed to load log.') }}'); })
     .always(function() { $('#log_loading').hide(); });
}

$(document).ready(function() {
    loadSources();
    updateDownloadLink();
    loadLog();

    $('#log_refresh').on('click', loadLog);
    $('#log_source, #log_level, #log_lines').on('change', function() { updateDownloadLink(); loadLog(); });

    var searchTimer = null;
    $('#log_search').on('keyup', function() {
        clearTimeout(searchTimer);
        searchTimer = setTimeout(loadLog, 350);
    });

    $('#log_autorefresh').on('change', function() {
        if ($(this).is(':checked')) { autoTimer = setInterval(loadLog, 10000); }
        else { clearInterval(autoTimer); autoTimer = null; }
    });

    $('#log_clear').on('click', function() {
        var src = $('#log_source').val();
        if (src === 'all') { showMsg('warning', '{{ lang._('Please pick a single source to clear.') }}'); return; }
        if (!confirm('{{ lang._('Really clear this log?') }}')) return;
        $.ajax({ url: '/api/automatisierung/log/clear', method: 'POST', data: { source: src } })
         .done(function(resp) {
            if (resp.result === 'ok') { showMsg('success', resp.message); loadLog(); }
            else { showMsg('danger', resp.message || 'Fehler'); }
         })
         .fail(function() { showMsg('danger', '{{ lang._('Clear failed.') }}'); });
    });
});
//]]>
</script>
