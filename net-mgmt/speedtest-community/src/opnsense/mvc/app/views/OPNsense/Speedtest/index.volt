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
    .speedtest-tabs { display: flex; flex-wrap: wrap; }
    .speedtest-tabs > li { float: none; }
    .speedtest-surface [hidden] { display: none !important; }
    .speedtest-surface .content-box-main { padding: 24px; }
    .speedtest-surface h2 { margin: 0 0 8px; font-size: 1.55em; }
    .speedtest-surface h3 { margin: 0 0 8px; font-size: 1.2em; }
    .speedtest-surface .help-block, .speedtest-secondary { color: inherit; opacity: .82; line-height: 1.4; }
    .speedtest-header { display: flex; flex-wrap: wrap; justify-content: space-between; gap: 12px 24px; margin-bottom: 20px; }
    .speedtest-header p { margin: 0; }
    .speedtest-engine { display: flex; flex-wrap: wrap; align-items: baseline; gap: 4px 12px; }
    .speedtest-notice { display: flex; gap: 12px; align-items: flex-start; padding: 14px 16px; margin: 0 0 20px; border: 1px solid rgba(127, 127, 127, .45); border-radius: 3px; }
    .speedtest-notice i { margin-top: 2px; }
    .speedtest-notice p { margin: 4px 0; }
    .speedtest-status:not(:empty) { margin: 0 0 16px; line-height: 1.4; }
    .speedtest-workspace { display: grid; grid-template-columns: minmax(250px, 360px) minmax(0, 1fr); gap: 28px; align-items: start; max-width: 1300px; }
    .speedtest-run-form fieldset { min-width: 0; }
    .speedtest-field { margin: 0 0 16px; }
    .speedtest-field > label, .speedtest-toolbar label { display: block; }
    .speedtest-server-control { display: flex; gap: 8px; }
    .speedtest-server-control select { min-width: 0; flex: 1; }
    .speedtest-option-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0 12px; }
    .speedtest-actions { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; margin: 16px 0; }
    .speedtest-readout { min-width: 0; padding: 20px; border: 1px solid rgba(127, 127, 127, .4); border-radius: 3px; }
    .speedtest-readout-header { display: flex; flex-wrap: wrap; justify-content: space-between; gap: 12px 20px; }
    .speedtest-readout-header p { margin: 0; }
    .speedtest-readout-controls { display: flex; flex-wrap: wrap; align-items: end; gap: 8px; }
    .speedtest-readout-controls label { display: block; }
    .speedtest-readout-controls select { width: auto; min-width: 92px; }
    .speedtest-metrics { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 16px; margin: 24px 0; }
    .speedtest-metrics > div { min-width: 0; }
    .speedtest-metrics dt { margin-bottom: 6px; font-weight: 600; overflow-wrap: anywhere; }
    .speedtest-metrics dd { margin: 0; font-size: 1.7em; font-weight: 600; font-variant-numeric: tabular-nums; overflow-wrap: anywhere; }
    .speedtest-metrics dd.is-empty { font-size: 1em; font-weight: 400; }
    .speedtest-metrics .download-icon { color: #b52da5; }
    .speedtest-metrics .upload-icon { color: #00818b; }
    .speedtest-live-stages { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 14px 20px; }
    .speedtest-live-stage > div { display: flex; justify-content: space-between; gap: 8px; margin-bottom: 5px; }
    .speedtest-live-stage span:last-child { white-space: nowrap; }
    .speedtest-live-chart { position: relative; height: 220px; margin: 12px 0; }
    .speedtest-live-heading { display: flex; flex-wrap: wrap; justify-content: space-between; gap: 8px 20px; margin-top: 20px; }
    .speedtest-live-heading h4 { margin: 0; font-weight: 600; }
    .speedtest-live-heading p { margin: 0; font-variant-numeric: tabular-nums; }
    #download_progress { accent-color: #b52da5; }
    #upload_progress { accent-color: #00818b; }
    .speedtest-result-details { display: flex; flex-wrap: wrap; gap: 12px 28px; margin: 20px 0 0; }
    .speedtest-result-details > div { min-width: 0; }
    .speedtest-result-details dd { margin: 4px 0 0; overflow-wrap: anywhere; }
    .speedtest-toolbar { display: flex; flex-wrap: wrap; align-items: end; gap: 12px; margin: 16px 0; }
    .speedtest-chart { position: relative; height: 260px; margin: 12px 0 24px; }
    .speedtest-disclosure { margin: 16px 0; }
    .speedtest-disclosure > summary { display: flex; align-items: center; gap: 8px; cursor: pointer; font-weight: 600; }
    .speedtest-disclosure > summary::-webkit-details-marker { display: none; }
    .speedtest-disclosure > summary::marker { content: ''; }
    .speedtest-disclosure > summary .fa { transition: transform 160ms ease-out; }
    .speedtest-disclosure[open] > summary .fa { transform: rotate(90deg); }
    .speedtest-disclosure > div { margin-top: 16px; }
    .speedtest-disclosure > summary:focus-visible { outline: 2px solid currentColor; outline-offset: 3px; }
    .speedtest-surface progress { display: block; width: 100%; height: 12px; accent-color: #c03e14; }
    .speedtest-surface pre { white-space: pre-wrap; overflow-wrap: anywhere; }
    .speedtest-surface .table td { vertical-align: middle; }
    .speedtest-surface .numeric { font-variant-numeric: tabular-nums; white-space: nowrap; }
    .speedtest-surface .section-note { max-width: 75ch; }
    .speedtest-settings { max-width: 900px; }
    .speedtest-settings h3 { margin-top: 24px; }
    @media (prefers-reduced-motion: reduce) {
        .speedtest-disclosure > summary .fa { transition: none; }
    }
    @media (max-width: 767px) {
        .speedtest-surface .content-box-main { padding: 16px; }
        .speedtest-workspace { grid-template-columns: minmax(0, 1fr); gap: 20px; }
        .speedtest-toolbar > div { flex: 1 1 140px; min-width: 0; }
        .speedtest-chart { height: 220px; }
    }
    @media (max-width: 560px) {
        .speedtest-metrics { grid-template-columns: repeat(2, minmax(0, 1fr)); }
        .speedtest-live-stages { grid-template-columns: minmax(0, 1fr); }
        .speedtest-readout { padding: 16px; }
    }
</style>
<ul class="nav nav-tabs speedtest-tabs" role="tablist" aria-label="{{ lang._('Speedtest sections') }}">
    <li class="active" role="presentation"><a id="measurement_tab" href="#measurement" data-toggle="tab" role="tab" aria-controls="measurement" aria-selected="true">{{ lang._('Run test') }}</a></li>
    <li role="presentation"><a id="history_tab" href="#history" data-toggle="tab" role="tab" aria-controls="history" aria-selected="false" tabindex="-1">{{ lang._('Trends and history') }}</a></li>
    {% if canSchedule %}<li role="presentation"><a id="schedule_tab" href="#schedule" data-toggle="tab" role="tab" aria-controls="schedule" aria-selected="false" tabindex="-1">{{ lang._('Schedule') }}</a></li>{% endif %}
    <li role="presentation"><a id="setup_tab" href="#setup" data-toggle="tab" role="tab" aria-controls="setup" aria-selected="false" tabindex="-1">{{ lang._('Setup and CLI') }}</a></li>
</ul>
<div class="tab-content content-box speedtest-surface">
    <div id="measurement" class="tab-pane active" role="tabpanel" aria-labelledby="measurement_tab">
        <div class="content-box-main">
            <div class="speedtest-header">
                <div>
                    <h2>{{ lang._('Connection test') }}</h2>
                    <p class="section-note">{{ lang._('Measure from this firewall to an authorized LibreSpeed server. A test may saturate your connection.') }}</p>
                </div>
                <div class="speedtest-engine">
                    <span id="version" role="status">{{ lang._('Checking engine...') }}</span>
                    <a href="https://librespeed.org/" target="_blank" rel="noopener noreferrer">{{ lang._('About LibreSpeed') }}</a>
                </div>
            </div>
            <div id="server_setup_notice" class="speedtest-notice" role="status" aria-live="polite" hidden>
                <i class="fa fa-info-circle" aria-hidden="true"></i>
                <div>
                    <strong>{{ lang._('No test server configured') }}</strong>
                    <p>{{ lang._('Add an authorized HTTPS LibreSpeed server before running a test.') }}</p>
                    {% if canConfigure %}
                    <a id="open_server_setup" href="#setup">{{ lang._('Set up servers') }} <i class="fa fa-angle-right" aria-hidden="true"></i></a>
                    {% else %}
                    <span>{{ lang._('Ask an administrator to add a server in Setup and CLI.') }}</span>
                    {% endif %}
                </div>
            </div>
            <div id="test_status" class="speedtest-status" role="status" aria-live="polite"></div>
            {% if not canRun %}
            <p class="section-note">{{ lang._('You can view results, but need the LibreSpeed run privilege to start a test.') }}</p>
            {% endif %}
            <div class="speedtest-workspace">
            <form id="test_form" class="speedtest-run-form">
                <fieldset id="test_controls" disabled>
                    <h3>{{ lang._('Test options') }}</h3>
                    <div class="speedtest-field">
                        <label for="serverid">{{ lang._('Server') }}</label>
                        <div class="speedtest-server-control">
                            <select id="serverid" class="form-control">
                                <option value="0">{{ lang._('Automatic selection') }}</option>
                                <option value="-1">{{ lang._('Compare all servers') }}</option>
                                <option value="custom">{{ lang._('Choose server IDs') }}</option>
                            </select>
                            <button class="btn btn-default" id="serverlistAct" type="button" title="{{ lang._('Refresh servers') }}" aria-label="{{ lang._('Refresh servers') }}"><i class="fa fa-refresh" aria-hidden="true"></i></button>
                        </div>
                        <span class="help-block">{{ lang._('Automatic selection uses the configured server with the lowest latency.') }}</span>
                        <div id="server_status" class="speedtest-status" role="status" aria-live="polite"></div>
                    </div>
                    <div class="speedtest-field" id="custom_server_group" hidden>
                        <label for="custom_servers">{{ lang._('Server IDs') }}</label>
                        <input id="custom_servers" type="text" class="form-control" pattern="[1-9][0-9]*(,[1-9][0-9]*)*" placeholder="42,84" disabled required>
                        <span class="help-block">{{ lang._('Enter configured IDs separated by commas. Servers are tested one at a time; each test uses more data.') }}</span>
                    </div>
                    <div class="speedtest-field">
                        <label for="mode">{{ lang._('Test mode') }}</label>
                        <select id="mode" class="form-control">
                            <option value="both">{{ lang._('Full test (recommended)') }}</option>
                            <option value="download">{{ lang._('Download only') }}</option>
                            <option value="upload">{{ lang._('Upload only') }}</option>
                            <option value="latency">{{ lang._('Latency and jitter only') }}</option>
                        </select>
                        <span class="help-block">{{ lang._('All modes measure latency and jitter. The full test also measures download and upload.') }}</span>
                        <span class="help-block">{{ lang._('Diagnostics and failures are saved in history. Dashboard widgets use successful full tests.') }}</span>
                    </div>
                    {% if canRun %}
                    <div class="speedtest-actions"><button class="btn btn-primary" id="reportAct" type="submit"><i class="fa fa-play" aria-hidden="true"></i> {{ lang._('Run test') }} <i id="reportAct_progress" aria-hidden="true"></i></button></div>
                    {% endif %}
                    <details class="speedtest-disclosure">
                        <summary><i class="fa fa-angle-right" aria-hidden="true"></i>{{ lang._('Advanced options') }}</summary>
                        <div>
                            <div class="speedtest-field">
                                <label for="exclude">{{ lang._('Exclude server IDs') }}</label>
                                <input id="exclude" type="text" class="form-control" pattern="([1-9][0-9]*(,[1-9][0-9]*)*)?">
                                <span class="help-block">{{ lang._('Use comma-separated IDs with automatic selection or Compare all. Clear exclusions when choosing specific IDs.') }}</span>
                            </div>
                            <div class="speedtest-option-grid">
                                <div class="speedtest-field"><label for="duration">{{ lang._('Duration per direction') }}</label><input id="duration" type="number" min="1" max="30" value="10" class="form-control" required><span class="help-block">{{ lang._('Seconds, 1-30') }}</span></div>
                                <div class="speedtest-field"><label for="timeout">{{ lang._('Request timeout') }}</label><input id="timeout" type="number" min="1" max="15" value="15" class="form-control" required><span class="help-block">{{ lang._('Seconds, 1-15') }}</span></div>
                                <div class="speedtest-field"><label for="concurrent">{{ lang._('Concurrent requests') }}</label><input id="concurrent" type="number" min="1" max="8" value="3" class="form-control" required></div>
                                <div class="speedtest-field"><label for="chunks">{{ lang._('Download chunks') }}</label><input id="chunks" type="number" min="1" max="1000" value="100" class="form-control" required><span class="help-block">{{ lang._('Size is set by the server.') }}</span></div>
                                <div class="speedtest-field"><label for="upload_size">{{ lang._('Upload payload') }}</label><input id="upload_size" type="number" min="1" max="16384" value="1024" class="form-control" required><span class="help-block">{{ lang._('KiB per payload, 1-16384') }}</span></div>
                                <div class="speedtest-field"><label for="family">{{ lang._('IP family') }}</label><select id="family" class="form-control"><option value="auto">{{ lang._('Automatic') }}</option><option value="ipv4">IPv4</option><option value="ipv6">IPv6</option></select></div>
                            </div>
                            <div class="speedtest-field">
                                <label for="source">{{ lang._('Source IP') }}</label>
                                <input id="source" type="text" class="form-control" placeholder="{{ lang._('Optional local address') }}">
                                <span class="help-block">{{ lang._('Use an address on this firewall. Source binding does not select a gateway; interface binding is not supported on FreeBSD.') }}</span>
                            </div>
                            <div class="checkbox"><label><input id="icmp" type="checkbox">{{ lang._('Try ICMP latency; fallback to HTTP is possible') }}</label></div>
                            <div class="checkbox"><label><input id="http2" type="checkbox">{{ lang._('Allow HTTP/2; requests may share a connection') }}</label></div>
                            <div class="checkbox"><label><input id="no_pre_allocate" type="checkbox">{{ lang._('Reduce upload buffer preallocation') }}</label></div>
                            <div class="checkbox"><label><input id="private_ca" type="checkbox">{{ lang._('Use the private CA bundle') }}</label></div>
                            <p class="help-block">{{ lang._('Longer tests, larger payloads and more concurrent requests use more data or memory. Private CA setup is described under Setup and CLI.') }}</p>
                        </div>
                    </details>
                </fieldset>
            </form>
            <section class="speedtest-readout" aria-labelledby="readout_heading">
                <div class="speedtest-readout-header">
                    <div><h3 id="readout_heading">{{ lang._('Latest result') }}</h3><p id="readout_hint" class="speedtest-secondary">{{ lang._('Run a test to see measurements here.') }}</p></div>
                    <div class="speedtest-readout-controls">
                        <div><label for="units">{{ lang._('Units') }}</label><select id="units" class="form-control"><option value="Mbps">Mbps</option><option value="MBps">MB/s</option><option value="MiBps">MiB/s</option></select></div>
                        <button id="check_status" type="button" class="btn btn-default">{{ lang._('Refresh status') }}</button>
                    </div>
                </div>
                <dl class="speedtest-metrics">
                    <div><dt><i class="fa fa-arrow-down download-icon" aria-hidden="true"></i> {{ lang._('Download') }}</dt><dd id="download" class="is-empty">{{ lang._('Not measured') }}</dd></div>
                    <div><dt><i class="fa fa-arrow-up upload-icon" aria-hidden="true"></i> {{ lang._('Upload') }}</dt><dd id="upload" class="is-empty">{{ lang._('Not measured') }}</dd></div>
                    <div><dt>{{ lang._('Latency') }}</dt><dd id="latency" class="is-empty">{{ lang._('Not measured') }}</dd></div>
                    <div><dt>{{ lang._('Jitter') }}</dt><dd id="jitter" class="is-empty">{{ lang._('Not measured') }}</dd></div>
                </dl>
                <div id="run_progress" hidden>
                    <p id="phase_status" role="status" aria-live="polite"></p>
                    <div class="speedtest-live-stages">
                        <div class="speedtest-live-stage"><div><span>{{ lang._('Server selection') }}</span><span id="selecting_status"></span></div><progress id="selecting_progress" max="100" value="0" aria-label="{{ lang._('Server selection progress') }}"></progress></div>
                        <div class="speedtest-live-stage"><div><span>{{ lang._('Latency and jitter') }}</span><span id="ping_status"></span></div><progress id="ping_progress" max="100" value="0" aria-label="{{ lang._('Latency and jitter progress') }}"></progress></div>
                        <div id="download_stage" class="speedtest-live-stage"><div><span>{{ lang._('Download') }}</span><span id="download_status"></span></div><progress id="download_progress" max="100" value="0" aria-label="{{ lang._('Download progress') }}"></progress></div>
                        <div id="upload_stage" class="speedtest-live-stage"><div><span>{{ lang._('Upload') }}</span><span id="upload_status"></span></div><progress id="upload_progress" max="100" value="0" aria-label="{{ lang._('Upload progress') }}"></progress></div>
                    </div>
                    <p class="help-block">{{ lang._('The test continues if you leave this page. Avoid running the direct CLI at the same time.') }}</p>
                </div>
                <div id="live_chart_region" hidden>
                    <div class="speedtest-live-heading"><h4>{{ lang._('Speed during this test') }}</h4><p id="live_speed"></p></div>
                    <p id="live_chart_server" class="speedtest-secondary"></p>
                    <p id="live_chart_status" class="speedtest-status" role="status"></p>
                    <div class="speedtest-live-chart"><canvas id="live_chart" role="img" aria-label="{{ lang._('Download and upload running averages during the test; the latest value appears above') }}"></canvas></div>
                    <p class="help-block">{{ lang._('Points show the running average reported by LibreSpeed. Time starts again for each direction.') }}</p>
                </div>
                <div id="test_results" hidden aria-live="polite">
                    <div id="latest_success">
                        <dl class="speedtest-result-details">
                            <div><dt>{{ lang._('Server') }}</dt><dd id="test_server"></dd></div>
                            <div><dt>{{ lang._('Data transferred') }}</dt><dd id="transfer"></dd></div>
                            <div><dt>{{ lang._('Probe TLS') }}</dt><dd id="tls"></dd></div>
                        </dl>
                        <details class="speedtest-disclosure"><summary><i class="fa fa-angle-right" aria-hidden="true"></i>{{ lang._('About these measurements') }}</summary><div><p>{{ lang._('TLS describes the server probe, not every transfer connection. Packet loss and loaded latency are not reported.') }}</p></div></details>
                    </div>
                    <div class="table-responsive" id="comparison" hidden>
                        <table class="table table-striped"><caption>{{ lang._('Sequential server comparison') }}</caption><thead><tr><th>{{ lang._('Server') }}</th><th>{{ lang._('Download') }}</th><th>{{ lang._('Upload') }}</th><th>{{ lang._('Latency') }}</th><th>{{ lang._('Status') }}</th></tr></thead><tbody id="comparison_rows"></tbody></table>
                    </div>
                </div>
            </section>
            </div>
        </div>
    </div>
    <div id="history" class="tab-pane" role="tabpanel" aria-labelledby="history_tab">
        <div class="content-box-main">
            <h2>{{ lang._('Trends and history') }}</h2>
            <p class="section-note">{{ lang._('Explore saved tests and diagnostics. For meaningful comparisons, use the same server and test settings.') }}</p>
            <div id="history_status" class="speedtest-status" role="status" aria-live="polite"></div>
            <form id="history_filters">
                <div class="speedtest-toolbar">
                    <div><label for="history_days">{{ lang._('Period') }}</label><select id="history_days" class="form-control"><option value="1">{{ lang._('24 hours') }}</option><option value="7">{{ lang._('7 days') }}</option><option value="30" selected>{{ lang._('30 days') }}</option><option value="90">{{ lang._('90 days') }}</option><option value="365">{{ lang._('1 year') }}</option><option value="0">{{ lang._('All dates') }}</option></select></div>
                    <div><label for="history_server">{{ lang._('Server') }}</label><select id="history_server" class="form-control"><option value="all">{{ lang._('All servers') }}</option></select></div>
                    <div><label for="history_mode">{{ lang._('Mode') }}</label><select id="history_mode" class="form-control"><option value="all">{{ lang._('All modes') }}</option><option value="both">{{ lang._('Full test') }}</option><option value="download">{{ lang._('Download') }}</option><option value="upload">{{ lang._('Upload') }}</option><option value="latency">{{ lang._('Latency') }}</option></select></div>
                    <div><label for="history_provider">{{ lang._('Engine') }}</label><select id="history_provider" class="form-control"><option value="librespeed">LibreSpeed Rust</option><option value="legacy">{{ lang._('Legacy CSV') }}</option></select></div>
                    <div><label for="history_outcome">{{ lang._('Outcome') }}</label><select id="history_outcome" class="form-control"><option value="all">{{ lang._('All outcomes') }}</option><option value="success">{{ lang._('Successful') }}</option><option value="failed">{{ lang._('Failed') }}</option></select></div>
                </div>
                <details class="speedtest-disclosure">
                    <summary><i class="fa fa-angle-right" aria-hidden="true"></i>{{ lang._('More filters') }}</summary>
                    <div class="speedtest-toolbar">
                        <div><label for="history_origin">{{ lang._('Trigger') }}</label><select id="history_origin" class="form-control"><option value="all">{{ lang._('All triggers') }}</option><option value="manual">{{ lang._('GUI') }}</option><option value="scheduled">{{ lang._('Scheduled') }}</option><option value="cli">{{ lang._('CLI / legacy cron') }}</option><option value="legacy">{{ lang._('Imported CSV') }}</option></select></div>
                        <div><label for="history_family">{{ lang._('IP family setting') }}</label><select id="history_family" class="form-control"><option value="all">{{ lang._('All families') }}</option><option value="auto">{{ lang._('Automatic') }}</option><option value="ipv4">IPv4</option><option value="ipv6">IPv6</option></select></div>
                        <div><label for="history_source">{{ lang._('Source binding') }}</label><select id="history_source" class="form-control"><option value="all">{{ lang._('All sources') }}</option></select></div>
                    </div>
                </details>
            </form>
            <p id="history_summary" class="numeric"></p>
            <div class="row" id="trend_charts" hidden>
                <div class="col-md-6"><h3>{{ lang._('Throughput trend') }}</h3><div class="speedtest-chart"><canvas id="throughput_chart" role="img" aria-label="{{ lang._('Historical download and upload averages; exact values are available in the table below') }}"></canvas></div></div>
                <div class="col-md-6"><h3>{{ lang._('Latency and jitter trend') }}</h3><div class="speedtest-chart"><canvas id="latency_chart" role="img" aria-label="{{ lang._('Historical latency and jitter averages; exact values are available in the table below') }}"></canvas></div></div>
            </div>
            <p id="chart_note" class="help-block"></p>
            <div class="table-responsive"><table class="table table-condensed"><caption>{{ lang._('Successful measurements only; unmeasured values are excluded.') }}</caption><thead><tr><th>{{ lang._('Metric') }}</th><th>{{ lang._('Average') }}</th><th>{{ lang._('Minimum') }}</th><th>{{ lang._('Maximum') }}</th></tr></thead><tbody id="history_metrics"></tbody></table></div>
            <div class="speedtest-actions">
                <a href="/api/speedtest/download/csv" class="btn btn-default">{{ lang._('Export full-test CSV') }}</a>
                <a href="/api/speedtest/download/json" class="btn btn-default">{{ lang._('Export detailed JSONL') }}</a>
                <button class="btn btn-default" id="refresh_history" type="button">{{ lang._('Refresh') }}</button>
                {% if canClear %}<button class="btn btn-danger" id="deletelogAct" type="button">{{ lang._('Clear history') }}</button>{% endif %}
            </div>
            <div class="table-responsive">
                <table class="table table-striped table-condensed">
                    <caption>{{ lang._('Recorded tests') }}</caption>
                    <thead><tr>
                        <th scope="col">{{ lang._('Time (browser local)') }}</th><th scope="col">{{ lang._('Server / details') }}</th><th scope="col">{{ lang._('Mode') }}</th>
                        <th scope="col">{{ lang._('Download') }}</th><th scope="col">{{ lang._('Upload') }}</th><th scope="col">{{ lang._('Latency') }}</th><th scope="col">{{ lang._('Jitter') }}</th><th scope="col">{{ lang._('Trigger / outcome') }}</th>
                    </tr></thead>
                    <tbody id="log_block"></tbody>
                </table>
            </div>
            <div class="speedtest-toolbar"><button id="history_previous" type="button" class="btn btn-default">{{ lang._('Newer') }}</button><span id="history_page"></span><button id="history_next" type="button" class="btn btn-default">{{ lang._('Older') }}</button></div>
            <p class="help-block">{{ lang._('Exports include all retained dates, not just the current filters. CSV contains full tests; JSONL contains detailed records and any consolidated legacy data. Clearing history removes both.') }}</p>
        </div>
    </div>
    {% if canSchedule %}
    <div id="schedule" class="tab-pane" role="tabpanel" aria-labelledby="schedule_tab">
        <div class="content-box-main">
            <h2>{{ lang._('Schedule') }}</h2>
            <p class="section-note">{{ lang._('Run tests automatically using OPNsense cron. A daily test outside busy hours is a useful starting point; throughput tests can use substantial data.') }}</p>
            <p id="schedule_timezone"></p><p id="schedule_conflicts" class="text-warning"></p>
            <form id="schedule_form" class="form-horizontal"><fieldset id="schedule_controls" disabled>
                <div class="form-group"><div class="col-sm-offset-3 col-sm-9"><div class="checkbox"><label><input id="schedule_enabled" type="checkbox">{{ lang._('Enable scheduled measurements') }}</label></div></div></div>
                <div class="form-group"><label for="schedule_cadence" class="col-sm-3 control-label">{{ lang._('Frequency') }}</label><div class="col-sm-9"><select id="schedule_cadence" class="form-control"><option value="hourly">{{ lang._('Hourly') }}</option><option value="daily">{{ lang._('Daily') }}</option><option value="weekdays">{{ lang._('Weekdays') }}</option><option value="weekly">{{ lang._('Weekly') }}</option></select></div></div>
                <div class="form-group"><label for="schedule_hour" class="col-sm-3 control-label">{{ lang._('Hour') }}</label><div class="col-sm-9"><input id="schedule_hour" class="form-control" type="number" min="0" max="23" value="3" required></div></div>
                <div class="form-group"><label for="schedule_minute" class="col-sm-3 control-label">{{ lang._('Minute') }}</label><div class="col-sm-9"><input id="schedule_minute" class="form-control" type="number" min="0" max="59" value="0" required></div></div>
                <div class="form-group"><label for="schedule_weekday" class="col-sm-3 control-label">{{ lang._('Day of week') }}</label><div class="col-sm-9"><select id="schedule_weekday" class="form-control"><option value="0">{{ lang._('Sunday') }}</option><option value="1">{{ lang._('Monday') }}</option><option value="2">{{ lang._('Tuesday') }}</option><option value="3">{{ lang._('Wednesday') }}</option><option value="4">{{ lang._('Thursday') }}</option><option value="5">{{ lang._('Friday') }}</option><option value="6">{{ lang._('Saturday') }}</option></select></div></div>
                <div class="form-group"><label for="schedule_server" class="col-sm-3 control-label">{{ lang._('Server selection') }}</label><div class="col-sm-9"><input id="schedule_server" class="form-control" type="text" value="0" pattern="0|-1|[1-9][0-9]*(,[1-9][0-9]*)*" required><span class="help-block">{{ lang._('0: lowest latency. -1: compare all. Or enter configured IDs, such as 42,84. Comparisons run sequentially.') }}</span></div></div>
                <div class="form-group"><label for="schedule_mode" class="col-sm-3 control-label">{{ lang._('Test mode') }}</label><div class="col-sm-9"><select id="schedule_mode" class="form-control"><option value="both">{{ lang._('Full test (recommended)') }}</option><option value="download">{{ lang._('Download only') }}</option><option value="upload">{{ lang._('Upload only') }}</option><option value="latency">{{ lang._('Latency and jitter only') }}</option></select><span class="help-block">{{ lang._('All modes measure latency and jitter. The full test also measures download and upload.') }}</span></div></div>
                <div class="form-group"><div class="col-sm-offset-3 col-sm-9"><p id="schedule_preview"></p><p class="help-block">{{ lang._('Saved measurement defaults apply at execution time. Overlapping tests are refused. Cron uses the firewall timezone and may skip or repeat a wall-clock time at daylight-saving changes.') }}</p><button id="save_schedule" class="btn btn-primary" type="submit">{{ lang._('Save and apply schedule') }}</button> <button id="apply_schedule" class="btn btn-default" type="button">{{ lang._('Apply saved schedule') }}</button></div></div>
            </fieldset></form>
            <div id="schedule_status" class="speedtest-status" role="status" aria-live="polite"></div>
            <p><a href="/ui/cron">{{ lang._('Open OPNsense cron for additional schedules') }}</a></p>
        </div>
    </div>
    {% endif %}
    <div id="setup" class="tab-pane" role="tabpanel" aria-labelledby="setup_tab">
        <div class="content-box-main speedtest-settings">
            <h2>{{ lang._('Setup and CLI') }}</h2>
            <p class="section-note">{{ lang._('Choose a server source and history retention. The advanced options on Run test can also be saved as defaults.') }}</p>
            {% if canConfigure %}
            <div class="checkbox"><label><input id="public_servers" type="checkbox">{{ lang._('Use the official LibreSpeed.org public server list when no custom servers are saved') }}</label></div>
            <p class="help-block">{{ lang._('The firewall retrieves the public list over HTTPS.') }} <a href="https://librespeed.org/backend-servers/servers.php" target="_blank" rel="noopener noreferrer">{{ lang._('View official server list') }}</a>. {{ lang._('The registry and selected test servers can see the firewall public IP. No results or telemetry are shared; opt out or use servers you operate or are authorized to use.') }}</p>
            <h3>{{ lang._('Servers') }}</h3>
            <label for="servers_json">{{ lang._('Authorized servers (JSON)') }}</label>
            <textarea id="servers_json" class="form-control" rows="7" spellcheck="false" aria-describedby="servers_help"></textarea>
            <p id="servers_help" class="help-block">{{ lang._('Add up to 50 servers with unique IDs and relative endpoint paths. Saved servers take priority. If this list is empty, the firewall-managed file is checked before the optional public list:') }} <code>/usr/local/etc/speedtest-community/librespeed-servers.json</code></p>
            <details class="speedtest-disclosure">
                <summary><i class="fa fa-angle-right" aria-hidden="true"></i>{{ lang._('Show server example') }}</summary>
                <div><p>{{ lang._('Replace the example address and paths with those for your authorized server.') }}</p>
                <pre>[
  {
    "id": 42,
    "name": "Lab",
    "server": "https://bench.example.net/",
    "dlURL": "garbage.php",
    "ulURL": "empty.php",
    "pingURL": "empty.php",
    "getIpURL": "getIP.php"
  }
]</pre></div>
            </details>
            <h3>{{ lang._('History retention') }}</h3>
            <form id="retention_form" class="speedtest-toolbar">
                <div><label for="retention_days">{{ lang._('Keep history for days') }}</label><input id="retention_days" class="form-control" type="number" min="0" max="3650" value="0" required></div>
                <div><label for="history_limit">{{ lang._('Maximum history records') }}</label><input id="history_limit" class="form-control" type="number" min="0" max="100000" value="0" required></div>
            </form>
            <p class="help-block">{{ lang._('0 keeps all history. Limits prune detailed records and legacy CSV after the next test. Export your data before reducing retention.') }}</p>
            <p>{{ lang._('Saving also sets the current advanced options as defaults for GUI, cron and terminal tests. No restart is needed.') }}</p>
            <button id="save_settings" type="button" class="btn btn-primary" disabled>{{ lang._('Save settings') }}</button>
            <div id="settings_status" class="speedtest-status" role="status" aria-live="polite"></div>
            {% else %}
            <p>{{ lang._('You need the LibreSpeed configure privilege to change server and retention settings.') }}</p>
            {% endif %}
            <details class="speedtest-disclosure">
                <summary><i class="fa fa-angle-right" aria-hidden="true"></i>{{ lang._('Connection security and privacy') }}</summary>
                <div>
                    <p>{{ lang._('Test endpoints must use HTTPS with verified certificates. This is independent of whether the OPNsense GUI uses HTTP or HTTPS.') }}</p>
                    <p>{{ lang._('For private endpoints, install a PEM CA bundle at /usr/local/etc/speedtest-community/ca.pem and enable the private CA option. It replaces the engine trust store for that run. Use separate issuing CA and server certificates.') }}</p>
                    <p>{{ lang._('When enabled, the public server list is retrieved from LibreSpeed.org over HTTPS only if no saved or firewall-managed list is available. The registry and selected test server can see the firewall public IP. The plugin does not request result sharing or telemetry. A configured source binding is retained for comparison; older CSV data is preserved.') }}</p>
                </div>
            </details>
            <details class="speedtest-disclosure">
                <summary><i class="fa fa-angle-right" aria-hidden="true"></i>{{ lang._('Terminal commands') }}</summary>
                <div><pre>opn-librespeed --help
opn-librespeed list
opn-librespeed run --server 42 --duration 15 --family ipv4
opn-librespeed run --mode latency --format json
opn-librespeed run --server 42 --server 84
opn-librespeed run --all-servers
opn-librespeed history --days 30 --format json
opn-librespeed stat
librespeed-cli --help</pre>
                <p>{{ lang._('opn-librespeed shares the GUI lock and history. Direct librespeed-cli runs expose upstream options but do not enter plugin history; do not run them alongside GUI or cron tests.') }}</p></div>
            </details>
            <details class="speedtest-disclosure">
                <summary><i class="fa fa-angle-right" aria-hidden="true"></i>{{ lang._('Permissions and support') }}</summary>
                <div>
                    <p>{{ lang._('Assign privileges under System > Access > Users or Groups. View results includes charts, dashboard data and exports. Running tests, configuring settings, managing the schedule and clearing history require separate privileges. Grant View results alongside additional privileges. Read-only accounts cannot run tests or change settings.') }}</p>
                    <ul>
                        <li><a href="https://github.com/blackoutsecure/opn-repo/tree/main/net-mgmt/speedtest-community" target="_blank" rel="noopener noreferrer">{{ lang._('Plugin setup and capability notes') }}</a></li>
                        <li><a href="https://github.com/blackoutsecure/opn-repo/issues" target="_blank" rel="noopener noreferrer">{{ lang._('Report plugin issues') }}</a></li>
                        <li><a href="https://github.com/librespeed/speedtest-cli-rust" target="_blank" rel="noopener noreferrer">{{ lang._('LibreSpeed Rust client') }}</a></li>
                        <li><a href="https://github.com/librespeed/speedtest" target="_blank" rel="noopener noreferrer">{{ lang._('LibreSpeed server setup') }}</a></li>
                        <li><a href="https://github.com/librespeed/speedtest-rust" target="_blank" rel="noopener noreferrer">{{ lang._('Optional Rust server backend') }}</a></li>
                    </ul>
                </div>
            </details>
        </div>
    </div>
</div>
<script>
    const api = "/api/speedtest/service/";
    let historyLoaded = false;
    let running = false;
    let starting = false;
    let otherOperation = false;
    let engineReady = false;
    let serversReady = false;
    let serversLoading = false;
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
    let liveChart = null;
    let liveState = null;
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
        $('#reportAct').prop('disabled', running || saving || !engineReady || !serversReady || !defaultsReady || !canRun);
        $('#serverlistAct').prop('disabled', running || saving || serversLoading);
        $('#save_settings').prop('disabled', running || saving || !defaultsReady || !settingsReady);
        $('#public_servers').prop('disabled', running || saving || !settingsReady);
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
    function readableError(message) {
        return typeof message === 'string'
            ? message.replace(/^Speedtest failed:\s*(?:[A-Za-z][A-Za-z0-9]*(?:Error|Exception):\s*)?/, '')
            : '';
    }
    function request(action, data, callback, status, timeout = 30000) {
        return $.ajax({url: action.startsWith('/') ? action : api + action, type: 'POST', data: data, dataType: 'json', timeout: timeout})
            .done(callback)
            .fail(function(xhr, reason) {
                showStatus(status, reason === 'timeout'
                    ? "{{ lang._('The request timed out. Check your session and backend logs.') }}"
                    : "{{ lang._('The service could not be reached. Check your session and backend logs.') }}", true);
            });
    }
    function serversReload() {
        if (serversLoading) return;
        serversLoading = true;
        serversReady = false;
        $('#server_setup_notice').prop('hidden', true);
        showStatus('#server_status', "{{ lang._('Loading servers...') }}");
        updateControls();
        request('serverlist', {}, function(data) {
            if (!Array.isArray(data)) {
                if (data?.code === 'servers_unconfigured') {
                    showStatus('#server_status', '');
                    $('#server_setup_notice').prop('hidden', false);
                } else {
                    const detail = readableError(data?.error);
                    showStatus('#server_status', "{{ lang._('Unable to load servers') }}" + (detail ? ': ' + detail : '.'), true);
                }
                return;
            }
            if (!data.length) {
                showStatus('#server_status', "{{ lang._('No servers were returned. Check the server configuration and refresh.') }}", true);
                return;
            }
            if (data.some(server => !server || typeof server.id !== 'string' || !/^[1-9][0-9]*$/.test(server.id)
                || typeof server.name !== 'string' || !server.name.trim())) {
                showStatus('#server_status', "{{ lang._('The server list was invalid. Check the configuration and backend logs.') }}", true);
                return;
            }
            const selected = $('#serverid').val();
            $('#serverid').empty()
                .append($('<option/>').val('0').text("{{ lang._('Automatic selection') }}"))
                .append($('<option/>').val('-1').text("{{ lang._('Compare all servers') }}"))
                .append($('<option/>').val('custom').text("{{ lang._('Choose server IDs') }}"));
            data.forEach(server => $('#serverid').append($('<option/>').val(server.id).text('(' + server.id + ') ' + server.name)));
            $('#serverid').val(['0', '-1', 'custom'].includes(selected) || data.some(server => server.id === selected) ? selected : '0');
            serversReady = true;
            showStatus('#server_status', '');
        }, '#server_status').always(function() {
            serversLoading = false;
            updateControls();
        });
    }
    function number(value, suffix = '') {
        return value === undefined || value === null ? "{{ lang._('Not measured') }}"
            : Number(value).toLocaleString(undefined, {maximumFractionDigits: 2}) + suffix;
    }
    function speedDivisor() {
        return $('#units').val() === 'MiBps' ? 8.388608 : $('#units').val() === 'MBps' ? 8 : 1;
    }
    function speed(value) {
        const unit = $('#units').val();
        return number(value === undefined || value === null ? null : value / speedDivisor(),
            unit === 'MiBps' ? ' MiB/s' : unit === 'MBps' ? ' MB/s' : ' Mbps');
    }
    function metricValue(key, value) {
        return ['download', 'upload'].includes(key) ? speed(value) : number(value, ' ms');
    }
    function renderResults(results) {
        latestResults = results;
        const result = results.find(item => !item.error);
        Object.keys(metricNames).forEach(key => {
            const value = result?.[key];
            $('#' + key).text(metricValue(key, value)).toggleClass('is-empty', value === undefined || value === null);
        });
        $('#readout_hint').text(running ? "{{ lang._('Test in progress. Results appear when it finishes.') }}"
            : result ? "{{ lang._('Most recent completed test.') }}"
            : results.length ? "{{ lang._('No successful measurements in this test.') }}"
            : "{{ lang._('Run a test to see measurements here.') }}");
        $('#test_results').prop('hidden', !results.length);
        $('#latest_success').prop('hidden', !result);
        if (result) {
            $('#test_server').text('(' + result.serverid + ') ' + result.servername);
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
                item.error ? "{{ lang._('Failed') }}: " + readableError(item.error) : "{{ lang._('Saved') }}"]
                .forEach(value => row.append($('<td/>').text(value)));
            rows.append(row);
        });
        if (results.length > 1) $('#test_results').prop('hidden', false);
    }
    function renderLive(state) {
        liveState = state;
        const samples = {};
        ['download', 'upload'].forEach(key => {
            const points = state?.samples?.[key];
            samples[key] = Array.isArray(points) ? points.filter(point => point
                && Number.isFinite(point.seconds) && point.seconds >= 0
                && Number.isFinite(point.mbps) && point.mbps >= 0) : [];
        });
        if (state?.status === 'running') {
            const phases = ['selecting', 'ping'];
            if (['both', 'download'].includes(state.mode)) phases.push('download');
            if (['both', 'upload'].includes(state.mode)) phases.push('upload');
            const current = phases.indexOf(state.phase);
            $('#download_stage').prop('hidden', !phases.includes('download'));
            $('#upload_stage').prop('hidden', !phases.includes('upload'));
            phases.forEach((phase, index) => {
                const bar = $('#' + phase + '_progress');
                const label = $('#' + phase + '_status');
                if (current === index && ['selecting', 'ping'].includes(phase)) {
                    bar.removeAttr('value');
                    label.text("{{ lang._('In progress') }}");
                } else {
                    const value = current > index ? 100 : current === index
                        ? Math.max(0, Math.min(100, Number(state.progress) || 0)) : 0;
                    bar.val(value);
                    label.text(value === 100 ? "{{ lang._('Complete') }}"
                        : current === index ? value + '%' : "{{ lang._('Waiting') }}");
                }
            });
            ['download', 'upload'].forEach(key => {
                const point = samples[key].at(-1);
                $('#' + key).text(speed(point?.mbps)).toggleClass('is-empty', !point);
            });
        }
        const hasSamples = samples.download.length || samples.upload.length;
        $('#live_chart_region').prop('hidden', !hasSamples);
        if (!hasSamples) {
            if (liveChart) liveChart.destroy();
            liveChart = null;
            return;
        }
        const direction = ['download', 'upload'].includes(state.phase) ? state.phase
            : samples.upload.length ? 'upload' : 'download';
        const point = samples[direction].at(-1);
        $('#live_chart_server').text(state.server || '');
        $('#live_speed').text(point ? metricNames[direction] + ': ' + speed(point.mbps)
            : "{{ lang._('Waiting for the first speed sample.') }}");
        if (typeof Chart !== 'function') {
            $('.speedtest-live-chart').prop('hidden', true);
            showStatus('#live_chart_status', "{{ lang._('Live chart unavailable. Progress and the latest speed remain visible.') }}", true);
            return;
        }
        $('.speedtest-live-chart').prop('hidden', false);
        showStatus('#live_chart_status', '');
        const unit = $('#units').val();
        const color = getComputedStyle(document.body).color;
        const datasets = ['download', 'upload'].map((key, index) => ({
            label: metricNames[key],
            data: samples[key].map(item => ({x: item.seconds, y: item.mbps / speedDivisor()})),
            borderColor: index ? '#00818b' : '#b52da5', backgroundColor: index ? '#00818b' : '#b52da5',
            borderWidth: 2, pointRadius: 2, spanGaps: false
        }));
        const unitLabel = unit === 'MiBps' ? 'MiB/s' : unit === 'MBps' ? 'MB/s' : 'Mbps';
        if (!liveChart) {
            liveChart = new Chart(document.getElementById('live_chart'), {
                type: 'line', data: {datasets: datasets},
                options: {
                    responsive: true, maintainAspectRatio: false, animation: false, parsing: false,
                    interaction: {mode: 'nearest', intersect: false},
                    plugins: {legend: {labels: {color: color}}},
                    scales: {
                        x: {type: 'linear', beginAtZero: true, ticks: {color: color, maxTicksLimit: 6},
                            title: {display: true, color: color, text: "{{ lang._('Seconds per direction') }}"}},
                        y: {beginAtZero: true, ticks: {color: color}, title: {display: true, color: color, text: unitLabel}}
                    }
                }
            });
        } else {
            liveChart.data.datasets = datasets;
            liveChart.options.scales.y.title.text = unitLabel;
            liveChart.update('none');
        }
    }
    function renderCharts(data) {
        charts.forEach(chart => chart.destroy());
        charts = [];
        $('#trend_charts').prop('hidden', !data.series.length);
        $('.speedtest-chart').prop('hidden', !data.series.length);
        if (!data.series.length) return;
        if (typeof Chart !== 'function') {
            $('#trend_charts').prop('hidden', true);
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
                    borderColor: index ? '#00818b' : '#b52da5', backgroundColor: index ? '#00818b' : '#b52da5',
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
                + (item.error ? "{{ lang._('Failed') }}: " + readableError(item.error) : "{{ lang._('Successful') }}")));
            rows.append(row);
        });
        if (!data.rows.length) rows.append($('<tr/>').append($('<td/>').attr('colspan', '8')
            .text("{{ lang._('No measurements to display.') }}")));
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
            + "{{ lang._('Only measured values are averaged. Table times use your browser timezone. Transfer totals exclude legacy records without byte counters.') }}"
            : "{{ lang._('No successful measurements for a trend. Run a test or adjust the filters.') }}");
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
                    showStatus('#history_status', readableError(data?.error) || "{{ lang._('Unable to load history') }}", true);
                    return;
                }
                historyLoaded = true;
                renderHistory(data);
            }).fail(function() {
                if (generation === historyGeneration) showStatus('#history_status', "{{ lang._('Unable to load history. Check your session and refresh.') }}", true);
            });
    }
    function followStatus(expected = null, queued = Date.now(), generation = ++pollGeneration, failures = 0) {
        clearTimeout(pollTimer);
        request('status', {}, function(state) {
            if (generation !== pollGeneration) return;
            if (!['idle', 'running', 'busy', 'completed', 'failed'].includes(state?.status)) {
                showStatus('#test_status', readableError(state?.error) || "{{ lang._('Unable to read test status. Use Refresh status to retry.') }}", true);
                return;
            }
            if (state.status === 'busy') {
                otherOperation = true;
                if (!running) renderResults([]);
                running = true;
                updateControls();
                $('#run_progress').prop('hidden', true);
                renderLive(null);
                $('#readout_hint').text("{{ lang._('Live progress is unavailable for this operation.') }}");
                showStatus('#test_status', "{{ lang._('Another test or history operation is in progress. Wait for it to finish.') }}");
                pollTimer = setTimeout(() => followStatus(expected, queued, generation), 1500);
                return;
            }
            if (expected && state.run_id !== expected && state.status !== 'running') {
                if (Date.now() - queued < 15000) {
                    pollTimer = setTimeout(() => followStatus(expected, queued, generation), 1500);
                } else {
                    running = false;
                    otherOperation = false;
                    renderResults([]);
                    updateControls();
                    $('#run_progress').prop('hidden', true);
                    showStatus('#test_status', "{{ lang._('The queued test did not start. Check backend logs and refresh status before retrying.') }}", true);
                }
                return;
            }
            const finishedOtherOperation = otherOperation && !expected;
            otherOperation = false;
            const wasRunning = running;
            if (state.status === 'running' && !wasRunning) renderResults([]);
            running = state.status === 'running';
            updateControls();
            $('#run_progress').prop('hidden', !running);
            renderLive(state.status === 'idle' ? null : state);
            if (running) {
                const phases = {selecting: "{{ lang._('Selecting server') }}", ping: "{{ lang._('Measuring latency') }}",
                    download: "{{ lang._('Measuring download') }}", upload: "{{ lang._('Measuring upload') }}"};
                const parts = [state.server, phases[state.phase] || state.phase];
                if (state.total > 1) parts.push("{{ lang._('Server') }} " + Math.min(state.completed + 1, state.total) + '/' + state.total);
                showStatus('#phase_status', parts.filter(Boolean).join(' · '));
                $('#readout_hint').text("{{ lang._('Live speeds are running averages. Final results appear when the test finishes.') }}");
                showStatus('#test_status', "{{ lang._('Test in progress. Throughput measurements may saturate the connection.') }}");
                if (Date.now() / 1000 > state.deadline + 30) {
                    showStatus('#test_status', "{{ lang._('The test exceeded its expected deadline. Check backend logs; a lock may still be held. Refresh status to check again.') }}", true);
                    return;
                }
                pollTimer = setTimeout(() => followStatus(state.run_id, queued, generation), 1500);
            } else if (state.status !== 'idle') {
                renderResults(state.results || []);
                const failure = readableError(state.error);
                let message = state.status === 'failed'
                    ? failure || "{{ lang._('The test failed. Check backend logs.') }}"
                    : "{{ lang._('Test complete. Results saved to history.') }}";
                if (finishedOtherOperation) {
                    message = state.status === 'failed'
                        ? "{{ lang._('Another operation finished. The most recent saved test failed.') }}" + (failure ? ' ' + failure : '')
                        : "{{ lang._('Another operation finished. Showing the most recent saved test.') }}";
                }
                showStatus('#test_status', message, state.status === 'failed');
                historyLoaded = false;
            } else if (wasRunning) {
                $('#readout_hint').text("{{ lang._('Run a test to see measurements here.') }}");
                showStatus('#test_status', "{{ lang._('No test is currently running.') }}");
            }
        }, '#test_status').fail(function() {
            if (generation !== pollGeneration) return;
            if (failures < 2) {
                pollTimer = setTimeout(() => followStatus(expected, queued, generation, failures + 1), 3000);
            } else {
                showStatus('#test_status', "{{ lang._('Progress connection lost. The test may still be running. Refresh status after restoring your session.') }}", true);
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
        const tabs = $('.speedtest-tabs a[role="tab"]');
        tabs.on('shown.bs.tab', function() {
            tabs.attr('aria-selected', 'false').attr('tabindex', '-1');
            $(this).attr('aria-selected', 'true').attr('tabindex', '0');
        }).on('keydown', function(event) {
            const index = tabs.index(this);
            if (index < 0 || !['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return;
            event.preventDefault();
            const next = event.key === 'Home' ? 0 : event.key === 'End' ? tabs.length - 1
                : (index + (event.key === 'ArrowRight' ? 1 : -1) + tabs.length) % tabs.length;
            tabs.eq(next).tab('show').trigger('focus');
        });
        if (canConfigure) {
            $('#open_server_setup').on('click', function(event) {
                event.preventDefault();
                $('#setup_tab').tab('show');
                $('#servers_json').trigger('focus');
            });
        }
        $('#test_form')[0].addEventListener('invalid', function() {
            $('#test_form details').prop('open', true);
        }, true);
        request('defaults', {}, function(data) {
            if (!data || data.error) {
                showStatus('#test_status', readableError(data?.error) || "{{ lang._('Unable to load saved defaults') }}", true);
                return;
            }
            optionKeys.forEach(key => { if (data[key] !== undefined) $('#' + key).val(data[key]); });
            booleanKeys.forEach(key => $('#' + key).prop('checked', data[key] === '1'));
            ['retention_days', 'history_limit'].forEach(key => {
                $('#' + key).val(data[key] || '0');
                savedRetention[key] = Number(data[key] || 0);
            });
            $('#public_servers').prop('checked', data.public_servers === '1');
            defaultsReady = true;
            updateControls();
            followStatus();
            $('#check_status').on('click', () => followStatus());
            $('#serverid').on('change', updateControls);
            $('#units').on('change', function() {
                if (!running) renderResults(latestResults);
                if (liveState) renderLive(liveState);
                if (historyData) renderHistory(historyData);
            });
            $(window).on('pagehide', function() { ++pollGeneration; clearTimeout(pollTimer); });
            if (canSchedule) {
                request('/api/speedtest/schedule/get', {}, function(data) {
                    if (!data?.schedule || data.error) {
                        showStatus('#schedule_status', readableError(data?.error) || "{{ lang._('Unable to load the schedule. Reload before saving.') }}", true);
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
                        : readableError(data?.error) || JSON.stringify(data?.validations || data), data?.result !== 'saved');
                }, '#schedule_status').always(function() { saving = false; updateControls(); schedulePreview(); });
            });
            $('#apply_schedule').on('click', function() {
                if (!canSchedule || saving || running || !scheduleReady) return;
                saving = true;
                updateControls();
                request('/api/speedtest/schedule/apply', {}, function(data) {
                    showStatus('#schedule_status', readableError(data?.error) || (data?.result === 'saved'
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
            options.public_servers = $('#public_servers').prop('checked') ? '1' : '0';
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
                        showStatus('#settings_status', readableError(data?.error) || JSON.stringify(data?.validations || data) || "{{ lang._('Settings were not saved') }}", true);
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
            if (typeof data?.message !== 'string' || !data.message || data.error) {
                showStatus('#version', readableError(data?.error) || "{{ lang._('LibreSpeed setup is incomplete. See Setup and CLI.') }}", true);
                updateControls();
                return;
            }
            const version = data.message.match(/^librespeed-cli\s+(v[^\s]+)(?:\s+\(built on 1970-01-01 00:00:00 UTC\))?$/i);
            showStatus('#version', version ? 'LibreSpeed CLI ' + version[1] : data.message);
            engineReady = true;
            updateControls();
            serversReload();
        }, '#version');
        $('#serverlistAct').on('click', serversReload);
        $('a[href="#history"]').on('shown.bs.tab', function() {
            if (!historyLoaded) historyReload();
            charts.forEach(chart => chart.resize());
        });
        $('a[href="#measurement"]').on('shown.bs.tab', function() {
            if (liveChart) liveChart.resize();
        });
        $('#history_filters').on('change', function() { historyPage = 1; historyReload(); });
        $('#history_previous').on('click', function() { if (historyPage > 1) { historyPage--; historyReload(); } });
        $('#history_next').on('click', function() { if (historyPage < 200) { historyPage++; historyReload(); } });
        $('#refresh_history').on('click', historyReload);
        $('#test_form').on('submit', function(event) {
            event.preventDefault();
            if (!canRun || !engineReady || !serversReady || !defaultsReady || running || saving || !this.reportValidity()) return;
            const options = currentOptions();
            const mode = $('#mode').val();
            const server = $('#serverid').val() === 'custom' ? $('#custom_servers').val() : $('#serverid').val();
            ++pollGeneration;
            clearTimeout(pollTimer);
            starting = true;
            running = true;
            updateControls();
            renderResults([]);
            renderLive(null);
            showStatus('#test_status', "{{ lang._('Starting test...') }}");
            request('start/' + encodeURIComponent(server) + '/' + mode, options, function(data) {
                if (data?.result !== 'started' || !data.run_id) {
                    running = false;
                    renderResults([]);
                    updateControls();
                    showStatus('#test_status', readableError(data?.error) || "{{ lang._('Unable to start a test. Check backend logs.') }}", true);
                    return;
                }
                followStatus(data.run_id);
            }, '#test_status').fail(function() {
                $('#readout_hint').text("{{ lang._('Test status is unknown. Refresh status to check.') }}");
                showStatus('#test_status', "{{ lang._('Start response lost. The test may have started; refresh status before retrying.') }}", true);
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
                    showStatus('#history_status', readableError(data?.error) || "{{ lang._('Unable to clear history') }}", true);
                    return;
                }
                historyReload();
            }, '#history_status').always(() => $('#deletelogAct').prop('disabled', false));
        });
    });
</script>
