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
    .speedtest-heading { display: flex; align-items: flex-start; gap: 12px; }
    .speedtest-heading img { flex: none; border-radius: 50%; }
    .speedtest-engine { display: flex; flex-wrap: wrap; align-items: baseline; gap: 4px 12px; }
    .speedtest-notice { display: flex; gap: 12px; align-items: flex-start; padding: 14px 16px; margin: 0 0 20px; border: 1px solid rgba(127, 127, 127, .45); border-radius: 3px; }
    .speedtest-notice i { margin-top: 2px; }
    .speedtest-notice p { margin: 4px 0; }
    .speedtest-status:not(:empty) { margin: 0 0 16px; line-height: 1.4; }
    #check_status { margin-bottom: 16px; }
    .speedtest-workspace { display: grid; gap: 28px; max-width: 1100px; margin: 0 auto; }
    .speedtest-run-form fieldset { min-width: 0; max-width: 720px; margin: 0 auto; }
    .speedtest-run-form .speedtest-actions { justify-content: center; }
    .speedtest-run-form #reportAct { min-width: 220px; padding: 14px 28px; font-size: 1.15em; }
    .speedtest-run-form #open_test_settings { display: block; text-align: center; }
    .speedtest-detected-server { display: block; font-size: 1.25em; font-weight: 600; margin: 12px 0 4px; overflow-wrap: anywhere; }
    .speedtest-connection { margin: 18px 0; text-align: center; overflow-wrap: anywhere; }
    .speedtest-connection p { margin: 4px 0; }
    .speedtest-field { margin: 0 0 16px; }
    .speedtest-field > label, .speedtest-toolbar label { display: block; }
    .speedtest-server-control { display: flex; gap: 8px; }
    .speedtest-server-control select { min-width: 0; flex: 1; }
    .speedtest-option-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0 12px; }
    .speedtest-actions { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; margin: 16px 0; }
    .speedtest-readout { min-width: 0; }
    .speedtest-readout-header { display: flex; flex-wrap: wrap; justify-content: space-between; gap: 12px 20px; }
    .speedtest-readout-header p { margin: 0; }
    .speedtest-metrics { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 20px 32px; margin: 24px 0; text-align: center; }
    .speedtest-metrics > div { min-width: 0; }
    .speedtest-metrics .speedtest-throughput { display: flex; flex-direction: column; }
    .speedtest-throughput dt { order: 2; }
    .speedtest-metrics dd.speedtest-gauge { position: relative; font-size: 1em; width: 100%; max-width: 400px; margin: 0 auto; }
    .speedtest-gauge svg { display: block; width: 100%; height: auto; overflow: visible; }
    .speedtest-gauge-readout { position: absolute; top: 48%; left: 4%; right: 4%; font-size: clamp(1.15em, 3vw, 2.4em); white-space: nowrap; }
    .speedtest-gauge-readout.is-empty { font-size: 1em; }
    .speedtest-gauge-scale { position: absolute; bottom: 8%; left: 0; right: 0; font-size: .85em; font-weight: 400; }
    .speedtest-gauge-track { stroke: currentColor; opacity: .2; }
    .speedtest-gauge-download { color: #b52da5; }
    .speedtest-gauge-upload { color: #00818b; }
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
    #catalog_table, #custom_server_table { max-height: 24rem; overflow: auto; }
    #catalog_rows td:first-child, #custom_server_rows td:first-child { overflow-wrap: anywhere; }
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
    .speedtest-support { display: flex; align-items: center; gap: 16px; border-top: 1px solid rgba(127, 127, 127, .45); }
    .speedtest-support img { flex: none; border-radius: 50%; }
    .speedtest-support div { min-width: 0; }
    .speedtest-support p { margin: 0; overflow-wrap: anywhere; }
    .speedtest-support p + p { margin-top: 4px; }
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
        .speedtest-metrics { gap: 20px 12px; }
    }
</style>
<ul class="nav nav-tabs speedtest-tabs" role="tablist" aria-label="{{ lang._('Speedtest sections') }}">
    <li class="active" role="presentation"><a id="measurement_tab" href="#measurement" data-toggle="tab" role="tab" aria-controls="measurement" aria-selected="true">{{ lang._('Run test') }}</a></li>
    <li role="presentation"><a id="history_tab" href="#history" data-toggle="tab" role="tab" aria-controls="history" aria-selected="false" tabindex="-1">{{ lang._('Trends and history') }}</a></li>
    {% if canSchedule %}<li role="presentation"><a id="schedule_tab" href="#schedule" data-toggle="tab" role="tab" aria-controls="schedule" aria-selected="false" tabindex="-1">{{ lang._('Schedule') }}</a></li>{% endif %}
    <li role="presentation"><a id="setup_tab" href="#setup" data-toggle="tab" role="tab" aria-controls="setup" aria-selected="false" tabindex="-1">{{ lang._('Advanced settings') }}</a></li>
</ul>
<div class="tab-content content-box speedtest-surface">
    <div id="measurement" class="tab-pane active" role="tabpanel" aria-labelledby="measurement_tab">
        <div class="content-box-main">
            <div class="speedtest-header">
                <div class="speedtest-heading">
                    <img src="/ui/img/speedtest-community/speedtest-logo.png" width="40" height="40" alt="" decoding="async">
                    <div>
                        <h2>{{ lang._('Connection test') }}</h2>
                        <p class="section-note">{{ lang._('Measure from this firewall to an authorized LibreSpeed server. A test may saturate your connection.') }}</p>
                    </div>
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
                    <span>{{ lang._('Ask an administrator to add a server in Advanced settings.') }}</span>
                    {% endif %}
                </div>
            </div>
            <div id="test_status" class="speedtest-status" role="status" aria-live="polite"></div>
            <button id="check_status" type="button" class="btn btn-default" aria-describedby="test_status" hidden>{{ lang._('Check test status') }}</button>
            {% if not canRun %}
            <p class="section-note">{{ lang._('You can view results, but need the LibreSpeed run privilege to start a test.') }}</p>
            {% endif %}
            <div class="speedtest-workspace">
            <form id="test_form" class="speedtest-run-form">
                <fieldset id="test_controls" disabled>
                    <div class="speedtest-field">
                        <label for="serverid">{{ lang._('Server') }}</label>
                        <div class="speedtest-server-control">
                            <select id="serverid" class="form-control">
                                <option value="0">{{ lang._('Automatic selection') }}</option>
                                <option value="-1">{{ lang._('Compare all servers') }}</option>
                                <option value="custom">{{ lang._('Choose server IDs') }}</option>
                            </select>
                            <button class="btn btn-default" id="serverlistAct" type="button" title="{{ lang._('Refresh servers and re-detect') }}" aria-label="{{ lang._('Refresh servers and re-detect') }}"><i class="fa fa-refresh" aria-hidden="true"></i></button>
                        </div>
                        <div id="automatic_server_group">
                            <strong id="detected_server" class="speedtest-detected-server" role="status" aria-live="polite">{{ lang._('Waiting to detect a server...') }}</strong>
                            <div id="detection_status" class="speedtest-status" role="status" aria-live="polite"></div>
                            <span class="help-block">{{ lang._('Latency probes only; no bandwidth test or saved result. Servers can see your public IP. Selection is rechecked when testing.') }}</span>
                        </div>
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
                    </div>
                    <div class="speedtest-connection" role="status" aria-live="polite">
                        <p><strong>{{ lang._('Server sponsor') }}:</strong> <span id="connection_sponsor">{{ lang._('Not reported') }}</span></p>
                        <p><strong>{{ lang._('Firewall IP seen by server') }}:</strong> <span id="connection_ip">{{ lang._('Not reported') }}</span></p>
                        <p><strong>{{ lang._('ISP / network') }}:</strong> <span id="connection_isp">{{ lang._('Not reported') }}</span></p>
                        <p id="connection_source" class="speedtest-secondary"></p>
                    </div>
                    {% if canRun %}
                    <div class="speedtest-actions"><button class="btn btn-primary" id="reportAct" type="submit"><i class="fa fa-play" aria-hidden="true"></i> {{ lang._('Run test') }} <i id="reportAct_progress" aria-hidden="true"></i></button></div>
                    {% endif %}
                    <a href="#setup" id="open_test_settings">{{ lang._('Advanced settings') }} <i class="fa fa-angle-right" aria-hidden="true"></i></a>
                </fieldset>
            </form>
            <section class="speedtest-readout" aria-labelledby="readout_heading">
                <div class="speedtest-readout-header">
                    <div><h3 id="readout_heading">{{ lang._('Latest result') }}</h3><p id="readout_hint" class="speedtest-secondary">{{ lang._('Run a test to see measurements here.') }}</p></div>
                </div>
                <dl class="speedtest-metrics">
                    <div class="speedtest-throughput">
                        <dt><i class="fa fa-arrow-down download-icon" aria-hidden="true"></i> {{ lang._('Download') }}</dt>
                        <dd class="speedtest-gauge">
                            <svg viewBox="0 0 220 145" aria-hidden="true" focusable="false" class="speedtest-gauge-download">
                                <path class="speedtest-gauge-track" d="M20 110 A90 90 0 0 1 200 110" fill="none" stroke-width="4"/>
                                <path id="download_arc" d="M20 110 A90 90 0 0 1 200 110" fill="none" stroke="currentColor" stroke-width="4" pathLength="100" stroke-dasharray="0 100"/>
                                <g id="download_needle" transform="rotate(-90 110 110)" opacity="0"><path d="M110 15 L105 31 L115 31 Z" fill="currentColor"/></g>
                            </svg>
                            <span id="download" class="speedtest-gauge-readout is-empty">{{ lang._('Not measured') }}</span>
                            <span class="speedtest-gauge-scale">0 / <span id="download_scale">100 Mbps</span></span>
                        </dd>
                    </div>
                    <div class="speedtest-throughput">
                        <dt><i class="fa fa-arrow-up upload-icon" aria-hidden="true"></i> {{ lang._('Upload') }}</dt>
                        <dd class="speedtest-gauge">
                            <svg viewBox="0 0 220 145" aria-hidden="true" focusable="false" class="speedtest-gauge-upload">
                                <path class="speedtest-gauge-track" d="M20 110 A90 90 0 0 1 200 110" fill="none" stroke-width="4"/>
                                <path id="upload_arc" d="M20 110 A90 90 0 0 1 200 110" fill="none" stroke="currentColor" stroke-width="4" pathLength="100" stroke-dasharray="0 100"/>
                                <g id="upload_needle" transform="rotate(-90 110 110)" opacity="0"><path d="M110 15 L105 31 L115 31 Z" fill="currentColor"/></g>
                            </svg>
                            <span id="upload" class="speedtest-gauge-readout is-empty">{{ lang._('Not measured') }}</span>
                            <span class="speedtest-gauge-scale">0 / <span id="upload_scale">100 Mbps</span></span>
                        </dd>
                    </div>
                    <div><dt>{{ lang._('Latency') }}</dt><dd id="latency" class="is-empty">{{ lang._('Not measured') }}</dd></div>
                    <div><dt>{{ lang._('Jitter') }}</dt><dd id="jitter" class="is-empty">{{ lang._('Not measured') }}</dd></div>
                </dl>
                <p class="help-block">{{ lang._('Gauge ranges scale automatically with the measured speed; they do not represent link capacity.') }}</p>
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
            <h2>{{ lang._('Advanced settings') }}</h2>
            <h3 id="measurement_settings_heading" tabindex="-1">{{ lang._('Measurement settings') }}</h3>
            <p class="section-note">{{ lang._('First installs use the recommended OPNsense/FreeBSD measurement settings below. Changes here apply to manual tests in this page. Save settings to use them as defaults for future GUI, scheduled and CLI tests.') }}</p>
            <form id="measurement_options_form">
                <fieldset id="measurement_options_controls" disabled>
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
                    <p class="help-block">{{ lang._('Longer tests, larger payloads and more concurrent requests use more data or memory. Private CA setup is described below.') }}</p>
                    <button id="reset_measurement" type="button" class="btn btn-default">{{ lang._('Restore recommended measurement settings') }}</button>
                    <p class="help-block">{{ lang._('Restores only the measurement controls on this page. Server lists, history, and schedules are unchanged. Save settings separately to make the restored values your defaults.') }}</p>
                </fieldset>
            </form>
            {% if canConfigure %}
            <h3 id="server_settings_heading" tabindex="-1">{{ lang._('Servers') }}</h3>
            <div class="checkbox"><label><input id="public_servers" type="checkbox">{{ lang._('Enable the official LibreSpeed.org catalog') }}</label></div>
            <p class="help-block">{{ lang._('The firewall fetches the catalog over HTTPS. The registry and selected servers can see its public IP. No results or telemetry are shared.') }}</p>
            <h4>{{ lang._('Official catalog') }}</h4>
            <p class="help-block">{{ lang._('All official servers are allowed initially. Remove a server to switch to a fixed allow-list; newly published servers will then require your approval. Allowed means permitted for testing, not independently security-reviewed.') }}</p>
            <div class="speedtest-toolbar">
                <div><label for="catalog_search">{{ lang._('Search by server, sponsor, host, or ID') }}</label><input id="catalog_search" class="form-control" type="search"></div>
                <button id="catalog_refresh" type="button" class="btn btn-default" disabled>{{ lang._('Refresh catalog') }}</button>
                <button id="catalog_allow_all" type="button" class="btn btn-default" disabled>{{ lang._('Allow all official servers') }}</button>
                <button id="catalog_allow_none" type="button" class="btn btn-default" disabled>{{ lang._('Remove all official servers') }}</button>
            </div>
            <p id="catalog_status" role="status" aria-live="polite"></p>
            <p id="catalog_selection_status" role="status" aria-live="polite"></p>
            <p id="catalog_no_matches" hidden>{{ lang._('No servers match your search.') }}</p>
            <div class="table-responsive" id="catalog_table" tabindex="0" role="region" aria-label="{{ lang._('Official LibreSpeed servers') }}" hidden>
                <table class="table table-striped">
                    <caption class="sr-only">{{ lang._('Official LibreSpeed servers') }}</caption>
                    <thead><tr><th scope="col">{{ lang._('Server') }}</th><th scope="col">{{ lang._('Sponsor') }}</th><th scope="col">{{ lang._('Allowed') }}</th><th scope="col">{{ lang._('Actions') }}</th></tr></thead>
                    <tbody id="catalog_rows"></tbody>
                </table>
            </div>
            <h4>{{ lang._('Custom servers') }}</h4>
            <p id="servers_help" class="help-block">{{ lang._('Add your own LibreSpeed server using the fields below; no JSON is required. Custom servers replace the public list unless you enable combining them. Catalog refresh never changes your custom entries.') }}</p>
            <div class="checkbox"><label><input id="combine_servers" type="checkbox" disabled>{{ lang._('Include allowed official servers alongside custom servers') }}</label></div>
            <p class="help-block">{{ lang._('If no custom entries are saved, the firewall-managed server file is used before the public list. Combining also applies to that file. Keep IDs and URLs unique across both sources.') }} <code>/usr/local/etc/speedtest-community/librespeed-servers.json</code></p>
            <fieldset id="custom_server_controls" disabled>
                <div class="table-responsive" id="custom_server_table" tabindex="0" role="region" aria-label="{{ lang._('Custom LibreSpeed servers') }}" hidden>
                    <table class="table table-striped">
                        <caption class="sr-only">{{ lang._('Custom LibreSpeed servers') }}</caption>
                        <thead><tr><th scope="col">{{ lang._('Server') }}</th><th scope="col">{{ lang._('Actions') }}</th></tr></thead>
                        <tbody id="custom_server_rows"></tbody>
                    </table>
                </div>
                <p id="custom_server_status" role="status" aria-live="polite"></p>
                <button id="add_custom_server" type="button" class="btn btn-default">{{ lang._('Add custom server') }}</button>
                <form id="custom_server_editor" class="form-horizontal" hidden>
                    <h5 id="custom_server_editor_title"></h5>
                    <div class="form-group"><label for="server_edit_name" class="col-sm-3 control-label">{{ lang._('Name') }}</label><div class="col-sm-9"><input id="server_edit_name" class="form-control" maxlength="200" required></div></div>
                    <div class="form-group"><label for="server_edit_server" class="col-sm-3 control-label">{{ lang._('HTTPS base URL') }}</label><div class="col-sm-9"><input id="server_edit_server" type="url" class="form-control" placeholder="https://speed.example.net/backend/" required><span class="help-block">{{ lang._('Use the LibreSpeed backend URL, not a results page. Standard PHP endpoint paths are filled in for you.') }}</span></div></div>
                    <details id="server_endpoint_options" class="speedtest-disclosure">
                        <summary><i class="fa fa-angle-right" aria-hidden="true"></i>{{ lang._('Advanced endpoint options') }}</summary>
                        <div>
                            <div class="form-group"><label for="server_edit_id" class="col-sm-3 control-label">{{ lang._('Server ID') }}</label><div class="col-sm-9"><input id="server_edit_id" class="form-control" inputmode="numeric" pattern="[1-9][0-9]{0,15}" required><span class="help-block">{{ lang._('Assigned automatically for new entries. Keep existing IDs stable for schedules and history.') }}</span></div></div>
                            <div class="form-group"><label for="server_edit_sponsorName" class="col-sm-3 control-label">{{ lang._('Sponsor (optional)') }}</label><div class="col-sm-9"><input id="server_edit_sponsorName" class="form-control" maxlength="200"></div></div>
                            <div class="form-group"><label for="server_edit_dlURL" class="col-sm-3 control-label">{{ lang._('Download path') }}</label><div class="col-sm-9"><input id="server_edit_dlURL" class="form-control" required></div></div>
                            <div class="form-group"><label for="server_edit_ulURL" class="col-sm-3 control-label">{{ lang._('Upload path') }}</label><div class="col-sm-9"><input id="server_edit_ulURL" class="form-control" required></div></div>
                            <div class="form-group"><label for="server_edit_pingURL" class="col-sm-3 control-label">{{ lang._('Latency path') }}</label><div class="col-sm-9"><input id="server_edit_pingURL" class="form-control" required></div></div>
                            <div class="form-group"><label for="server_edit_getIpURL" class="col-sm-3 control-label">{{ lang._('Client IP path') }}</label><div class="col-sm-9"><input id="server_edit_getIpURL" class="form-control" required></div></div>
                        </div>
                    </details>
                    <div class="speedtest-toolbar">
                        <button type="submit" class="btn btn-default">{{ lang._('Apply to custom list') }}</button>
                        <button id="cancel_server_edit" type="button" class="btn btn-default">{{ lang._('Cancel edit') }}</button>
                    </div>
                    <p id="server_edit_status" role="status" aria-live="polite"></p>
                </form>
                <details class="speedtest-disclosure">
                    <summary><i class="fa fa-angle-right" aria-hidden="true"></i>{{ lang._('Edit raw server JSON') }}</summary>
                    <div><label for="servers_json">{{ lang._('Custom servers (JSON)') }}</label>
                    <textarea id="servers_json" class="form-control" rows="7" spellcheck="false" aria-describedby="servers_help"></textarea></div>
                </details>
            </fieldset>
            <h3>{{ lang._('History retention') }}</h3>
            <form id="retention_form" class="speedtest-toolbar">
                <div><label for="retention_days">{{ lang._('Keep history for days') }}</label><input id="retention_days" class="form-control" type="number" min="0" max="3650" value="31" required></div>
                <div><label for="history_limit">{{ lang._('Maximum history records') }}</label><input id="history_limit" class="form-control" type="number" min="0" max="100000" value="10000" required></div>
                <button id="reset_retention" type="button" class="btn btn-default" disabled>{{ lang._('Use recommended retention') }}</button>
            </form>
            <p class="help-block">{{ lang._('Recommended: 31 days and at most 10,000 records, whichever limit is reached first. Pruning runs after successful and failed tests and applies to detailed history and legacy CSV. 0 disables that limit; setting both to 0 keeps all history. Export before reducing retention.') }}</p>
            <p>{{ lang._('Saving applies these settings to future GUI, cron and terminal tests. No restart is needed.') }}</p>
            <button id="save_settings" type="button" class="btn btn-primary" disabled>{{ lang._('Save settings') }}</button>
            <div id="settings_status" class="speedtest-status" role="status" aria-live="polite"></div>
            {% else %}
            <p>{{ lang._('You need the LibreSpeed configure privilege to save defaults or change server and retention settings.') }}</p>
            {% endif %}
            <details class="speedtest-disclosure">
                <summary><i class="fa fa-angle-right" aria-hidden="true"></i>{{ lang._('Connection security and privacy') }}</summary>
                <div>
                    <p>{{ lang._('Test endpoints must use HTTPS with verified certificates. This is independent of whether the OPNsense GUI uses HTTP or HTTPS.') }}</p>
                    <p>{{ lang._('For private endpoints, install a PEM CA bundle at /usr/local/etc/speedtest-community/ca.pem and enable the private CA option. It replaces the engine trust store for that run. Use separate issuing CA and server certificates.') }}</p>
                    <p>{{ lang._('When enabled, the official catalog is retrieved over HTTPS for the server manager, for tests without a local list, or when combining sources. Only allowed official IDs are used for tests. The registry and selected servers can see the firewall public IP. No result sharing or telemetry is requested.') }}</p>
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
                        <li><a href="https://github.com/blackoutsecure/opn-repo/issues" target="_blank" rel="noopener noreferrer">{{ lang._('Issues, feedback and provider requests') }}</a></li>
                        <li><a href="https://github.com/librespeed/speedtest-cli-rust" target="_blank" rel="noopener noreferrer">{{ lang._('LibreSpeed Rust client') }}</a></li>
                        <li><a href="https://github.com/librespeed/speedtest" target="_blank" rel="noopener noreferrer">{{ lang._('LibreSpeed server setup') }}</a></li>
                        <li><a href="https://github.com/librespeed/speedtest-rust" target="_blank" rel="noopener noreferrer">{{ lang._('Optional Rust server backend') }}</a></li>
                    </ul>
                </div>
            </details>
        </div>
    </div>
    <footer class="content-box-main speedtest-support">
        <img src="/ui/img/speedtest-community/speedtest-logo.png" width="48" height="48" alt="" loading="lazy" decoding="async">
        <div>
            <p><a href="https://blackoutsecure.app/" target="_blank" rel="noopener noreferrer">{{ lang._('Maintained and supported by BlackOut Secure') }}</a></p>
            <p><a href="https://github.com/blackoutsecure/opn-repo/issues" target="_blank" rel="noopener noreferrer">{{ lang._('Issues, feedback and provider requests') }}</a>
                &middot; <a href="https://librespeed.org/" target="_blank" rel="noopener noreferrer">{{ lang._('Powered by LibreSpeed') }}</a></p>
        </div>
    </footer>
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
    let catalogLoading = false;
    let setupVisible = false;
    let catalog = [];
    let catalogReceived = false;
    let publicSelection = 'all';
    let serverEditIndex = null;
    let savedPublicServers = false;
    let statusReady = false;
    let statusNeedsAttention = false;
    let statusRetrying = false;
    let lastStatusKey = null;
    let detecting = false;
    let detectionChecked = false;
    let detectionGeneration = 0;
    let detectionTimer = null;
    let settingsReady = false;
    let scheduleReady = false;
    let saving = false;
    let historyPage = 1;
    let historyGeneration = 0;
    let savedRetention = {};
    let pollGeneration = 0;
    let pollTimer = null;
    let charts = [];
    let liveChart = null;
    const gaugeRanges = {download: 0, upload: 0};
    const canRun = {% if canRun %}true{% else %}false{% endif %};
    const canConfigure = {% if canConfigure %}true{% else %}false{% endif %};
    const canSchedule = {% if canSchedule %}true{% else %}false{% endif %};
    const optionKeys = ['duration', 'timeout', 'concurrent', 'chunks', 'upload_size', 'family', 'source', 'exclude'];
    const booleanKeys = ['icmp', 'http2', 'no_pre_allocate', 'private_ca'];
    const recommendedRetention = {retention_days: '31', history_limit: '10000'};
    const serverFields = ['id', 'name', 'server', 'dlURL', 'ulURL', 'pingURL', 'getIpURL', 'sponsorName'];
    const recommendedOptions = {
        duration: '10', timeout: '15', concurrent: '3', chunks: '100', upload_size: '1024',
        family: 'auto', source: '', exclude: '', icmp: '0', http2: '0',
        no_pre_allocate: '0', private_ca: '0'
    };
    const metricNames = {download: "{{ lang._('Download') }}", upload: "{{ lang._('Upload') }}",
        latency: "{{ lang._('Latency') }}", jitter: "{{ lang._('Jitter') }}"};
    const modeNames = {both: "{{ lang._('Full test') }}", download: "{{ lang._('Download') }}",
        upload: "{{ lang._('Upload') }}", latency: "{{ lang._('Latency') }}"};
    const originNames = {manual: "{{ lang._('GUI') }}", scheduled: "{{ lang._('Scheduled') }}",
        cli: "{{ lang._('CLI / legacy cron') }}", legacy: "{{ lang._('Legacy') }}"};
    function updateControls() {
        const busy = running || starting || saving || detecting;
        $('#test_controls').prop('disabled', busy || !defaultsReady || (!canRun && !canConfigure));
        $('#measurement_options_controls').prop('disabled', busy || !defaultsReady || (!canRun && !canConfigure));
        $('#reportAct').prop('disabled', busy || !engineReady || !serversReady || !defaultsReady || !statusReady || !canRun);
        $('#serverlistAct').prop('disabled', busy || serversLoading);
        $('#save_settings').prop('disabled', busy || !defaultsReady || !settingsReady || serverEditIndex !== null);
        $('#public_servers').prop('disabled', busy || !settingsReady);
        $('#reset_retention').prop('disabled', busy || !defaultsReady || !settingsReady || !canConfigure);
        $('#combine_servers').prop('disabled', busy || !settingsReady);
        $('#custom_server_controls').prop('disabled', busy || !settingsReady);
        $('#servers_json').prop('disabled', serverEditIndex !== null);
        $('#catalog_refresh').prop('disabled', busy || !settingsReady || !defaultsReady || catalogLoading
            || !savedPublicServers || !$('#public_servers').prop('checked'));
        $('#catalog_rows button').prop('disabled', busy || !settingsReady || serverEditIndex !== null);
        $('#catalog_allow_all, #catalog_allow_none').prop('disabled', busy || !settingsReady || !defaultsReady
            || catalogLoading || !savedPublicServers || !$('#public_servers').prop('checked'));
        $('#schedule_controls').prop('disabled', busy || !scheduleReady);
        $('#deletelogAct').prop('disabled', busy);
        $('#check_status').prop('disabled', starting || detecting || statusRetrying);
        $('#custom_servers').prop('disabled', $('#serverid').val() !== 'custom');
        $('#custom_server_group').prop('hidden', $('#serverid').val() !== 'custom');
        $('#automatic_server_group').prop('hidden', $('#serverid').val() !== '0');
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
                if (status) showStatus(status, reason === 'timeout'
                    ? "{{ lang._('The request timed out. Check your session and backend logs.') }}"
                    : "{{ lang._('The service could not be reached. Check your session and backend logs.') }}", true);
            });
    }
    function customServers() {
        try {
            const text = $('#servers_json').val().trim();
            const list = text ? JSON.parse(text) : [];
            return Array.isArray(list) && list.every(server => server && Number.isSafeInteger(server.id)) ? list : null;
        } catch (error) {
            if (!(error instanceof SyntaxError)) throw error;
            return null;
        }
    }
    function serverNameCell(server) {
        return $('<td/>').append($('<strong/>').text('(' + server.id + ') ' + server.name))
            .append($('<div/>').text(String(server.server ?? '')));
    }
    function rowButton(label, name, handler) {
        return $('<button/>').attr('type', 'button').attr('aria-label', label + ': ' + name)
            .addClass('btn btn-default btn-xs').text(label).on('click', handler);
    }
    function approvedPublicIds() {
        return publicSelection === 'all' ? catalog.map(server => server.id)
            : publicSelection === 'none' ? [] : publicSelection.split(',');
    }
    function setPublicSelection(selection) {
        if (!canConfigure || !settingsReady || running || saving || detecting || serverEditIndex !== null) return;
        publicSelection = selection;
        renderCatalog();
        showStatus('#settings_status', "{{ lang._('Server permissions changed on this page. Save settings to apply them to tests.') }}");
    }
    function togglePublicServer(server) {
        const ids = new Set(approvedPublicIds());
        if (ids.has(server.id)) ids.delete(server.id);
        else ids.add(server.id);
        if (ids.size > 50) {
            showStatus('#catalog_selection_status', "{{ lang._('Select up to 50 official servers.') }}", true);
            return;
        }
        setPublicSelection(ids.size ? [...ids].join(',') : 'none');
    }
    function nextCustomServerId() {
        const ids = new Set([...(customServers() || []).map(server => String(server.id)), ...catalog.map(server => server.id)]);
        let id = 10000;
        while (ids.has(String(id))) id++;
        return id;
    }
    function renderCustomServers() {
        const list = customServers();
        const rows = $('#custom_server_rows').empty();
        $('#custom_server_table').prop('hidden', !list?.length);
        $('#add_custom_server, #custom_server_rows button').prop('disabled', !list || serverEditIndex !== null);
        if (!list) {
            showStatus('#custom_server_status', "{{ lang._('Use raw JSON to correct this list or edit IDs larger than the form supports.') }}", true);
            return;
        }
        showStatus('#custom_server_status', list.length ? '' : "{{ lang._('No custom servers. Tests use the configured fallback source.') }}");
        list.forEach((server, index) => {
            const buttons = $('<td/>')
                .append(rowButton("{{ lang._('Edit') }}", server.name, () => editServer(server, index)))
                .append(' ')
                .append(rowButton("{{ lang._('Remove') }}", server.name, () => {
                    if (running || saving || detecting || serverEditIndex !== null) return;
                    if (list.length === 1 && !window.confirm("{{ lang._('Removing the last custom server restores the configured fallback source after saving. Remove it?') }}")) return;
                    list.splice(index, 1);
                    writeCustomServers(list);
                    $('#add_custom_server').trigger('focus');
                }));
            rows.append($('<tr/>').append(serverNameCell(server)).append(buttons));
        });
        $('#custom_server_rows button').prop('disabled', serverEditIndex !== null);
    }
    function writeCustomServers(list) {
        $('#servers_json').val(list.length ? JSON.stringify(list, null, 2) : '');
        renderCustomServers();
        showStatus('#custom_server_status', "{{ lang._('Custom list updated on this page. Save settings to use it for tests.') }}");
    }
    function editServer(server, index) {
        if (running || saving || detecting || !settingsReady || serverEditIndex !== null || !customServers()) return;
        serverEditIndex = index;
        $('#custom_server_editor_title').text(index === -1
            ? "{{ lang._('Add to custom servers') }}" : "{{ lang._('Edit custom server') }}");
        serverFields.forEach(key => $('#server_edit_' + key).val(String(server[key] ?? '')));
        $('#server_endpoint_options').prop('open', false);
        showStatus('#server_edit_status', '');
        $('#custom_server_editor').prop('hidden', false);
        renderCustomServers();
        updateControls();
        $('#server_edit_name').trigger('focus');
    }
    function closeServerEditor() {
        serverEditIndex = null;
        $('#custom_server_editor').prop('hidden', true);
        renderCustomServers();
        updateControls();
        $('#add_custom_server').trigger('focus');
    }
    function renderCatalog() {
        const enabled = savedPublicServers && $('#public_servers').prop('checked');
        const query = $('#catalog_search').val().trim().toLowerCase();
        const ids = approvedPublicIds();
        const unavailable = publicSelection === 'all' || !catalogReceived ? [] : ids.filter(id => !catalog.some(server => server.id === id))
            .map(id => ({id, name: "{{ lang._('Not in the current catalog') }}", server: '', sponsorName: ''}));
        const matches = enabled ? [...catalog, ...unavailable].filter(server =>
            [server.id, server.name, server.server, server.sponsorName].some(value => value.toLowerCase().includes(query))) : [];
        const rows = $('#catalog_rows').empty();
        matches.forEach(server => {
            const allowed = publicSelection === 'all' || ids.includes(server.id);
            rows.append($('<tr/>').append(serverNameCell(server)).append($('<td/>').text(server.sponsorName))
                .append($('<td/>').text(allowed ? "{{ lang._('Yes') }}" : "{{ lang._('No') }}"))
                .append($('<td/>').append(rowButton(allowed ? "{{ lang._('Remove') }}" : "{{ lang._('Allow') }}",
                    server.name, () => {
                        togglePublicServer(server);
                        $('#catalog_allow_' + server.id).trigger('focus');
                    }).attr('id', 'catalog_allow_' + server.id))));
        });
        $('#catalog_table').prop('hidden', !matches.length);
        $('#catalog_no_matches').prop('hidden', !enabled || !catalog.length || !!matches.length);
        $('#catalog_search').prop('disabled', !enabled);
        showStatus('#catalog_selection_status', publicSelection === 'all'
            ? "{{ lang._('All official servers, including future additions, are allowed.') }}"
            : publicSelection === 'none' ? "{{ lang._('No official servers are allowed. Add a custom server or allow an official server before testing.') }}"
            : "{{ lang._('Only your selected official IDs are allowed; new catalog entries are not automatically allowed.') }}");
        updateControls();
    }
    function refreshCatalog() {
        if (!canConfigure || !settingsReady || !defaultsReady || catalogLoading) return;
        if (!savedPublicServers || !$('#public_servers').prop('checked')) {
            showStatus('#catalog_status', "{{ lang._('Enable the official catalog and save settings to retrieve it.') }}");
            renderCatalog();
            return;
        }
        catalogLoading = true;
        showStatus('#catalog_status', "{{ lang._('Loading the official catalog...') }}");
        updateControls();
        request('/api/speedtest/settings/catalog', {}, function(data) {
            if (!$('#public_servers').prop('checked')) return;
            if (!Array.isArray(data?.servers) || data.servers.some(server => !server
                || serverFields.some(key => typeof server[key] !== 'string'))) {
                showStatus('#catalog_status', readableError(data?.error) || "{{ lang._('Unable to refresh the official catalog.') }}", true);
                return;
            }
            catalog = data.servers;
            catalogReceived = true;
            renderCatalog();
            showStatus('#catalog_status', "{{ lang._('Official catalog refreshed.') }}");
        }, '#catalog_status').always(function() {
            catalogLoading = false;
            updateControls();
        });
    }
    function serversReload() {
        if (serversLoading) return;
        serversLoading = true;
        serversReady = false;
        $('#detected_server').text("{{ lang._('Server not detected') }}");
        showStatus('#detection_status', '');
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
            detectServer();
        });
    }
    function finishDetection(message, error = false) {
        detecting = false;
        if (error) {
            $('#detected_server').text("{{ lang._('Server not detected') }}");
            renderConnection(null);
        }
        showStatus('#detection_status', message, error);
        updateControls();
    }
    function followDetection(expected, queued, generation) {
        request('detectionstatus', {}, function(state) {
            if (generation !== detectionGeneration) return;
            if (!['idle', 'running', 'busy', 'completed', 'failed'].includes(state?.status)) {
                finishDetection(readableError(state?.error) || "{{ lang._('Unable to read server detection status. Refresh servers to retry.') }}", true);
                return;
            }
            if (state.run_id !== expected || state.status === 'idle' || state.status === 'busy') {
                if (Date.now() - queued < 15000) {
                    detectionTimer = setTimeout(() => followDetection(expected, queued, generation), 1500);
                } else {
                    finishDetection("{{ lang._('Server detection did not start or another operation is active. Refresh servers to retry.') }}", true);
                }
                return;
            }
            if (state.status === 'running') {
                if (!Number.isFinite(state.deadline) || Date.now() / 1000 > state.deadline + 30) {
                    finishDetection("{{ lang._('Server detection exceeded its expected deadline. Check backend logs and refresh servers.') }}", true);
                    return;
                }
                detectionTimer = setTimeout(() => followDetection(expected, queued, generation), 1500);
                return;
            }
            const result = state.results?.[0];
            if (state.status !== 'completed' || !result || result.error
                || !/^[1-9][0-9]*$/.test(String(result.serverid))
                || typeof result.servername !== 'string' || !result.servername.trim()
                || !Number.isFinite(result.latency) || result.latency < 0) {
                finishDetection(readableError(state.error || result?.error)
                    || "{{ lang._('No reachable server was detected. Check Advanced settings and refresh servers.') }}", true);
                return;
            }
            $('#detected_server').text('(' + result.serverid + ') ' + result.servername);
            renderConnection(result);
            const jitter = Number.isFinite(result.jitter) && result.jitter >= 0
                ? ' · ' + "{{ lang._('Jitter') }}: " + number(result.jitter, ' ms') : '';
            finishDetection("{{ lang._('Detected latency') }}: " + number(result.latency, ' ms') + jitter);
        }, '#detection_status').fail(function() {
            if (generation !== detectionGeneration) return;
            finishDetection("{{ lang._('Detection connection lost. The scan may still be running. Refresh servers to retry.') }}", true);
        });
    }
    function detectServer() {
        if (!$('#measurement').hasClass('active') || detectionChecked || detecting || running || starting || saving || !statusReady || !defaultsReady
            || !engineReady || !serversReady || $('#serverid').val() !== '0') return;
        if (!canRun) {
            detectionChecked = true;
            $('#detected_server').text("{{ lang._('Automatic server selection') }}");
            showStatus('#detection_status', "{{ lang._('The LibreSpeed run privilege is required to detect a server.') }}");
            return;
        }
        if (!$('#measurement_options_form')[0].reportValidity()) return;
        detectionChecked = true;
        detecting = true;
        const generation = ++detectionGeneration;
        $('#detected_server').text("{{ lang._('Detecting the lowest-latency server...') }}");
        renderConnection(null);
        showStatus('#detection_status', "{{ lang._('Probing configured servers. Download and upload are not running.') }}");
        updateControls();
        request('detect', currentOptions(), function(data) {
            if (generation !== detectionGeneration) return;
            if (data?.result !== 'started' || !/^[a-f0-9]{32}$/.test(data.run_id || '')) {
                finishDetection(readableError(data?.error) || "{{ lang._('Unable to start server detection. Refresh servers to retry.') }}", true);
                return;
            }
            followDetection(data.run_id, Date.now(), generation);
        }, '#detection_status').fail(function() {
            if (generation === detectionGeneration) {
                finishDetection("{{ lang._('Detection response lost. The scan may still be running. Refresh servers to retry.') }}", true);
            }
        });
    }
    function number(value, suffix = '') {
        return value === undefined || value === null ? "{{ lang._('Not measured') }}"
            : Number(value).toLocaleString(undefined, {maximumFractionDigits: 2}) + suffix;
    }
    function speedScale(mbps) {
        if (mbps >= 1000000) return {unit: 'Tbps', divisor: 1000000};
        if (mbps >= 1000) return {unit: 'Gbps', divisor: 1000};
        if (mbps >= 1 || mbps === 0) return {unit: 'Mbps', divisor: 1};
        if (mbps >= 0.001) return {unit: 'kbps', divisor: 0.001};
        return {unit: 'bps', divisor: 0.000001};
    }
    function speed(value) {
        if (value == null) return number(null);
        const {unit, divisor} = speedScale(value);
        return number(value / divisor, ' ' + unit);
    }
    function metricValue(key, value) {
        return ['download', 'upload'].includes(key) ? speed(value) : number(value, ' ms');
    }
    function renderConnection(result) {
        const notReported = "{{ lang._('Not reported') }}";
        const value = text => typeof text === 'string' && text.trim() ? text : notReported;
        $('#connection_sponsor').text(value(result?.sponsor));
        $('#connection_ip').text(value(result?.connection?.ip));
        $('#connection_isp').text(value(result?.connection?.isp));
        $('#connection_source').text(result?.servername
            ? "{{ lang._('Details for') }} " + result.servername + "{{ lang._('; IP and ISP describe this firewall, not the browser.') }}"
            : "{{ lang._('Details appear after server detection or a test.') }}");
    }
    function renderGauge(key, value, live = false) {
        const measured = Number.isFinite(value) && value >= 0;
        const base = measured && value > 0 ? Math.pow(10, Math.floor(Math.log10(value))) : 100;
        const range = measured && value > 0 ? [1, 2, 5, 10].find(step => step * base >= value) * base : base;
        const maximum = live && measured ? Math.max(gaugeRanges[key], range) : range;
        gaugeRanges[key] = measured ? maximum : 0;
        const percent = measured ? Math.min(100, value / maximum * 100) : 0;
        $('#' + key + '_arc').attr('stroke-dasharray', percent + ' 100');
        $('#' + key + '_needle').attr('transform', 'rotate(' + (percent * 1.8 - 90) + ' 110 110)')
            .attr('opacity', measured ? '1' : '0');
        $('#' + key + '_scale').text(speed(maximum));
    }
    function renderResults(results) {
        const result = results.find(item => !item.error);
        renderConnection(result);
        Object.keys(metricNames).forEach(key => {
            const value = result?.[key];
            $('#' + key).text(metricValue(key, value)).toggleClass('is-empty', value === undefined || value === null);
            if (['download', 'upload'].includes(key)) renderGauge(key, value);
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
                renderGauge(key, point?.mbps, true);
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
        const {unit, divisor} = speedScale(Math.max(0, ...samples.download.map(item => item.mbps),
            ...samples.upload.map(item => item.mbps)));
        const color = getComputedStyle(document.body).color;
        const datasets = ['download', 'upload'].map((key, index) => ({
            label: metricNames[key],
            data: samples[key].map(item => ({x: item.seconds, y: item.mbps / divisor})),
            borderColor: index ? '#00818b' : '#b52da5', backgroundColor: index ? '#00818b' : '#b52da5',
            borderWidth: 2, pointRadius: 2, spanGaps: false
        }));
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
                        y: {beginAtZero: true, ticks: {color: color}, title: {display: true, color: color, text: unit}}
                    }
                }
            });
        } else {
            liveChart.data.datasets = datasets;
            liveChart.options.scales.y.title.text = unit;
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
            const {unit, divisor} = id === 'throughput_chart'
                ? speedScale(Math.max(0, ...data.series.map(point => Math.max(point.download ?? 0, point.upload ?? 0))))
                : {unit: 'ms', divisor: 1};
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
                        y: {beginAtZero: true, ticks: {color: color}, title: {display: true, color: color, text: unit}}
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
    function statusProblem(message) {
        statusReady = false;
        statusNeedsAttention = true;
        statusRetrying = false;
        $('#check_status').prop('hidden', false);
        showStatus('#test_status', message, true);
        updateControls();
    }
    function scheduleStatusCheck(generation) {
        pollTimer = setTimeout(function() {
            if (generation !== pollGeneration) return;
            if (detecting || saving || starting || document.hidden) {
                scheduleStatusCheck(generation);
            } else {
                followStatus(null, Date.now(), generation);
            }
        }, 30000);
    }
    function followStatus(expected = null, queued = Date.now(), generation = ++pollGeneration, failures = 0) {
        clearTimeout(pollTimer);
        request('status', {}, function(state) {
            if (generation !== pollGeneration) return;
            if (detecting && !expected) {
                scheduleStatusCheck(generation);
                return;
            }
            if (!['idle', 'running', 'busy', 'completed', 'failed'].includes(state?.status)) {
                statusProblem(readableError(state?.error) || "{{ lang._('Unable to check test status.') }}");
                return;
            }
            if (statusNeedsAttention || failures) showStatus('#test_status', '');
            statusNeedsAttention = false;
            statusRetrying = false;
            $('#check_status').prop('hidden', true);
            statusReady = true;
            if (state.status === 'busy') {
                otherOperation = true;
                if (!running) renderResults([]);
                running = true;
                updateControls();
                $('#run_progress').prop('hidden', true);
                renderLive(null);
                $('#readout_hint').text("{{ lang._('Live progress is unavailable for this operation.') }}");
                showStatus('#test_status', "{{ lang._('Another test, server scan or history operation is in progress. Wait for it to finish.') }}");
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
                    statusProblem("{{ lang._('The queued test did not start. Check backend logs and test status before retrying.') }}");
                }
                return;
            }
            const finishedOtherOperation = otherOperation && !expected;
            otherOperation = false;
            const wasRunning = running;
            const statusKey = JSON.stringify([state.status, state.run_id ?? null, state.updated ?? null]);
            const changed = statusKey !== lastStatusKey;
            lastStatusKey = statusKey;
            if (state.status === 'running' && !wasRunning) renderResults([]);
            running = state.status === 'running';
            updateControls();
            if (!running && !wasRunning && !finishedOtherOperation && !changed) {
                scheduleStatusCheck(generation);
                return;
            }
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
                    statusProblem("{{ lang._('The test exceeded its expected deadline. Check backend logs; a lock may still be held.') }}");
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
            } else {
                renderResults([]);
                showStatus('#test_status', wasRunning ? "{{ lang._('No test is currently running.') }}" : '');
            }
            detectServer();
            if (!running) scheduleStatusCheck(generation);
        }, null).fail(function() {
            if (generation !== pollGeneration) return;
            if (detecting && !expected) {
                scheduleStatusCheck(generation);
                return;
            }
            statusReady = false;
            updateControls();
            if (failures < 2) {
                showStatus('#test_status', "{{ lang._('Unable to check test status. Retrying...') }}", true);
                pollTimer = setTimeout(() => followStatus(expected, queued, generation, failures + 1), 3000);
            } else {
                statusProblem("{{ lang._('Unable to check test status. The test may still be running; check your session and backend logs.') }}");
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
                $('#server_settings_heading').trigger('focus');
            });
        }
        $('#open_test_settings').on('click', function(event) {
            event.preventDefault();
            $('#setup_tab').tab('show');
            $('#measurement_settings_heading').trigger('focus');
        });
        $('#measurement_options_form')[0].addEventListener('invalid', function() {
            $('#setup_tab').tab('show');
        }, true);
        $('#measurement_options_form').on('submit', event => event.preventDefault());
        $('#measurement_options_form').on('change', function() {
            detectionChecked = false;
            $('#detected_server').text("{{ lang._('Settings changed. Return to Run test to re-detect.') }}");
            showStatus('#detection_status', '');
        });
        $('#reset_measurement').on('click', function() {
            if (running || saving || detecting || !defaultsReady || (!canRun && !canConfigure)) return;
            optionKeys.forEach(key => $('#' + key).val(recommendedOptions[key]));
            booleanKeys.forEach(key => $('#' + key).prop('checked', recommendedOptions[key] === '1'));
            $('#measurement_options_form').trigger('change');
            showStatus('#settings_status', "{{ lang._('Recommended measurement settings restored on this page. Save settings to use them for future tests.') }}");
        });
        request('defaults', {}, function(data) {
            if (!data || data.error) {
                showStatus('#test_status', readableError(data?.error) || "{{ lang._('Unable to load saved defaults') }}", true);
                return;
            }
            optionKeys.forEach(key => { if (data[key] !== undefined) $('#' + key).val(data[key]); });
            booleanKeys.forEach(key => $('#' + key).prop('checked', data[key] === '1'));
            ['retention_days', 'history_limit'].forEach(key => {
                const value = data[key] ?? recommendedRetention[key];
                $('#' + key).val(value);
                savedRetention[key] = Number(value);
            });
            savedPublicServers = data.public_servers === '1';
            $('#public_servers').prop('checked', savedPublicServers);
            defaultsReady = true;
            updateControls();
            if (setupVisible) refreshCatalog();
            followStatus();
            $('#check_status').on('click', function() {
                if (starting || detecting || statusRetrying) return;
                statusRetrying = true;
                showStatus('#test_status', "{{ lang._('Checking test status...') }}");
                updateControls();
                followStatus();
            });
            $('#serverid').on('change', function() { updateControls(); detectServer(); });
            $(window).on('pagehide', function() {
                ++pollGeneration;
                ++detectionGeneration;
                clearTimeout(pollTimer);
                clearTimeout(detectionTimer);
            });
            $(window).on('pageshow', function(event) {
                if (!event.originalEvent?.persisted) return;
                if (detecting) {
                    detecting = false;
                    detectionChecked = false;
                    $('#detected_server').text("{{ lang._('Waiting to detect a server...') }}");
                    showStatus('#detection_status', '');
                }
                statusReady = false;
                statusRetrying = statusNeedsAttention;
                updateControls();
                followStatus();
            });
            $(document).on('visibilitychange', function() {
                if (!document.hidden && statusReady && !running && !starting && !detecting && !saving && !statusNeedsAttention) followStatus();
            });
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
            $('#retention_form').on('submit', event => event.preventDefault());
            $('#reset_retention').on('click', function() {
                if (running || saving || detecting || !settingsReady || !defaultsReady) return;
                Object.entries(recommendedRetention).forEach(([key, value]) => $('#' + key).val(value));
                showStatus('#settings_status', "{{ lang._('Recommended retention restored on this page. Save settings to apply it; export history before shortening limits.') }}");
            });
            $('#setup_tab').on('shown.bs.tab', function() {
                setupVisible = true;
                refreshCatalog();
            }).on('hidden.bs.tab', function() { setupVisible = false; });
            $('#catalog_refresh').on('click', refreshCatalog);
            $('#catalog_allow_all').on('click', () => setPublicSelection('all'));
            $('#catalog_allow_none').on('click', () => setPublicSelection('none'));
            $('#public_servers').on('change', function() {
                renderCatalog();
                refreshCatalog();
            });
            $('#catalog_search').on('input', renderCatalog);
            $('#servers_json').on('input', renderCustomServers);
            $('#add_custom_server').on('click', () => editServer({
                id: nextCustomServerId(),
                dlURL: 'garbage.php', ulURL: 'empty.php', pingURL: 'empty.php', getIpURL: 'getIP.php'
            }, -1));
            $('#cancel_server_edit').on('click', closeServerEditor);
            $('#custom_server_editor')[0].addEventListener('invalid', function() {
                $('#server_endpoint_options').prop('open', true);
            }, true);
            $('#custom_server_editor').on('submit', function(event) {
                event.preventDefault();
                if (serverEditIndex === null || running || saving || detecting || !this.reportValidity()) return;
                const list = customServers();
                if (!list) return;
                const server = serverEditIndex === -1 ? {} : {...list[serverEditIndex]};
                serverFields.forEach(key => server[key] = $('#server_edit_' + key).val().trim());
                server.id = Number(server.id);
                let url;
                try { url = new URL(server.server); }
                catch (error) {
                    if (!(error instanceof TypeError)) throw error;
                    showStatus('#server_edit_status', "{{ lang._('Enter a valid HTTPS backend URL.') }}", true);
                    return;
                }
                if (!Number.isSafeInteger(server.id) || server.id < 1 || !server.name || /[\u0000-\u001f\u007f]/.test(server.name)
                    || url.protocol !== 'https:' || !/^https:\/\/[^/]/.test(server.server) || url.username || url.password
                    || url.search || url.hash || /[\s\\]/.test(server.server)
                    || list.some((entry, index) => index !== serverEditIndex && (entry.id === server.id
                        || String(entry.server).replace(/\/+$/, '') === server.server.replace(/\/+$/, '')))) {
                    $('#server_endpoint_options').prop('open', true);
                    showStatus('#server_edit_status', "{{ lang._('Use a unique positive ID, a name, and a unique HTTPS URL without credentials, queries or fragments.') }}", true);
                    return;
                }
                if (['dlURL', 'ulURL', 'pingURL', 'getIpURL'].some(key =>
                    !/^[A-Za-z0-9_.-]+(?:\/[A-Za-z0-9_.-]+)*$/.test(server[key])
                    || server[key].split('/').some(part => part === '.' || part === '..'))) {
                    showStatus('#server_edit_status', "{{ lang._('Endpoint paths must be relative and cannot contain dot or parent segments.') }}", true);
                    return;
                }
                if (serverEditIndex === -1 && list.length >= 50) {
                    showStatus('#server_edit_status', "{{ lang._('Remove a custom server before adding another. The list supports up to 50.') }}", true);
                    return;
                }
                if (!server.sponsorName) delete server.sponsorName;
                list[serverEditIndex === -1 ? list.length : serverEditIndex] = server;
                closeServerEditor();
                writeCustomServers(list);
            });
            $.ajax({url: '/api/speedtest/settings/get', dataType: 'json', timeout: 30000}).done(function(data) {
                if (typeof data?.speedtest?.general?.servers !== 'string') {
                    showStatus('#settings_status', "{{ lang._('Unable to load server settings') }}", true);
                    return;
                }
                $('#servers_json').val(data.speedtest.general.servers);
                publicSelection = data.speedtest.general.public_selection || 'all';
                $('#combine_servers').prop('checked', data.speedtest.general.combine_servers === '1');
                settingsReady = true;
                renderCustomServers();
                renderCatalog();
                updateControls();
                if (setupVisible) refreshCatalog();
            }).fail(() => showStatus('#settings_status', "{{ lang._('Unable to load server settings') }}", true));
        }
        $('#save_settings').on('click', function() {
            if (running || saving || detecting || !settingsReady || !defaultsReady || !canConfigure || serverEditIndex !== null) return;
            if (!$('#measurement_options_form')[0].reportValidity()) return;
            if (!$('#retention_form')[0].reportValidity()) return;
            const options = currentOptions();
            options.public_servers = $('#public_servers').prop('checked') ? '1' : '0';
            options.public_selection = publicSelection;
            options.combine_servers = $('#combine_servers').prop('checked') ? '1' : '0';
            options.servers = $('#servers_json').val();
            if (options.combine_servers === '1' && options.public_servers === '1') {
                const allowed = approvedPublicIds();
                if ((customServers() || []).some(server => catalog.some(official =>
                    allowed.includes(official.id) && (String(server.id) === official.id
                        || String(server.server ?? '').replace(/\/+$/, '') === official.server.replace(/\/+$/, ''))))) {
                    showStatus('#settings_status', "{{ lang._('Custom and allowed official servers share an ID or URL. Edit the custom entry or remove the official server from the allowed list before combining.') }}", true);
                    return;
                }
            }
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
                showStatus('#version', readableError(data?.error) || "{{ lang._('LibreSpeed setup is incomplete. See Advanced settings.') }}", true);
                updateControls();
                return;
            }
            const version = data.message.match(/^librespeed-cli\s+(v[^\s]+)(?:\s+\(built on 1970-01-01 00:00:00 UTC\))?$/i);
            showStatus('#version', version ? 'LibreSpeed CLI ' + version[1] : data.message);
            engineReady = true;
            updateControls();
            serversReload();
        }, '#version');
        $('#serverlistAct').on('click', function() {
            if (running || starting || saving || detecting) return;
            detectionChecked = false;
            if (canRun) renderConnection(null);
            serversReload();
        });
        $('a[href="#history"]').on('shown.bs.tab', function() {
            if (!historyLoaded) historyReload();
            charts.forEach(chart => chart.resize());
        });
        $('a[href="#measurement"]').on('shown.bs.tab', function() {
            if (liveChart) liveChart.resize();
            detectServer();
        });
        $('#history_filters').on('change', function() { historyPage = 1; historyReload(); });
        $('#history_previous').on('click', function() { if (historyPage > 1) { historyPage--; historyReload(); } });
        $('#history_next').on('click', function() { if (historyPage < 200) { historyPage++; historyReload(); } });
        $('#refresh_history').on('click', historyReload);
        $('#test_form').on('submit', function(event) {
            event.preventDefault();
            if (!canRun || !engineReady || !serversReady || !defaultsReady || !statusReady || running || starting || saving || detecting || !this.reportValidity()
                || !$('#measurement_options_form')[0].reportValidity()) return;
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
                    scheduleStatusCheck(pollGeneration);
                    return;
                }
                followStatus(data.run_id);
            }, '#test_status').fail(function() {
                $('#readout_hint').text("{{ lang._('Test status is unknown.') }}");
                statusProblem("{{ lang._('Start response lost. The test may have started; check its status before retrying.') }}");
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
                renderResults([]);
                renderLive(null);
                $('#detected_server').text("{{ lang._('Server not detected') }}");
                showStatus('#detection_status', '');
                showStatus('#test_status', "{{ lang._('History cleared.') }}");
                historyReload();
            }, '#history_status').always(() => $('#deletelogAct').prop('disabled', false));
        });
    });
</script>
