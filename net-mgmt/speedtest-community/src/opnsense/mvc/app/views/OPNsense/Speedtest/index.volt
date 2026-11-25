{# Copyright 2021 Miha Kralj
*    Redistribution and use in source and binary forms, with or without
*    modification, are permitted provided that the following conditions are met:
*
*    1. Redistributions of source code must retain the above copyright notice,
*       this list of conditions and the following disclaimer.
*
*    2. Redistributions in binary form must reproduce the above copyright
*       notice, this list of conditions and the following disclaimer in the
*       documentation and/or other materials provided with the distribution.
*
*    THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
*    INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
*    AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
*    AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
*    OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
*    SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
*    INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
*    CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
*    ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
*    POSSIBILITY OF SUCH DAMAGE.
#}
<script src="/ui/js/chart.umd.min.js"></script>
<style>
    .speedtest-toolbar { display: flex; flex-wrap: wrap; align-items: end; gap: 12px; margin: 16px 0; }
    .speedtest-toolbar label { display: block; }
    .speedtest-chart { position: relative; height: 260px; margin: 12px 0 24px; }
    .speedtest-surface details { margin: 12px 0 20px; }
    .speedtest-surface summary { cursor: pointer; margin-bottom: 12px; }
    .speedtest-surface progress { display: block; width: 100%; height: 16px; }
    .speedtest-surface pre { white-space: pre-wrap; overflow-wrap: anywhere; }
    .speedtest-surface .table td { vertical-align: middle; }
    .speedtest-surface .numeric { font-variant-numeric: tabular-nums; white-space: nowrap; }
    .speedtest-surface .section-note { max-width: 75ch; }
    @media (max-width: 767px) {
        .speedtest-toolbar > div { flex: 1 1 140px; min-width: 0; }
        .speedtest-chart { height: 220px; }
    }
</style>
<ul class="nav nav-tabs" role="tablist">
    <li class="active"><a href="#measurement" data-toggle="tab" role="tab">{{ lang._('Run test') }}</a></li>
    <li><a href="#history" data-toggle="tab" role="tab">{{ lang._('Trends and history') }}</a></li>
    {% if canSchedule %}<li><a href="#schedule" data-toggle="tab" role="tab">{{ lang._('Schedule') }}</a></li>{% endif %}
    <li><a href="#setup" data-toggle="tab" role="tab">{{ lang._('Setup and CLI') }}</a></li>
</ul>
<div class="tab-content content-box speedtest-surface">
    <div id="measurement" class="tab-pane active" role="tabpanel">
        <div class="content-box-main">
            <h2>LibreSpeedtest</h2>
            <p>{{ lang._('Measure from the firewall to an authorized LibreSpeed server. Tests may saturate the connection.') }}</p>
            <p>
                {{ lang._('Provider') }}:
                <a href="https://librespeed.org/" target="_blank" rel="noopener noreferrer">LibreSpeedtest</a>
                <span id="version" role="status">{{ lang._('Checking LibreSpeed...') }}</span>
            </p>
            <div id="test_status" role="status" aria-live="polite"></div>
            <div class="speedtest-toolbar">
                <div><label for="units">{{ lang._('Speed display') }}</label><select id="units" class="form-control"><option value="Mbps">Mbps</option><option value="MBps">MB/s</option><option value="MiBps">MiB/s</option></select></div>
                <button id="check_status" type="button" class="btn btn-default">{{ lang._('Check running test') }}</button>
            </div>
            <div id="run_progress" hidden>
                <p id="phase_status"></p>
                <progress id="measurement_progress" max="100" value="0" aria-label="{{ lang._('Current measurement phase progress') }}"></progress>
                <p class="help-block">{{ lang._('The measurement continues if you leave this page. Return here to follow progress; do not start a direct CLI test at the same time.') }}</p>
            </div>
            {% if not canRun %}
            <p>{{ lang._('Your account can view results but cannot run measurements. Ask an administrator for the LibreSpeed run privilege.') }}</p>
            {% endif %}
            <form id="test_form" class="form-horizontal">
                <fieldset id="test_controls" disabled>
                    <div class="form-group">
                        <label for="serverid" class="col-sm-3 control-label">{{ lang._('Server') }}</label>
                        <div class="col-sm-9">
                            <select id="serverid" class="form-control">
                                <option value="0">{{ lang._('Automatic server selection') }}</option>
                                <option value="-1">{{ lang._('Compare all configured servers') }}</option>
                                <option value="custom">{{ lang._('Choose server IDs') }}</option>
                            </select>
                            <span class="help-block">{{ lang._('Only administrator-configured servers are used. Automatic selection chooses the lowest latency.') }}</span>
                            <button class="btn btn-default" id="serverlistAct" type="button">{{ lang._('Refresh servers') }}</button>
                        </div>
                        <div class="form-group" id="custom_server_group" hidden>
                            <label for="custom_servers" class="col-sm-3 control-label">{{ lang._('Server IDs') }}</label>
                            <div class="col-sm-9"><input id="custom_servers" type="text" class="form-control" pattern="[1-9][0-9]*(,[1-9][0-9]*)*" placeholder="42,84" disabled required><span class="help-block">{{ lang._('Comma-separated configured IDs. Servers are tested sequentially, never in parallel. Each additional server transfers more data.') }}</span></div>
                        </div>
                    </div>
                    <div class="form-group">
                        <label for="mode" class="col-sm-3 control-label">{{ lang._('Test mode') }}</label>
                        <div class="col-sm-9">
                            <select id="mode" class="form-control">
                                <option value="both">{{ lang._('Download and upload') }}</option>
                                <option value="download">{{ lang._('Download only') }}</option>
                                <option value="upload">{{ lang._('Upload only') }}</option>
                                <option value="latency">{{ lang._('Latency and jitter only') }}</option>
                            </select>
                            <span class="help-block">{{ lang._('All modes and failed measurements enter detailed history. Legacy statistics and widgets continue to use full successful tests only.') }}</span>
                        </div>
                    </div>
                    <details>
                        <summary>{{ lang._('Advanced measurement options') }}</summary>
                        <div class="form-group">
                            <label for="exclude" class="col-sm-3 control-label">{{ lang._('Exclude server IDs') }}</label>
                            <div class="col-sm-9"><input id="exclude" type="text" class="form-control" pattern="([1-9][0-9]*(,[1-9][0-9]*)*)?"><span class="help-block">{{ lang._('Optional comma-separated IDs for automatic selection or Compare all. Clear exclusions when choosing explicit server IDs.') }}</span></div>
                        </div>
                        <div class="form-group">
                            <label for="duration" class="col-sm-3 control-label">{{ lang._('Duration per direction') }}</label>
                            <div class="col-sm-9"><input id="duration" type="number" min="1" max="30" value="10" class="form-control" required><span class="help-block">{{ lang._('Seconds, 1-30. Longer tests transfer more data.') }}</span></div>
                        </div>
                        <div class="form-group">
                            <label for="timeout" class="col-sm-3 control-label">{{ lang._('Request timeout') }}</label>
                            <div class="col-sm-9"><input id="timeout" type="number" min="1" max="15" value="8" class="form-control" required><span class="help-block">{{ lang._('Seconds, 1-15. An overall deadline also bounds the test.') }}</span></div>
                        </div>
                        <div class="form-group">
                            <label for="concurrent" class="col-sm-3 control-label">{{ lang._('Concurrent requests') }}</label>
                            <div class="col-sm-9"><input id="concurrent" type="number" min="1" max="8" value="3" class="form-control" required></div>
                        </div>
                        <div class="form-group">
                            <label for="chunks" class="col-sm-3 control-label">{{ lang._('Download chunks') }}</label>
                            <div class="col-sm-9"><input id="chunks" type="number" min="1" max="1000" value="100" class="form-control" required><span class="help-block">{{ lang._('Chunk size is determined by the server.') }}</span></div>
                        </div>
                        <div class="form-group">
                            <label for="upload_size" class="col-sm-3 control-label">{{ lang._('Upload payload') }}</label>
                            <div class="col-sm-9"><input id="upload_size" type="number" min="1" max="16384" value="1024" class="form-control" required><span class="help-block">{{ lang._('KiB per payload, 1-16384. Large payloads and concurrency consume more memory.') }}</span></div>
                        </div>
                        <div class="form-group">
                            <label for="family" class="col-sm-3 control-label">{{ lang._('IP family') }}</label>
                            <div class="col-sm-9"><select id="family" class="form-control"><option value="auto">{{ lang._('Automatic') }}</option><option value="ipv4">IPv4</option><option value="ipv6">IPv6</option></select></div>
                        </div>
                        <div class="form-group">
                            <label for="source" class="col-sm-3 control-label">{{ lang._('Source IP') }}</label>
                            <div class="col-sm-9"><input id="source" type="text" class="form-control" placeholder="{{ lang._('Optional local address') }}"><span class="help-block">{{ lang._('Use an address assigned to this firewall. Source binding does not override routing or multi-WAN policy. Interface binding is not supported by the FreeBSD engine.') }}</span></div>
                        </div>
                        <div class="form-group">
                            <div class="col-sm-offset-3 col-sm-9">
                                <div class="checkbox"><label><input id="icmp" type="checkbox">{{ lang._('Try ICMP latency; the engine may fall back to HTTP') }}</label></div>
                                <div class="checkbox"><label><input id="http2" type="checkbox">{{ lang._('Allow HTTP/2; requests may share one connection') }}</label></div>
                                <div class="checkbox"><label><input id="no_pre_allocate" type="checkbox">{{ lang._('Reduce upload buffer preallocation') }}</label></div>
                                <div class="checkbox"><label><input id="private_ca" type="checkbox">{{ lang._('Use the private CA bundle at /usr/local/etc/speedtest-community/ca.pem') }}</label></div>
                            </div>
                        </div>
                    </details>
                    <div class="form-group">
                        <div class="col-sm-offset-3 col-sm-9">
                            {% if canRun %}
                            <button class="btn btn-primary" id="reportAct" type="submit">{{ lang._('Run test') }} <i id="reportAct_progress" aria-hidden="true"></i></button>
                            {% endif %}
                        </div>
                    </div>
                </fieldset>
            </form>
            <div id="test_results" hidden aria-live="polite">
                <h3>{{ lang._('Latest measurement') }}</h3>
                <div id="latest_success">
                <table class="table table-condensed">
                    <tbody>
                        <tr><th scope="row">{{ lang._('Server') }}</th><td id="test_server"></td></tr>
                        <tr><th scope="row">{{ lang._('Download') }}</th><td id="download"></td></tr>
                        <tr><th scope="row">{{ lang._('Upload') }}</th><td id="upload"></td></tr>
                        <tr><th scope="row">{{ lang._('Latency') }}</th><td id="latency"></td></tr>
                        <tr><th scope="row">{{ lang._('Jitter') }}</th><td id="jitter"></td></tr>
                        <tr><th scope="row">{{ lang._('Data transferred') }}</th><td id="transfer"></td></tr>
                        <tr><th scope="row">{{ lang._('Probe TLS') }}</th><td id="tls"></td></tr>
                    </tbody>
                </table>
                <p>{{ lang._('TLS details describe the server probe, not every transfer connection. Packet loss and loaded latency are not reported by this engine.') }}</p>
                </div>
                <div class="table-responsive" id="comparison" hidden>
                    <table class="table table-striped"><caption>{{ lang._('Sequential server comparison') }}</caption><thead><tr><th>{{ lang._('Server') }}</th><th>{{ lang._('Download') }}</th><th>{{ lang._('Upload') }}</th><th>{{ lang._('Latency') }}</th><th>{{ lang._('Status') }}</th></tr></thead><tbody id="comparison_rows"></tbody></table>
                </div>
            </div>
        </div>
    </div>
    <div id="history" class="tab-pane" role="tabpanel">
        <div class="content-box-main">
            <h2>{{ lang._('Measurement history') }}</h2>
            <div id="history_status" role="status" aria-live="polite"></div>
            <p class="section-note">{{ lang._('Explore saved measurements, diagnostics and failures. Compare the same server, source address, IP family and test settings. Legacy results are kept separate from the Rust engine.') }}</p>
            <form id="history_filters" class="speedtest-toolbar">
                <div><label for="history_days">{{ lang._('Period') }}</label><select id="history_days" class="form-control"><option value="1">{{ lang._('24 hours') }}</option><option value="7">{{ lang._('7 days') }}</option><option value="30" selected>{{ lang._('30 days') }}</option><option value="90">{{ lang._('90 days') }}</option><option value="365">{{ lang._('1 year') }}</option><option value="0">{{ lang._('All dates') }}</option></select></div>
                <div><label for="history_server">{{ lang._('Server') }}</label><select id="history_server" class="form-control"><option value="all">{{ lang._('All servers') }}</option></select></div>
                <div><label for="history_mode">{{ lang._('Mode') }}</label><select id="history_mode" class="form-control"><option value="all">{{ lang._('All modes') }}</option><option value="both">{{ lang._('Full test') }}</option><option value="download">{{ lang._('Download') }}</option><option value="upload">{{ lang._('Upload') }}</option><option value="latency">{{ lang._('Latency') }}</option></select></div>
                <div><label for="history_provider">{{ lang._('Engine') }}</label><select id="history_provider" class="form-control"><option value="librespeed">LibreSpeed Rust</option><option value="legacy">{{ lang._('Legacy CSV') }}</option></select></div>
                <div><label for="history_outcome">{{ lang._('Outcome') }}</label><select id="history_outcome" class="form-control"><option value="all">{{ lang._('All outcomes') }}</option><option value="success">{{ lang._('Successful') }}</option><option value="failed">{{ lang._('Failed') }}</option></select></div>
                <div><label for="history_origin">{{ lang._('Trigger') }}</label><select id="history_origin" class="form-control"><option value="all">{{ lang._('All triggers') }}</option><option value="manual">{{ lang._('GUI') }}</option><option value="scheduled">{{ lang._('Scheduled') }}</option><option value="cli">{{ lang._('CLI / legacy cron') }}</option><option value="legacy">{{ lang._('Imported CSV') }}</option></select></div>
                <div><label for="history_family">{{ lang._('IP family setting') }}</label><select id="history_family" class="form-control"><option value="all">{{ lang._('All families') }}</option><option value="auto">{{ lang._('Automatic') }}</option><option value="ipv4">IPv4</option><option value="ipv6">IPv6</option></select></div>
                <div><label for="history_source">{{ lang._('Source binding') }}</label><select id="history_source" class="form-control"><option value="all">{{ lang._('All sources') }}</option></select></div>
            </form>
            <p id="history_summary" class="numeric"></p>
            <div class="row">
                <div class="col-md-6"><h3>{{ lang._('Throughput trend') }}</h3><div class="speedtest-chart"><canvas id="throughput_chart" role="img" aria-label="{{ lang._('Historical download and upload averages; exact values are available in the table below') }}"></canvas></div></div>
                <div class="col-md-6"><h3>{{ lang._('Latency and jitter trend') }}</h3><div class="speedtest-chart"><canvas id="latency_chart" role="img" aria-label="{{ lang._('Historical latency and jitter averages; exact values are available in the table below') }}"></canvas></div></div>
            </div>
            <p id="chart_note" class="help-block"></p>
            <div class="table-responsive"><table class="table table-condensed"><caption>{{ lang._('Successful measurements in the selected window; unmeasured values are excluded, not treated as zero') }}</caption><thead><tr><th>{{ lang._('Metric') }}</th><th>{{ lang._('Average') }}</th><th>{{ lang._('Minimum') }}</th><th>{{ lang._('Maximum') }}</th></tr></thead><tbody id="history_metrics"></tbody></table></div>
            <p>
                <a href="/api/speedtest/download/csv" class="btn btn-default">{{ lang._('Export full-test CSV') }}</a>
                <a href="/api/speedtest/download/json" class="btn btn-default">{{ lang._('Export detailed JSONL') }}</a>
                <button class="btn btn-default" id="refresh_history" type="button">{{ lang._('Refresh history') }}</button>
                {% if canClear %}<button class="btn btn-danger" id="deletelogAct" type="button">{{ lang._('Clear history') }}</button>{% endif %}
            </p>
            <div class="table-responsive">
                <table class="table table-striped table-condensed">
                    <thead><tr>
                        <th scope="col">{{ lang._('Time (browser local)') }}</th><th scope="col">{{ lang._('Server / details') }}</th><th scope="col">{{ lang._('Mode') }}</th>
                        <th scope="col">{{ lang._('Download') }}</th><th scope="col">{{ lang._('Upload') }}</th><th scope="col">{{ lang._('Latency') }}</th><th scope="col">{{ lang._('Jitter') }}</th><th scope="col">{{ lang._('Trigger / outcome') }}</th>
                    </tr></thead>
                    <tbody id="log_block"></tbody>
                </table>
            </div>
            <div class="speedtest-toolbar"><button id="history_previous" type="button" class="btn btn-default">{{ lang._('Newer') }}</button><span id="history_page"></span><button id="history_next" type="button" class="btn btn-default">{{ lang._('Older') }}</button></div>
            <p class="help-block">{{ lang._('Exports include all retained dates, independent of filters. JSONL contains detailed modern records; CSV also preserves older full tests. Clearing history removes both.') }}</p>
        </div>
    </div>
    {% if canSchedule %}
    <div id="schedule" class="tab-pane" role="tabpanel">
        <div class="content-box-main">
            <h2>{{ lang._('Scheduled measurements') }}</h2>
            <p class="section-note">{{ lang._('Build a connection history without leaving a browser open. This uses native OPNsense cron, not a second scheduler. Start with one daily test outside busy hours; throughput tests can consume substantial data.') }}</p>
            <p id="schedule_timezone"></p><p id="schedule_conflicts" class="text-warning"></p>
            <form id="schedule_form" class="form-horizontal"><fieldset id="schedule_controls" disabled>
                <div class="form-group"><div class="col-sm-offset-3 col-sm-9"><div class="checkbox"><label><input id="schedule_enabled" type="checkbox">{{ lang._('Enable scheduled measurements') }}</label></div></div></div>
                <div class="form-group"><label for="schedule_cadence" class="col-sm-3 control-label">{{ lang._('Frequency') }}</label><div class="col-sm-9"><select id="schedule_cadence" class="form-control"><option value="hourly">{{ lang._('Hourly') }}</option><option value="daily">{{ lang._('Daily') }}</option><option value="weekdays">{{ lang._('Weekdays') }}</option><option value="weekly">{{ lang._('Weekly') }}</option></select></div></div>
                <div class="form-group"><label for="schedule_hour" class="col-sm-3 control-label">{{ lang._('Hour') }}</label><div class="col-sm-9"><input id="schedule_hour" class="form-control" type="number" min="0" max="23" value="3" required></div></div>
                <div class="form-group"><label for="schedule_minute" class="col-sm-3 control-label">{{ lang._('Minute') }}</label><div class="col-sm-9"><input id="schedule_minute" class="form-control" type="number" min="0" max="59" value="0" required></div></div>
                <div class="form-group"><label for="schedule_weekday" class="col-sm-3 control-label">{{ lang._('Day of week') }}</label><div class="col-sm-9"><select id="schedule_weekday" class="form-control"><option value="0">{{ lang._('Sunday') }}</option><option value="1">{{ lang._('Monday') }}</option><option value="2">{{ lang._('Tuesday') }}</option><option value="3">{{ lang._('Wednesday') }}</option><option value="4">{{ lang._('Thursday') }}</option><option value="5">{{ lang._('Friday') }}</option><option value="6">{{ lang._('Saturday') }}</option></select></div></div>
                <div class="form-group"><label for="schedule_server" class="col-sm-3 control-label">{{ lang._('Server selection') }}</label><div class="col-sm-9"><input id="schedule_server" class="form-control" type="text" value="0" pattern="0|-1|[1-9][0-9]*(,[1-9][0-9]*)*" required><span class="help-block">{{ lang._('0: lowest latency. -1: compare all. Or enter configured IDs, such as 42,84. Comparisons run sequentially.') }}</span></div></div>
                <div class="form-group"><label for="schedule_mode" class="col-sm-3 control-label">{{ lang._('Test mode') }}</label><div class="col-sm-9"><select id="schedule_mode" class="form-control"><option value="both">{{ lang._('Download and upload') }}</option><option value="download">{{ lang._('Download only') }}</option><option value="upload">{{ lang._('Upload only') }}</option><option value="latency">{{ lang._('Latency and jitter only') }}</option></select></div></div>
                <div class="form-group"><div class="col-sm-offset-3 col-sm-9"><p id="schedule_preview"></p><p class="help-block">{{ lang._('Saved measurement defaults apply at execution time. Overlapping tests are refused. Cron uses the firewall timezone and may skip or repeat a wall-clock time at daylight-saving changes.') }}</p><button id="save_schedule" class="btn btn-primary" type="submit">{{ lang._('Save and apply schedule') }}</button> <button id="apply_schedule" class="btn btn-default" type="button">{{ lang._('Apply saved schedule') }}</button></div></div>
            </fieldset></form>
            <div id="schedule_status" role="status" aria-live="polite"></div>
            <p><a href="/ui/cron">{{ lang._('Open native cron for additional schedules or existing jobs') }}</a></p>
        </div>
    </div>
    {% endif %}
    <div id="setup" class="tab-pane" role="tabpanel">
        <div class="content-box-main">
            <h2>{{ lang._('Setup and terminal use') }}</h2>
            <p>{{ lang._('The plugin includes the native Rust engine. Save one to ten authorized servers here, or maintain the root-owned file below. Saved server settings take precedence. No Rust compiler, Go, Node.js, or extra Python package is required on the firewall.') }}</p>
            <code>/usr/local/etc/speedtest-community/librespeed-servers.json</code>
            {% if canConfigure %}
            <h3>{{ lang._('Server configuration') }}</h3>
            <label for="servers_json">{{ lang._('Authorized servers (JSON)') }}</label>
            <textarea id="servers_json" class="form-control" rows="10" spellcheck="false" aria-describedby="servers_help"></textarea>
            <p id="servers_help">{{ lang._('Leave empty to use the administrator-managed file. Otherwise use the array format in this example, with unique IDs and relative endpoint paths.') }}</p>
            <pre>[{"id":42,"name":"Lab","server":"https://bench.example.net/","dlURL":"garbage.php","ulURL":"empty.php","pingURL":"empty.php","getIpURL":"getIP.php"}]</pre>
            <form id="retention_form" class="speedtest-toolbar">
                <div><label for="retention_days">{{ lang._('Keep history for days') }}</label><input id="retention_days" class="form-control" type="number" min="0" max="3650" value="0" required></div>
                <div><label for="history_limit">{{ lang._('Maximum history records') }}</label><input id="history_limit" class="form-control" type="number" min="0" max="100000" value="0" required></div>
            </form>
            <p class="help-block">{{ lang._('0 preserves all history. Optional limits prune both detailed records and legacy CSV after the next measurement. For daily tests, 365 days and 5000 records are a useful starting point. Export before reducing retention.') }}</p>
            <p>{{ lang._('Save also stores the advanced options selected on Run test as defaults for GUI, cron and terminal use. No service restart is needed.') }}</p>
            <button id="save_settings" type="button" class="btn btn-primary" disabled>{{ lang._('Save servers and measurement defaults') }}</button>
            <div id="settings_status" role="status" aria-live="polite"></div>
            {% endif %}
            <h3>{{ lang._('HTTPS is for the test endpoint') }}</h3>
            <p>{{ lang._('The OPNsense administration GUI can use HTTP or HTTPS independently. All measurement endpoints must use HTTPS, and certificates are verified. A browser certificate warning and a test-server certificate failure are different issues.') }}</p>
            <p>{{ lang._('For private endpoints, install a PEM CA bundle at /usr/local/etc/speedtest-community/ca.pem and enable the private CA option. This replaces the engine trust store for that run. The issuing CA and server certificate must be separate certificates. Certificate verification cannot be disabled here.') }}</p>
            <h3>{{ lang._('Terminal commands') }}</h3>
            <pre>opn-librespeed --help
opn-librespeed list
opn-librespeed run --server 42 --duration 15 --family ipv4
opn-librespeed run --mode latency --format json
opn-librespeed run --server 42 --server 84
opn-librespeed run --all-servers
opn-librespeed history --days 30 --format json
opn-librespeed stat
librespeed-cli --help</pre>
            <p>{{ lang._('opn-librespeed shares the GUI lock and history. The native librespeed-cli exposes all upstream options, including JSON streaming, CSV, multi-server tests, and explicit telemetry; direct engine runs do not enter plugin history. Do not run direct engine tests concurrently with GUI or cron tests.') }}</p>
            <h3>{{ lang._('Project and support') }}</h3>
            <ul>
                <li><a href="https://github.com/blackoutsecure/opn-repo/tree/main/net-mgmt/speedtest-community" target="_blank" rel="noopener noreferrer">{{ lang._('Plugin setup, build instructions, and capability notes') }}</a></li>
                <li><a href="https://github.com/blackoutsecure/opn-repo/issues" target="_blank" rel="noopener noreferrer">{{ lang._('Report plugin integration issues') }}</a></li>
                <li><a href="https://github.com/librespeed/speedtest-cli-rust" target="_blank" rel="noopener noreferrer">{{ lang._('Rust engine documentation and issues') }}</a></li>
                <li><a href="https://github.com/librespeed/speedtest" target="_blank" rel="noopener noreferrer">{{ lang._('LibreSpeed server setup') }}</a></li>
                <li><a href="https://github.com/librespeed/speedtest-rust" target="_blank" rel="noopener noreferrer">{{ lang._('Optional Rust server backend') }}</a></li>
            </ul>
            <p>{{ lang._('Public server discovery and telemetry are never requested by the plugin. The test server sees your public IP, which is not collected in new records. A configured local source binding is retained for comparison; older CSV data is preserved. Advanced options apply to the current run unless saved as defaults.') }}</p>
            <h3>{{ lang._('User and group permissions') }}</h3>
            <p>{{ lang._('Assign privileges under System > Access > Users or Groups. View results includes charts, dashboard data and exports. Run measurements, Configure settings, Manage schedule, and Clear history are separate privileges. Grant View results alongside additional privileges. Configuration-read-only accounts cannot run tests or change settings. Native cron access is needed only for additional or manually created jobs; terminal access follows operating-system permissions.') }}</p>
        </div>
    </div>
</div>
<script>
    const api = "/api/speedtest/service/";
    let historyLoaded = false;
    let running = false;
    let starting = false;
    let engineReady = false;
    let defaultsReady = false;
    let settingsReady = false;
    let scheduleReady = false;
    let saving = false;
    let historyPage = 1;
    let historyGeneration = 0;
    let historyData = null;
    let latestResults = [];
    let savedRetention = {};
    let pollGeneration = 0;
    let pollTimer = null;
    let charts = [];
    const canRun = {% if canRun %}true{% else %}false{% endif %};
    const canConfigure = {% if canConfigure %}true{% else %}false{% endif %};
    const canSchedule = {% if canSchedule %}true{% else %}false{% endif %};
    const optionKeys = ['duration', 'timeout', 'concurrent', 'chunks', 'upload_size', 'family', 'source', 'exclude'];
    const booleanKeys = ['icmp', 'http2', 'no_pre_allocate', 'private_ca'];
    const metricNames = {download: "{{ lang._('Download') }}", upload: "{{ lang._('Upload') }}",
        latency: "{{ lang._('Latency') }}", jitter: "{{ lang._('Jitter') }}"};
    const modeNames = {both: "{{ lang._('Full test') }}", download: "{{ lang._('Download') }}",
        upload: "{{ lang._('Upload') }}", latency: "{{ lang._('Latency') }}"};
    const originNames = {manual: "{{ lang._('GUI') }}", scheduled: "{{ lang._('Scheduled') }}",
        cli: "{{ lang._('CLI / legacy cron') }}", legacy: "{{ lang._('Legacy') }}"};
    function updateControls() {
        $('#test_controls').prop('disabled', running || saving || !defaultsReady || (!canRun && !canConfigure));
        $('#reportAct').prop('disabled', running || saving || !engineReady || !defaultsReady || !canRun);
        $('#save_settings').prop('disabled', running || saving || !defaultsReady || !settingsReady);
        $('#servers_json').prop('disabled', running || saving || !settingsReady);
        $('#schedule_controls').prop('disabled', running || saving || !scheduleReady);
        $('#deletelogAct').prop('disabled', running || saving);
        $('#check_status').prop('disabled', starting);
        $('#custom_servers').prop('disabled', $('#serverid').val() !== 'custom');
        $('#custom_server_group').prop('hidden', $('#serverid').val() !== 'custom');
    }
    function currentOptions() {
        const options = {};
        optionKeys.forEach(key => options[key] = $('#' + key).val());
        booleanKeys.forEach(key => options[key] = $('#' + key).prop('checked') ? '1' : '0');
        return options;
    }
    function showStatus(id, message, error = false) {
        const target = $(id);
        if (target.text() !== message) target.text(message);
        target.toggleClass('text-danger', error);
    }
    function request(action, data, callback, status, timeout = 30000) {
        return $.ajax({url: action.startsWith('/') ? action : api + action, type: 'POST', data: data, dataType: 'json', timeout: timeout})
            .done(callback)
            .fail(function(xhr, reason) {
                showStatus(status, reason === 'timeout'
                    ? "{{ lang._('The request timed out. A test may still be running; wait before retrying.') }}"
                    : "{{ lang._('The service could not be reached. Check your session and backend logs.') }}", true);
            });
    }
    function serversReload() {
        $('#serverlistAct').prop('disabled', true);
        request('serverlist', {}, function(data) {
            if (!Array.isArray(data)) {
                showStatus('#test_status', data?.error || "{{ lang._('Unable to load configured servers') }}", true);
                return;
            }
            const selected = $('#serverid').val();
            $('#serverid').empty()
                .append($('<option/>').val('0').text("{{ lang._('Automatic server selection') }}"))
                .append($('<option/>').val('-1').text("{{ lang._('Compare all configured servers') }}"))
                .append($('<option/>').val('custom').text("{{ lang._('Choose server IDs') }}"));
            data.forEach(server => $('#serverid').append($('<option/>').val(server.id).text('(' + server.id + ') ' + server.name)));
            $('#serverid').val(['0', '-1', 'custom'].includes(selected) || data.some(server => server.id === selected) ? selected : '0');
        }, '#test_status').always(() => $('#serverlistAct').prop('disabled', running));
    }
    function number(value, suffix = '') {
        return value === undefined || value === null ? "{{ lang._('Not measured') }}"
            : Number(value).toLocaleString(undefined, {maximumFractionDigits: 2}) + suffix;
    }
    function speed(value) {
        const unit = $('#units').val();
        return number(value === undefined || value === null ? null : value / (unit === 'MiBps' ? 8.388608 : unit === 'MBps' ? 8 : 1),
            unit === 'MiBps' ? ' MiB/s' : unit === 'MBps' ? ' MB/s' : ' Mbps');
    }
    function metricValue(key, value) {
        return ['download', 'upload'].includes(key) ? speed(value) : number(value, ' ms');
    }
    function renderResults(results) {
        latestResults = results;
        const result = results.find(item => !item.error);
        $('#test_results').prop('hidden', !results.length);
        $('#latest_success').prop('hidden', !result);
        if (result) {
            $('#test_server').text('(' + result.serverid + ') ' + result.servername);
            Object.keys(metricNames).forEach(key => $('#' + key).text(metricValue(key, result[key])));
            $('#transfer').text("{{ lang._('Received') }}: " + number(result.bytes_received, ' B')
                + ' / ' + "{{ lang._('Sent') }}: " + number(result.bytes_sent, ' B'));
            $('#tls').text(result.tls ? [result.tls.version, result.tls.cipher].filter(Boolean).join(' / ') : "{{ lang._('Not reported') }}");
        } else {
            $('#test_results').prop('hidden', true);
        }
        $('#comparison').prop('hidden', results.length < 2);
        const rows = $('#comparison_rows').empty();
        results.forEach(item => {
            const row = $('<tr/>');
            [item.servername, speed(item.download), speed(item.upload), number(item.latency, ' ms'),
                item.error || "{{ lang._('Saved') }}"].forEach(value => row.append($('<td/>').text(value)));
            rows.append(row);
        });
        if (results.length > 1) $('#test_results').prop('hidden', false);
    }
    function renderCharts(data) {
        charts.forEach(chart => chart.destroy());
        charts = [];
        $('.speedtest-chart').prop('hidden', !data.series.length);
        if (!data.series.length) return;
        if (typeof Chart !== 'function') {
            showStatus('#history_status', "{{ lang._('Charts could not load. The history table remains available; check that core chart assets are installed.') }}", true);
            return;
        }
        const color = getComputedStyle(document.body).color;
        [['throughput_chart', ['download', 'upload']], ['latency_chart', ['latency', 'jitter']]].forEach(([id, keys]) => {
            const unit = $('#units').val();
            const divisor = id === 'throughput_chart' ? (unit === 'MiBps' ? 8.388608 : unit === 'MBps' ? 8 : 1) : 1;
            charts.push(new Chart(document.getElementById(id), {
                type: 'line',
                data: {datasets: keys.map((key, index) => ({
                    label: metricNames[key],
                    data: data.series.map(point => ({x: point.epoch * 1000, y: point[key] === null ? null : point[key] / divisor})),
                    borderColor: index ? '#b35c28' : '#287ca5', backgroundColor: index ? '#b35c28' : '#287ca5',
                    borderWidth: 2, pointRadius: data.series.length < 60 ? 3 : 0, spanGaps: false
                }))},
                options: {
                    responsive: true, maintainAspectRatio: false, animation: false, parsing: false,
                    interaction: {mode: 'index', intersect: false},
                    plugins: {
                        legend: {labels: {color: color}},
                        tooltip: {callbacks: {title: items => items.length
                            ? new Date(items[0].parsed.x).toLocaleDateString(undefined, {timeZone: 'UTC'}) + ' UTC' : ''}}
                    },
                    scales: {
                        x: {type: 'linear', ticks: {color: color, maxTicksLimit: 6,
                            callback: value => new Date(value).toLocaleDateString(undefined, {month: 'short', day: 'numeric', timeZone: 'UTC'})}},
                        y: {beginAtZero: true, ticks: {color: color}, title: {display: true, color: color,
                            text: id === 'latency_chart' ? 'ms' : unit === 'MiBps' ? 'MiB/s' : unit === 'MBps' ? 'MB/s' : 'Mbps'}}
                    }
                }
            }));
        });
    }
    function populateFilter(id, values, label) {
        const selected = $(id).val() || 'all';
        $(id).empty().append($('<option/>').val('all').text(label));
        Object.entries(values).forEach(([value, name]) => $(id).append($('<option/>').val(value).text(name)));
        $(id).val(Object.hasOwn(values, selected) ? selected : 'all');
    }
    function renderHistory(data) {
        historyData = data;
        const rows = $('#log_block').empty();
        data.rows.forEach(item => {
            const row = $('<tr/>');
            row.append($('<td/>').text(new Date(item.epoch * 1000).toLocaleString()));
            const server = $('<td/>').text('(' + item.serverid + ') ' + item.servername);
            const details = $('<details/>').append($('<summary/>').text("{{ lang._('Details') }}"));
            details.append($('<pre/>').text(JSON.stringify(item, null, 2)));
            row.append(server.append(details)).append($('<td/>').text(modeNames[item.mode] || item.mode));
            Object.keys(metricNames).forEach(key => row.append($('<td/>').addClass('numeric').text(metricValue(key, item[key]))));
            row.append($('<td/>').text((originNames[item.origin] || item.origin) + ' / '
                + (item.error || "{{ lang._('Successful') }}")));
            rows.append(row);
        });
        const metrics = $('#history_metrics').empty();
        Object.entries(data.metrics).forEach(([key, value]) => {
            const row = $('<tr/>').append($('<th/>').attr('scope', 'row').text(metricNames[key]));
            ['avg', 'min', 'max'].forEach(kind => row.append($('<td/>').addClass('numeric').text(metricValue(key, value[kind]))));
            metrics.append(row);
        });
        $('#history_summary').text("{{ lang._('Successful') }}: " + data.successful + ' / '
            + "{{ lang._('Failed') }}: " + data.failed + ' · ' + "{{ lang._('Recorded transfer') }}: "
            + number((data.bytes_received + data.bytes_sent) / 1073741824, ' GiB'));
        $('#chart_note').text(data.series.length ? "{{ lang._('Chart bucket (UTC days)') }}: " + data.bucket_days + '. '
            + "{{ lang._('Only measured values are averaged. The table shows exact runs in your browser timezone. Transfer totals exclude legacy records without byte counters.') }}"
            : "{{ lang._('No successful measurements in this window. Run a test or adjust the filters to start a trend.') }}");
        populateFilter('#history_server', data.servers, "{{ lang._('All servers') }}");
        populateFilter('#history_source', Object.fromEntries(data.sources.map(source => [source, source])), "{{ lang._('All sources') }}");
        $('#history_previous').prop('disabled', historyPage <= 1);
        $('#history_next').prop('disabled', historyPage * data.limit >= data.total || historyPage >= 200);
        $('#history_page').text("{{ lang._('Page') }} " + historyPage + ' / ' + Math.max(1, Math.ceil(data.total / data.limit))
            + ' · ' + data.total + ' ' + "{{ lang._('records') }}"
            + (data.total > 10000 ? ' · ' + "{{ lang._('Browse up to 10000 rows per filter; narrow filters or export for the complete set.') }}" : ''));
        showStatus('#history_status', data.total ? '' : "{{ lang._('No matching records. Adjust the filters or run a test. Older CSV results appear under Legacy CSV.') }}");
        renderCharts(data);
    }
    function historyReload() {
        const generation = ++historyGeneration;
        historyData = null;
        const filters = {page: historyPage, days: $('#history_days').val(), server: $('#history_server').val(),
            mode: $('#history_mode').val(), provider: $('#history_provider').val(), status: $('#history_outcome').val(),
            origin: $('#history_origin').val(), family: $('#history_family').val(),
            source: $('#history_source').val() === 'all' ? '' : $('#history_source').val()};
        showStatus('#history_status', "{{ lang._('Loading history...') }}");
        $('#history_previous, #history_next').prop('disabled', true);
        $.ajax({url: api + 'history', type: 'POST', data: filters, dataType: 'json', timeout: 30000})
            .done(function(data) {
                if (generation !== historyGeneration) return;
                if (!Array.isArray(data?.rows) || !Array.isArray(data?.series) || !data.metrics) {
                    showStatus('#history_status', data?.error || "{{ lang._('Unable to load history') }}", true);
                    return;
                }
                historyLoaded = true;
                renderHistory(data);
            }).fail(function() {
                if (generation === historyGeneration) showStatus('#history_status', "{{ lang._('Unable to load history. Check your session and try Refresh history.') }}", true);
            });
    }
    function followStatus(expected = null, queued = Date.now(), generation = ++pollGeneration, failures = 0) {
        clearTimeout(pollTimer);
        request('status', {}, function(state) {
            if (generation !== pollGeneration) return;
            if (!['idle', 'running', 'completed', 'failed'].includes(state?.status)) {
                showStatus('#test_status', state?.error || "{{ lang._('Unable to read measurement status. Use Check running test to retry.') }}", true);
                return;
            }
            if (expected && state.run_id !== expected && state.status !== 'running') {
                if (Date.now() - queued < 15000) {
                    pollTimer = setTimeout(() => followStatus(expected, queued, generation), 1500);
                } else {
                    running = false;
                    updateControls();
                    showStatus('#test_status', "{{ lang._('The queued test did not start. Check backend logs and use Check running test before retrying.') }}", true);
                }
                return;
            }
            running = state.status === 'running';
            updateControls();
            $('#run_progress').prop('hidden', !running);
            if (running) {
                const phases = {selecting: "{{ lang._('Selecting server') }}", ping: "{{ lang._('Measuring latency') }}",
                    download: "{{ lang._('Measuring download') }}", upload: "{{ lang._('Measuring upload') }}"};
                $('#phase_status').text((state.server || '') + ' · ' + (phases[state.phase] || state.phase)
                    + ' · ' + state.completed + '/' + state.total + (state.mbps === null || state.mbps === undefined ? '' : ' · ' + speed(state.mbps)));
                $('#measurement_progress').val(state.progress || 0);
                showStatus('#test_status', "{{ lang._('Measurement running. Throughput phases may saturate the connection.') }}");
                if (Date.now() / 1000 > state.deadline + 30) {
                    showStatus('#test_status', "{{ lang._('The measurement exceeded its expected deadline. Check backend logs; a lock may still be held. Use Check running test to refresh.') }}", true);
                    return;
                }
                pollTimer = setTimeout(() => followStatus(state.run_id, queued, generation), 1500);
            } else if (state.status !== 'idle') {
                renderResults(state.results || []);
                showStatus('#test_status', state.error || "{{ lang._('Measurement completed. Results are saved in detailed history.') }}", state.status === 'failed');
                historyLoaded = false;
            }
        }, '#test_status').fail(function() {
            if (generation !== pollGeneration) return;
            if (failures < 2) {
                pollTimer = setTimeout(() => followStatus(expected, queued, generation, failures + 1), 3000);
            } else {
                showStatus('#test_status', "{{ lang._('Progress connection lost. The test may still be running. Use Check running test after restoring your session.') }}", true);
            }
        });
    }
    function schedulePreview() {
        const cadence = $('#schedule_cadence').val();
        $('#schedule_hour').prop('disabled', cadence === 'hourly');
        $('#schedule_weekday').prop('disabled', cadence !== 'weekly');
        const hour = String($('#schedule_hour').val()).padStart(2, '0');
        const minute = String($('#schedule_minute').val()).padStart(2, '0');
        $('#schedule_preview').text(cadence === 'hourly'
            ? "{{ lang._('Every hour at minute') }} " + minute
            : "{{ lang._('Scheduled time (firewall local)') }}: " + hour + ':' + minute);
    }
    $(function() {
        $('#test_form')[0].addEventListener('invalid', function() {
            $('#test_form details').prop('open', true);
        }, true);
        request('defaults', {}, function(data) {
            if (!data || data.error) {
                showStatus('#test_status', data?.error || "{{ lang._('Unable to load saved defaults') }}", true);
                return;
            }
            optionKeys.forEach(key => { if (data[key] !== undefined) $('#' + key).val(data[key]); });
            booleanKeys.forEach(key => $('#' + key).prop('checked', data[key] === '1'));
            ['retention_days', 'history_limit'].forEach(key => {
                $('#' + key).val(data[key] || '0');
                savedRetention[key] = Number(data[key] || 0);
            });
            defaultsReady = true;
            updateControls();
            followStatus();
            $('#check_status').on('click', () => followStatus());
            $('#serverid').on('change', updateControls);
            $('#units').on('change', function() {
                renderResults(latestResults);
                if (historyData) renderHistory(historyData);
            });
            $(window).on('pagehide', function() { ++pollGeneration; clearTimeout(pollTimer); });
            if (canSchedule) {
                request('/api/speedtest/schedule/get', {}, function(data) {
                    if (!data?.schedule || data.error) {
                        showStatus('#schedule_status', data?.error || "{{ lang._('Unable to load the schedule. Reload before saving.') }}", true);
                        return;
                    }
                    const schedule = data.schedule;
                    ['cadence', 'hour', 'minute', 'weekday', 'server', 'mode'].forEach(key => $('#schedule_' + key).val(schedule[key]));
                    $('#schedule_enabled').prop('checked', schedule.enabled === '1');
                    $('#schedule_timezone').text("{{ lang._('Firewall timezone') }}: " + schedule.timezone);
                    $('#schedule_conflicts').text(schedule.other_jobs
                        ? "{{ lang._('Other speedtest cron jobs are enabled. Disable them in native cron before enabling this schedule; they will not be modified automatically.') }}" : '');
                    scheduleReady = true;
                    updateControls();
                    schedulePreview();
                }, '#schedule_status');
            }
            $('#schedule_cadence, #schedule_hour, #schedule_minute, #schedule_weekday').on('change', schedulePreview);
            $('#schedule_form').on('submit', function(event) {
                event.preventDefault();
                if (!canSchedule || !scheduleReady || running || saving || !this.reportValidity()) return;
                const schedule = {enabled: $('#schedule_enabled').prop('checked') ? '1' : '0'};
                ['cadence', 'hour', 'minute', 'weekday', 'server', 'mode'].forEach(key => schedule[key] = $('#schedule_' + key).val());
                saving = true;
                updateControls();
                request('/api/speedtest/schedule/set', {schedule: schedule}, function(data) {
                    showStatus('#schedule_status', data?.result === 'saved'
                        ? "{{ lang._('Schedule saved and applied. Saving does not run a test now.') }}"
                        : data?.error || JSON.stringify(data?.validations || data), data?.result !== 'saved');
                }, '#schedule_status').always(function() { saving = false; updateControls(); schedulePreview(); });
            });
            $('#apply_schedule').on('click', function() {
                if (!canSchedule || saving || running || !scheduleReady) return;
                saving = true;
                updateControls();
                request('/api/speedtest/schedule/apply', {}, function(data) {
                    showStatus('#schedule_status', data?.error || (data?.result === 'saved'
                        ? "{{ lang._('Saved schedule applied.') }}" : "{{ lang._('Unable to apply cron. Check backend logs.') }}"), data?.result !== 'saved');
                }, '#schedule_status').always(function() { saving = false; updateControls(); schedulePreview(); });
            });
        }, '#test_status');
        updateControls();
        if (canConfigure) {
            $.ajax({url: '/api/speedtest/settings/get', dataType: 'json', timeout: 30000}).done(function(data) {
                if (typeof data?.speedtest?.general?.servers !== 'string') {
                    showStatus('#settings_status', "{{ lang._('Unable to load server settings') }}", true);
                    return;
                }
                $('#servers_json').val(data.speedtest.general.servers);
                settingsReady = true;
                updateControls();
            }).fail(() => showStatus('#settings_status', "{{ lang._('Unable to load server settings') }}", true));
        }
        $('#save_settings').on('click', function() {
            if (running || saving || !settingsReady || !defaultsReady || !canConfigure) return;
            if (!$('#test_form')[0].reportValidity()) return;
            if (!$('#retention_form')[0].reportValidity()) return;
            const options = currentOptions();
            options.servers = $('#servers_json').val();
            for (const key of ['retention_days', 'history_limit']) {
                options[key] = $('#' + key).val();
            }
            if (['retention_days', 'history_limit'].some(key => Number(options[key]) > 0
                && (!savedRetention[key] || Number(options[key]) < savedRetention[key]))
                && !window.confirm("{{ lang._('Shorter retention will permanently prune old records after the next measurement. Export CSV and JSONL first. Save these limits?') }}")) return;
            saving = true;
            updateControls();
            $.ajax({url: '/api/speedtest/settings/set', type: 'POST', data: {speedtest: {general: options}}, dataType: 'json', timeout: 30000})
                .done(function(data) {
                    if (data?.result !== 'saved') {
                        showStatus('#settings_status', data?.error || JSON.stringify(data?.validations || data) || "{{ lang._('Settings were not saved') }}", true);
                        return;
                    }
                    showStatus('#settings_status', "{{ lang._('Settings saved. New tests and scheduled runs will use these defaults.') }}");
                    window.location.reload();
                }).fail(xhr => showStatus('#settings_status', xhr.responseJSON?.errorMessage || "{{ lang._('Unable to save settings; check permissions, server JSON, and backend logs.') }}", true))
                .always(function() {
                    saving = false;
                    updateControls();
                });
        });
        request('version', {}, function(data) {
            if (!data?.message || data.error) {
                showStatus('#version', data?.error || "{{ lang._('LibreSpeed setup is incomplete. See Setup and CLI.') }}", true);
                updateControls();
                return;
            }
            showStatus('#version', data.message);
            engineReady = true;
            updateControls();
            serversReload();
        }, '#version');
        $('#serverlistAct').on('click', serversReload);
        $('a[href="#history"]').on('shown.bs.tab', function() {
            if (!historyLoaded) historyReload();
            charts.forEach(chart => chart.resize());
        });
        $('#history_filters').on('change', function() { historyPage = 1; historyReload(); });
        $('#history_previous').on('click', function() { if (historyPage > 1) { historyPage--; historyReload(); } });
        $('#history_next').on('click', function() { if (historyPage < 200) { historyPage++; historyReload(); } });
        $('#refresh_history').on('click', historyReload);
        $('#test_form').on('submit', function(event) {
            event.preventDefault();
            if (!canRun || !engineReady || !defaultsReady || running || saving || !this.reportValidity()) return;
            const options = currentOptions();
            const mode = $('#mode').val();
            const server = $('#serverid').val() === 'custom' ? $('#custom_servers').val() : $('#serverid').val();
            ++pollGeneration;
            clearTimeout(pollTimer);
            starting = true;
            running = true;
            updateControls();
            $('#test_results').prop('hidden', true);
            showStatus('#test_status', "{{ lang._('Queuing measurement...') }}");
            request('start/' + encodeURIComponent(server) + '/' + mode, options, function(data) {
                if (data?.result !== 'started' || !data.run_id) {
                    running = false;
                    updateControls();
                    showStatus('#test_status', data?.error || "{{ lang._('Unable to start a measurement. Check backend logs.') }}", true);
                    return;
                }
                followStatus(data.run_id);
            }, '#test_status').fail(function() {
                showStatus('#test_status', "{{ lang._('Start response lost. The test may have started; use Check running test before retrying.') }}", true);
            }).always(function() {
                starting = false;
                updateControls();
            });
        });
        $('#deletelogAct').on('click', function() {
            if (running || saving || !window.confirm("{{ lang._('Permanently clear all speedtest history? Export CSV and JSONL first if you need a copy.') }}")) return;
            $('#deletelogAct').prop('disabled', true);
            request('deletelog', {}, function(data) {
                if (!data || data.error || data.result !== 'ok') {
                    showStatus('#history_status', data?.error || "{{ lang._('Unable to clear history') }}", true);
                    return;
                }
                historyReload();
            }, '#history_status').always(() => $('#deletelogAct').prop('disabled', false));
        });
    });
</script>
