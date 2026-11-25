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
    .speedtest-tabs > li:not(.active) > a { color: inherit; }
    .speedtest-surface [hidden] { display: none !important; }
    .speedtest-surface .content-box-main { padding: clamp(14px, 2vw, 24px); }
    .speedtest-surface h2 { margin: 0 0 6px; font-size: 1.5em; }
    .speedtest-surface h3 { margin: 0 0 8px; font-size: 1.16em; }
    .speedtest-surface .help-block, .speedtest-secondary { color: inherit; line-height: 1.45; }
    .speedtest-header { display: flex; flex-wrap: wrap; justify-content: space-between; gap: 12px 24px; margin-bottom: 20px; }
    .speedtest-header p { margin: 0; }
    .speedtest-heading { display: flex; align-items: center; gap: 10px; }
    .speedtest-heading img { flex: none; border-radius: 50%; }
    .speedtest-status { margin: 0; }
    .speedtest-status:not(:empty) { margin-bottom: 10px; }
    #check_status { margin-bottom: 12px; }
    .speedtest-surface fieldset, .speedtest-field { min-width: 0; }
    .speedtest-field { margin: 0 0 12px; }
    .speedtest-field > label, .speedtest-toolbar label { display: block; }
    .speedtest-option-grid { display: grid; gap: 0 12px; grid-template-columns: repeat(auto-fit, minmax(min(100%, 150px), 1fr)); }
    .speedtest-run-note { margin: 0 0 8px; max-width: 72ch; }
    #server_controls, #custom_server_group { max-width: 620px; }
    .speedtest-actions { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; margin: 12px 0; }
    .speedtest-subtle { text-decoration: underline; color: inherit; }
    .speedtest-server-preview { margin-top: 8px; overflow-wrap: anywhere; }
    .speedtest-readout { min-width: 0; margin-top: 20px; padding-top: 16px; border-top: 1px solid rgba(127, 127, 127, .38); }
    .speedtest-meta { display: flex; flex-wrap: wrap; align-items: baseline; gap: 4px 12px; margin: 0; overflow-wrap: anywhere; }
    .speedtest-metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 130px), 1fr)); align-items: start; gap: 12px; margin: 16px 0 0; max-width: 760px; }
    .speedtest-metrics > div { min-width: 0; }
    .speedtest-metrics dt { margin-bottom: 4px; font-weight: 600; }
    .speedtest-metrics dd { margin: 0; font-size: clamp(1.25em, 2vw, 1.75em); font-weight: 600; font-variant-numeric: tabular-nums; overflow-wrap: anywhere; }
    .speedtest-gauge svg { display: block; width: min(100%, 88px); height: auto; }
    .speedtest-gauge-scale { display: block; font-size: max(12px, .55em); font-weight: 400; }
    .speedtest-gauge-track { stroke: currentColor; opacity: .2; }
    .speedtest-gauge-download { color: #b52da5; }
    .speedtest-gauge-upload { color: #00818b; }
    .speedtest-result-details { display: flex; flex-wrap: wrap; gap: 8px 24px; margin: 0 0 8px; }
    .speedtest-result-details > div { min-width: 0; }
    .speedtest-result-details dd { margin: 0; overflow-wrap: anywhere; }
    .speedtest-toolbar { display: flex; flex-wrap: wrap; align-items: end; gap: 12px; margin: 16px 0; }
    #catalog_table, #custom_server_table { max-height: 24rem; overflow: auto; }
    #catalog_rows td:first-child, #custom_server_rows td:first-child { overflow-wrap: anywhere; }
    .speedtest-chart { position: relative; height: 220px; margin: 8px 0 16px; }
    .speedtest-disclosure { margin: 12px 0; }
    .speedtest-disclosure > summary { cursor: pointer; font-weight: 600; }
    .speedtest-disclosure > div { margin-top: 10px; }
    .speedtest-disclosure > summary:focus-visible { outline: 2px solid currentColor; outline-offset: 3px; }
    .speedtest-surface progress { display: block; width: 100%; max-width: 760px; height: 8px; margin-bottom: 12px; }
    .speedtest-surface .table td { vertical-align: top; }
    .speedtest-surface .table .speedtest-disclosure { margin: 3px 0 0; }
    .speedtest-surface .numeric { font-variant-numeric: tabular-nums; white-space: nowrap; }
    .speedtest-surface .section-note { max-width: 72ch; }
    .speedtest-settings { max-width: 900px; }
    .speedtest-settings > .speedtest-disclosure { margin: 0; padding: 12px 0; border-top: 1px solid rgba(127, 127, 127, .38); }
    .speedtest-settings > .speedtest-disclosure > summary { font-size: 1.08em; }
    .speedtest-surface .speedtest-support { padding-block: 12px; border-top: 1px solid rgba(127, 127, 127, .38); }
    #schedule_options { max-width: 760px; }
    @media (max-width: 620px) {
        #reportAct { width: 100%; }
        .speedtest-toolbar > div { flex: 1 1 120px; min-width: 0; }
        .speedtest-chart { height: 180px; }
    }
</style>
<ul class="nav nav-tabs speedtest-tabs" role="tablist" aria-label="{{ lang._('Speedtest sections') }}">
    <li class="active" role="presentation"><a id="measurement_tab" href="#measurement" data-toggle="tab" role="tab" aria-controls="measurement" aria-selected="true">{{ lang._('Run test') }}</a></li>
    <li role="presentation"><a id="history_tab" href="#history" data-toggle="tab" role="tab" aria-controls="history" aria-selected="false" tabindex="-1">{{ lang._('History') }}</a></li>
    {% if canSchedule %}<li role="presentation"><a id="schedule_tab" href="#schedule" data-toggle="tab" role="tab" aria-controls="schedule" aria-selected="false" tabindex="-1">{{ lang._('Schedule') }}</a></li>{% endif %}
    <li role="presentation"><a id="setup_tab" href="#setup" data-toggle="tab" role="tab" aria-controls="setup" aria-selected="false" tabindex="-1">{{ lang._('Settings') }}</a></li>
</ul>
<div class="tab-content content-box speedtest-surface">
    <div id="measurement" class="tab-pane active" role="tabpanel" aria-labelledby="measurement_tab">
        <div class="content-box-main">
            <div class="speedtest-header">
                <div class="speedtest-heading">
                    <img src="/ui/img/speedtest-community/speedtest-logo.png" width="36" height="36" alt="" decoding="async">
                    <div>
                        <h2>{{ lang._('Speedtest') }}</h2>
                        <p>{{ lang._('Measure throughput and latency from this firewall.') }}</p>
                    </div>
                </div>
            </div>
            <p id="engine_status" class="speedtest-status" role="status"></p>
            <div id="test_status" class="speedtest-status" role="status" aria-live="polite"></div>
            <button id="check_status" type="button" class="btn btn-default" aria-describedby="test_status" hidden>{{ lang._('Check test status') }}</button>
            {% if canRun %}
            <form id="test_form">
                <div id="server_setup_notice" class="speedtest-status" role="status" hidden>
                    {{ lang._('No test server is configured.') }}
                    {% if canConfigure %}
                    <a id="open_server_setup" class="speedtest-subtle" href="#setup">{{ lang._('Set up servers') }}</a>
                    {% else %}
                    {{ lang._('Ask an administrator to add an HTTPS test server in Settings.') }}
                    {% endif %}
                </div>
                <p id="run_defaults_status" class="speedtest-status" role="status"></p>
                <p id="server_status" class="speedtest-status" role="status"></p>
                <fieldset id="test_controls" disabled>
                    <div class="speedtest-field"><button class="btn btn-primary" id="reportAct" type="submit" aria-describedby="run_notice"><i class="fa fa-play" aria-hidden="true"></i> {{ lang._('Run test') }}</button></div>
                    <p id="run_notice" class="speedtest-run-note">
                        {{ lang._('Test servers see the firewall’s public IP.') }}
                        <span id="throughput_warning">{{ lang._('Throughput tests may saturate the connection.') }}</span>
                        <span id="comparison_warning" hidden>{{ lang._('Each selected server runs a separate test, one at a time.') }}</span>
                    </p>
                    <p id="run_overrides" hidden><a class="speedtest-subtle" href="#setup" id="open_test_settings">{{ lang._('Using unsaved measurement options') }}</a></p>
                </fieldset>
            </form>
            {% else %}
            <p>{{ lang._('View only. Running tests requires the Speedtest run privilege.') }}</p>
            {% endif %}
            <section class="speedtest-readout" aria-labelledby="readout_heading">
                <h3 id="readout_heading">{{ lang._('Latest result') }}</h3>
                <p id="readout_hint" class="speedtest-secondary">{{ lang._('Loading latest result...') }}</p>
                <p id="result_meta" class="speedtest-meta" hidden><strong id="test_server"></strong><time id="result_time" hidden></time></p>
                <div id="run_progress" hidden>
                    <p id="phase_status" role="status"></p>
                    <progress id="phase_progress" max="100" aria-label="{{ lang._('Current measurement phase progress') }}"></progress>
                </div>
                <dl id="test_metrics" class="speedtest-metrics" hidden>
                    <div id="download_metric" hidden>
                        <dt>{{ lang._('Download') }}</dt>
                        <dd class="speedtest-gauge">
                            <span id="download"></span>
                            <svg viewBox="15 12 190 103" aria-hidden="true" focusable="false" class="speedtest-gauge-download">
                                <path class="speedtest-gauge-track" d="M20 110 A90 90 0 0 1 200 110" fill="none" stroke-width="6"/>
                                <path id="download_arc" d="M20 110 A90 90 0 0 1 200 110" fill="none" stroke="currentColor" stroke-width="6" pathLength="100" stroke-dasharray="0 100"/>
                                <g id="download_needle" transform="rotate(-90 110 110)" opacity="0"><path d="M110 15 L105 31 L115 31 Z" fill="currentColor"/></g>
                            </svg>
                            <small class="speedtest-gauge-scale">{{ lang._('Scale:') }} <span id="download_scale"></span></small>
                        </dd>
                    </div>
                    <div id="upload_metric" hidden>
                        <dt>{{ lang._('Upload') }}</dt>
                        <dd class="speedtest-gauge">
                            <span id="upload"></span>
                            <svg viewBox="15 12 190 103" aria-hidden="true" focusable="false" class="speedtest-gauge-upload">
                                <path class="speedtest-gauge-track" d="M20 110 A90 90 0 0 1 200 110" fill="none" stroke-width="6"/>
                                <path id="upload_arc" d="M20 110 A90 90 0 0 1 200 110" fill="none" stroke="currentColor" stroke-width="6" pathLength="100" stroke-dasharray="0 100"/>
                                <g id="upload_needle" transform="rotate(-90 110 110)" opacity="0"><path d="M110 15 L105 31 L115 31 Z" fill="currentColor"/></g>
                            </svg>
                            <small class="speedtest-gauge-scale">{{ lang._('Scale:') }} <span id="upload_scale"></span></small>
                        </dd>
                    </div>
                    <div id="latency_metric" hidden><dt>{{ lang._('Latency') }}</dt><dd id="latency"></dd></div>
                    <div id="jitter_metric" hidden><dt>{{ lang._('Jitter') }}</dt><dd id="jitter"></dd></div>
                </dl>
                <details id="live_chart_region" class="speedtest-disclosure" hidden>
                    <summary>{{ lang._('Live throughput chart') }}</summary>
                    <div>
                        <p id="live_speed" class="numeric"></p>
                        <p id="live_chart_status" class="speedtest-status" role="status"></p>
                        <div class="speedtest-chart" id="live_plot"><canvas id="live_chart" role="img" aria-label="{{ lang._('Running average speed by direction') }}"></canvas></div>
                        <p>{{ lang._('Speeds are running averages. Time starts again for each direction.') }}</p>
                    </div>
                </details>
                <details id="result_details" class="speedtest-disclosure" hidden>
                    <summary>{{ lang._('Test details') }}</summary>
                    <div>
                        <dl class="speedtest-result-details"></dl>
                        <p>{{ lang._('Gauge scales are for display, not link capacity. TLS refers to the latency probe.') }}</p>
                    </div>
                </details>
                <div class="table-responsive" id="comparison" hidden>
                    <table class="table table-striped"><caption class="sr-only">{{ lang._('Sequential server comparison') }}</caption><thead><tr><th>{{ lang._('Server') }}</th><th>{{ lang._('Download') }}</th><th>{{ lang._('Upload') }}</th><th>{{ lang._('Latency') }}</th><th>{{ lang._('Jitter') }}</th><th>{{ lang._('Status') }}</th></tr></thead><tbody id="comparison_rows"></tbody></table>
                </div>
            </section>
        </div>
    </div>
    <div id="history" class="tab-pane" role="tabpanel" aria-labelledby="history_tab">
        <div class="content-box-main">
            <h2>{{ lang._('Test history') }}</h2>
            <p class="section-note">{{ lang._('Compare results from the same server and test settings.') }}</p>
            <form id="history_filters">
                <div class="speedtest-toolbar">
                    <div><label for="history_days">{{ lang._('Period') }}</label><select id="history_days" class="form-control"><option value="1">{{ lang._('24 hours') }}</option><option value="7">{{ lang._('7 days') }}</option><option value="30" selected>{{ lang._('30 days') }}</option><option value="90">{{ lang._('90 days') }}</option><option value="365">{{ lang._('1 year') }}</option><option value="0">{{ lang._('All dates') }}</option></select></div>
                    <div><label for="history_server">{{ lang._('Server') }}</label><select id="history_server" class="form-control"><option value="all">{{ lang._('All servers') }}</option></select></div>
                    <div><label for="history_provider">{{ lang._('Results from') }}</label><select id="history_provider" class="form-control"><option value="librespeed">{{ lang._('Speedtest') }}</option><option value="legacy">{{ lang._('Legacy CSV') }}</option></select></div>
                    <button class="btn btn-default" id="refresh_history" type="button">{{ lang._('Refresh history') }}</button>
                    <button class="btn btn-default" id="reset_history_filters" type="button" hidden>{{ lang._('Reset filters') }}</button>
                </div>
                <details id="history_more_filters" class="speedtest-disclosure">
                    <summary>{{ lang._('More filters') }}</summary>
                    <div class="speedtest-toolbar">
                        <div><label for="history_mode">{{ lang._('Mode') }}</label><select id="history_mode" class="form-control"><option value="all">{{ lang._('All modes') }}</option><option value="both">{{ lang._('Full test') }}</option><option value="download">{{ lang._('Download') }}</option><option value="upload">{{ lang._('Upload') }}</option><option value="latency">{{ lang._('Latency') }}</option></select></div>
                        <div><label for="history_outcome">{{ lang._('Outcome') }}</label><select id="history_outcome" class="form-control"><option value="all">{{ lang._('All outcomes') }}</option><option value="success">{{ lang._('Successful') }}</option><option value="failed">{{ lang._('Failed') }}</option></select></div>
                        <div><label for="history_origin">{{ lang._('Trigger') }}</label><select id="history_origin" class="form-control"><option value="all">{{ lang._('All triggers') }}</option><option value="manual">{{ lang._('GUI') }}</option><option value="scheduled">{{ lang._('Scheduled') }}</option><option value="cli">{{ lang._('CLI / legacy cron') }}</option><option value="legacy">{{ lang._('Imported CSV') }}</option></select></div>
                        <div><label for="history_family">{{ lang._('IP family setting') }}</label><select id="history_family" class="form-control"><option value="all">{{ lang._('All families') }}</option><option value="auto">{{ lang._('Automatic') }}</option><option value="ipv4">IPv4</option><option value="ipv6">IPv6</option></select></div>
                        <div><label for="history_source">{{ lang._('Source binding') }}</label><select id="history_source" class="form-control"><option value="all">{{ lang._('All sources') }}</option></select></div>
                    </div>
                </details>
            </form>
            <p id="history_status" class="speedtest-status" role="status"></p>
            <div id="history_results" hidden>
                <p id="history_summary"></p>
                <div class="table-responsive" tabindex="0" role="region" aria-label="{{ lang._('Recorded tests') }}">
                    <table class="table table-striped table-condensed">
                        <caption class="sr-only">{{ lang._('Recorded tests') }}</caption>
                        <thead><tr>
                            <th scope="col">{{ lang._('Local time') }}</th><th scope="col">{{ lang._('Server') }}</th><th scope="col">{{ lang._('Mode') }}</th>
                            <th scope="col">{{ lang._('Download') }}</th><th scope="col">{{ lang._('Upload') }}</th><th scope="col">{{ lang._('Latency') }}</th><th scope="col">{{ lang._('Jitter') }}</th><th scope="col">{{ lang._('Trigger / outcome') }}</th>
                        </tr></thead>
                        <tbody id="log_block"></tbody>
                    </table>
                </div>
                <div id="history_pagination" class="speedtest-actions" hidden><button id="history_previous" type="button" class="btn btn-default">{{ lang._('Newer') }}</button><span id="history_page"></span><button id="history_next" type="button" class="btn btn-default">{{ lang._('Older') }}</button></div>
                <details id="history_trends" class="speedtest-disclosure" hidden>
                    <summary>{{ lang._('Trends and averages') }}</summary>
                    <div>
                        <div class="row" id="trend_charts" hidden>
                            <div class="col-md-6" id="throughput_chart_group"><h3>{{ lang._('Throughput') }}</h3><div class="speedtest-chart"><canvas id="throughput_chart" role="img" aria-label="{{ lang._('Historical download and upload averages') }}"></canvas></div></div>
                            <div class="col-md-6" id="latency_chart_group"><h3>{{ lang._('Latency and jitter') }}</h3><div class="speedtest-chart"><canvas id="latency_chart" role="img" aria-label="{{ lang._('Historical latency and jitter averages') }}"></canvas></div></div>
                        </div>
                        <p id="chart_note" class="help-block"></p>
                        <div class="table-responsive"><table class="table table-condensed"><caption>{{ lang._('Measured values from successful tests only') }}</caption><thead><tr><th>{{ lang._('Metric') }}</th><th>{{ lang._('Average') }}</th><th>{{ lang._('Minimum') }}</th><th>{{ lang._('Maximum') }}</th></tr></thead><tbody id="history_metrics"></tbody></table></div>
                    </div>
                </details>
            </div>
            <details class="speedtest-disclosure">
                <summary>{{ lang._('Export and manage history') }}</summary>
                <div>
                    <p>{{ lang._('Exports cover all retained dates. CSV includes full tests; JSONL includes detailed records. Clearing history removes both.') }}</p>
                    <div class="speedtest-actions">
                        <a href="/api/speedtest/download/csv" class="btn btn-default">{{ lang._('Export full-test CSV') }}</a>
                        <a href="/api/speedtest/download/json" class="btn btn-default">{{ lang._('Export detailed JSONL') }}</a>
                        {% if canClear %}<button class="btn btn-danger" id="deletelogAct" type="button">{{ lang._('Clear history') }}</button>{% endif %}
                    </div>
                </div>
            </details>
        </div>
    </div>
    {% if canSchedule %}
    <div id="schedule" class="tab-pane" role="tabpanel" aria-labelledby="schedule_tab">
        <div class="content-box-main">
            <h2>{{ lang._('Schedule') }}</h2>
            <p class="section-note">{{ lang._('Schedule tests outside busy hours. Scheduled tests use the saved measurement settings.') }}</p>
            <form id="schedule_form"><fieldset id="schedule_controls" disabled>
                <div class="checkbox"><label><input id="schedule_enabled" type="checkbox">{{ lang._('Enable scheduled tests') }}</label></div>
                <fieldset id="schedule_options" disabled hidden>
                    <div class="speedtest-option-grid">
                        <div class="speedtest-field"><label for="schedule_cadence">{{ lang._('Frequency') }}</label><select id="schedule_cadence" class="form-control"><option value="hourly">{{ lang._('Hourly') }}</option><option value="daily">{{ lang._('Daily') }}</option><option value="weekdays">{{ lang._('Weekdays') }}</option><option value="weekly">{{ lang._('Weekly') }}</option></select></div>
                        <div id="schedule_hour_field" class="speedtest-field"><label for="schedule_hour">{{ lang._('Hour (0–23)') }}</label><input id="schedule_hour" class="form-control" type="number" min="0" max="23" value="3" required></div>
                        <div class="speedtest-field"><label for="schedule_minute">{{ lang._('Minute (0–59)') }}</label><input id="schedule_minute" class="form-control" type="number" min="0" max="59" value="0" required></div>
                        <div id="schedule_weekday_field" class="speedtest-field"><label for="schedule_weekday">{{ lang._('Day of week') }}</label><select id="schedule_weekday" class="form-control"><option value="0">{{ lang._('Sunday') }}</option><option value="1">{{ lang._('Monday') }}</option><option value="2">{{ lang._('Tuesday') }}</option><option value="3">{{ lang._('Wednesday') }}</option><option value="4">{{ lang._('Thursday') }}</option><option value="5">{{ lang._('Friday') }}</option><option value="6">{{ lang._('Saturday') }}</option></select></div>
                    </div>
                    <div class="speedtest-option-grid">
                        <div class="speedtest-field"><label for="schedule_selection">{{ lang._('Server selection') }}</label><select id="schedule_selection" class="form-control"><option value="0">{{ lang._('Automatic (lowest latency)') }}</option><option value="custom">{{ lang._('Choose server IDs') }}</option><option value="-1">{{ lang._('Compare all servers') }}</option></select></div>
                        <div id="schedule_server_field" class="speedtest-field" hidden><label for="schedule_server">{{ lang._('Server IDs') }}</label><input id="schedule_server" class="form-control" type="text" placeholder="42,84" pattern="[1-9][0-9]*(,[1-9][0-9]*)*" disabled required></div>
                        <div class="speedtest-field"><label for="schedule_mode">{{ lang._('Test mode') }}</label><select id="schedule_mode" class="form-control"><option value="both">{{ lang._('Download and upload') }}</option><option value="download">{{ lang._('Download only') }}</option><option value="upload">{{ lang._('Upload only') }}</option><option value="latency">{{ lang._('Latency and jitter only') }}</option></select></div>
                    </div>
                    <p id="schedule_timezone"></p>
                    <p id="schedule_conflicts" class="speedtest-status text-warning" role="status"></p>
                </fieldset>
                <p id="schedule_preview" class="speedtest-status"></p>
                <div class="speedtest-actions">
                    <button id="save_schedule" class="btn btn-primary" type="submit" disabled>{{ lang._('Save and apply schedule') }}</button>
                    <button id="discard_schedule" class="btn btn-default" type="button" hidden>{{ lang._('Discard changes') }}</button>
                </div>
            </fieldset></form>
            <p id="schedule_status" class="speedtest-status" role="status"></p>
            <details id="schedule_recovery" class="speedtest-disclosure">
                <summary>{{ lang._('Cron tools') }}</summary>
                <div>
                    <p>{{ lang._('Cron uses the firewall timezone. Daylight-saving changes may skip or repeat a run. Overlapping tests are refused.') }}</p>
                    <div class="speedtest-actions"><button id="apply_schedule" class="btn btn-default" type="button" disabled>{{ lang._('Apply saved schedule') }}</button>
                    <a class="speedtest-subtle" href="/ui/cron">{{ lang._('Open OPNsense cron') }}</a></div>
                </div>
            </details>
        </div>
    </div>
    {% endif %}
    <div id="setup" class="tab-pane" role="tabpanel" aria-labelledby="setup_tab">
        <div class="content-box-main speedtest-settings">
            <h2>{{ lang._('Advanced settings') }}</h2>
            {% if canConfigure %}
            <p class="section-note">{{ lang._('Save settings to apply them to future GUI, CLI and scheduled tests.') }}</p>
            <div class="speedtest-actions">
                <button id="save_settings" type="button" class="btn btn-primary" disabled>{{ lang._('Save settings') }}</button>
                <button id="discard_settings" type="button" class="btn btn-default" hidden>{{ lang._('Discard changes') }}</button>
            </div>
            {% endif %}
            <p id="settings_status" class="speedtest-status" role="status"></p>
            {% if canRun or canConfigure %}
            <details id="measurement_options" class="speedtest-disclosure">
            <summary id="measurement_settings_heading">{{ lang._('Measurement options') }}</summary>
            <div>
            <p class="section-note">{{ lang._('Unsaved options apply only to manual tests started from this page.') }}</p>
            {% if canRun %}
            <fieldset id="server_controls" disabled>
                <div class="speedtest-field">
                    <label for="serverid">{{ lang._('Server') }}</label>
                    <select id="serverid" class="form-control" aria-describedby="server_choice_help">
                        <option value="0" selected>{{ lang._('Auto (lowest latency)') }}</option>
                        <option value="-1">{{ lang._('Compare all servers') }}</option>
                        <option value="custom">{{ lang._('Choose server IDs') }}</option>
                    </select>
                    <span id="server_choice_help" class="help-block">{{ lang._('Auto checks latency each time you run a test. A specific server is reused for manual tests on this page.') }}</span>
                </div>
                <div class="speedtest-field" id="custom_server_group" hidden>
                    <label for="custom_servers">{{ lang._('Server IDs') }}</label>
                    <input id="custom_servers" type="text" class="form-control" pattern="[1-9][0-9]*(,[1-9][0-9]*)*" placeholder="42,84" aria-describedby="custom_servers_help" disabled required>
                    <span id="custom_servers_help" class="help-block">{{ lang._('Separate configured IDs with commas. Each server runs a separate test.') }}</span>
                </div>
                <p id="selection_status" class="speedtest-status" role="status"></p>
                <div class="speedtest-actions">
                    <button id="detect_server" class="btn btn-default btn-sm" type="button" aria-describedby="server_probe_help" disabled>{{ lang._('Find and select lowest-latency server') }}</button>
                    <button id="serverlistAct" class="btn btn-default btn-sm" type="button">{{ lang._('Reload server list') }}</button>
                </div>
                <p id="server_probe_help" class="help-block">{{ lang._('The scan checks latency only. Servers see the firewall’s public IP.') }}</p>
                <div id="server_preview" class="speedtest-server-preview" hidden>
                    <strong id="detected_server"></strong>
                    <p id="detection_status" class="speedtest-status" role="status"></p>
                    <p id="preview_note" hidden>{{ lang._('Selected for manual tests on this page. No bandwidth test was run or result saved to history.') }}</p>
                    <details id="preview_details" class="speedtest-disclosure" hidden>
                        <summary>{{ lang._('Scan connection details') }}</summary>
                        <div><dl class="speedtest-result-details"></dl></div>
                    </details>
                </div>
            </fieldset>
            {% endif %}
            <form id="measurement_options_form">
                <fieldset id="measurement_options_controls" disabled>
                    {% if canRun %}
                    <div class="speedtest-field">
                        <label for="mode">{{ lang._('Test mode') }}</label>
                        <select id="mode" class="form-control" aria-describedby="manual_mode_help">
                            <option value="both" selected>{{ lang._('Full test') }}</option>
                            <option value="download">{{ lang._('Download only') }}</option>
                            <option value="upload">{{ lang._('Upload only') }}</option>
                            <option value="latency">{{ lang._('Latency and jitter only') }}</option>
                        </select>
                        <span id="manual_mode_help" class="help-block section-note">{{ lang._('Full test measures download, upload, latency and jitter. This mode choice applies only to manual tests from this page.') }}</span>
                    </div>
                    {% endif %}
                    <div class="speedtest-field">
                        <label for="exclude">{{ lang._('Exclude server IDs') }}</label>
                        <input id="exclude" type="text" class="form-control" pattern="([1-9][0-9]*(,[1-9][0-9]*)*)?">
                        <span class="help-block">{{ lang._('Comma-separated IDs apply only to Auto, Compare all, and the one-time scan.') }}</span>
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
                    <p class="help-block">{{ lang._('Longer tests and higher limits can use more bandwidth or memory.') }}</p>
                    <div class="speedtest-actions">
                        <button id="reset_measurement" type="button" class="btn btn-default">{{ lang._('Use recommended measurement options') }}</button>
                        <button id="restore_measurement" type="button" class="btn btn-default" hidden>{{ lang._('Restore saved measurement options') }}</button>
                    </div>
                </fieldset>
            </form>
            </div>
            </details>
            {% endif %}
            {% if canConfigure %}
            <details id="server_options" class="speedtest-disclosure">
            <summary id="server_settings_heading">{{ lang._('Servers') }}</summary>
            <div>
            <div class="checkbox"><label><input id="public_servers" type="checkbox">{{ lang._('Use the public server catalog') }}</label></div>
            <details id="catalog_panel" class="speedtest-disclosure" hidden>
            <summary>{{ lang._('Manage allowed official servers') }}</summary>
            <div>
            <p id="catalog_selection_status" class="speedtest-status" role="status"></p>
            <div class="speedtest-toolbar">
                <div><label for="catalog_search">{{ lang._('Search by server, sponsor, host, or ID') }}</label><input id="catalog_search" class="form-control" type="search"></div>
                <button id="catalog_refresh" type="button" class="btn btn-default" disabled>{{ lang._('Refresh catalog') }}</button>
                <button id="catalog_allow_all" type="button" class="btn btn-default" disabled hidden>{{ lang._('Allow all official servers') }}</button>
                <button id="catalog_allow_none" type="button" class="btn btn-default" disabled hidden>{{ lang._('Remove all official servers') }}</button>
            </div>
            <p id="catalog_status" class="speedtest-status" role="status"></p>
            <p id="catalog_no_matches" hidden>{{ lang._('No servers match your search.') }}</p>
            <div class="table-responsive" id="catalog_table" tabindex="0" role="region" aria-label="{{ lang._('Public servers') }}" hidden>
                <table class="table table-striped">
                    <caption class="sr-only">{{ lang._('Public servers') }}</caption>
                    <thead><tr><th scope="col">{{ lang._('Server') }}</th><th scope="col">{{ lang._('Sponsor') }}</th><th scope="col">{{ lang._('Allowed') }}</th><th scope="col">{{ lang._('Actions') }}</th></tr></thead>
                    <tbody id="catalog_rows"></tbody>
                </table>
            </div>
            </div>
            </details>
            <div id="combine_servers_field" class="checkbox" hidden><label><input id="combine_servers" type="checkbox" disabled>{{ lang._('Include allowed official servers alongside custom servers') }}</label></div>
            <h3>{{ lang._('Custom servers') }}</h3>
            <p id="servers_help">{{ lang._('Custom servers replace the official list unless you combine them. With no custom entries, the firewall-managed server file takes priority over the catalog.') }}</p>
            <fieldset id="custom_server_controls" disabled>
                <div class="table-responsive" id="custom_server_table" tabindex="0" role="region" aria-label="{{ lang._('Custom servers') }}" hidden>
                    <table class="table table-striped">
                        <caption class="sr-only">{{ lang._('Custom servers') }}</caption>
                        <thead><tr><th scope="col">{{ lang._('Server') }}</th><th scope="col">{{ lang._('Actions') }}</th></tr></thead>
                        <tbody id="custom_server_rows"></tbody>
                    </table>
                </div>
                <p id="custom_server_status" role="status" aria-live="polite"></p>
                <button id="add_custom_server" type="button" class="btn btn-default">{{ lang._('Add custom server') }}</button>
                <form id="custom_server_editor" class="form-horizontal" hidden>
                    <h5 id="custom_server_editor_title"></h5>
                    <div class="form-group"><label for="server_edit_name" class="col-sm-3 control-label">{{ lang._('Name') }}</label><div class="col-sm-9"><input id="server_edit_name" class="form-control" maxlength="200" required></div></div>
                    <div class="form-group"><label for="server_edit_server" class="col-sm-3 control-label">{{ lang._('HTTPS base URL') }}</label><div class="col-sm-9"><input id="server_edit_server" type="url" class="form-control" placeholder="https://speed.example.net/backend/" required><span class="help-block">{{ lang._('Use the backend URL, not a results page. Standard PHP endpoint paths are filled in for you.') }}</span></div></div>
                    <details id="server_endpoint_options" class="speedtest-disclosure">
                        <summary>{{ lang._('Advanced endpoint options') }}</summary>
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
                    <summary>{{ lang._('Edit raw server JSON') }}</summary>
                    <div><label for="servers_json">{{ lang._('Custom servers (JSON)') }}</label>
                    <textarea id="servers_json" class="form-control" rows="7" spellcheck="false" aria-describedby="servers_help"></textarea></div>
                </details>
            </fieldset>
            </div>
            </details>
            <details id="retention_options" class="speedtest-disclosure">
            <summary>{{ lang._('History retention') }}</summary>
            <div>
            <form id="retention_form" class="speedtest-toolbar">
                <div><label for="retention_days">{{ lang._('Keep history for days') }}</label><input id="retention_days" class="form-control" type="number" min="0" max="3650" value="31" required></div>
                <div><label for="history_limit">{{ lang._('Maximum history records') }}</label><input id="history_limit" class="form-control" type="number" min="0" max="100000" value="10000" required></div>
                <button id="reset_retention" type="button" class="btn btn-default" disabled>{{ lang._('Use recommended retention') }}</button>
            </form>
            <p class="help-block">{{ lang._('0 means unlimited. The recommended limits are 31 days and 10,000 records. Shorter limits prune both histories after the next test; export first.') }}</p>
            </div>
            </details>
            {% else %}
            {% if canRun %}
            <p>{{ lang._('Saving defaults or changing servers and retention requires the Speedtest configure privilege.') }}</p>
            {% endif %}
            {% endif %}
            <details class="speedtest-disclosure">
                <summary>{{ lang._('Speed display') }}</summary>
                <div class="speedtest-field">
                    <label for="speed_units">{{ lang._('Speed units') }}</label>
                    <select id="speed_units" class="form-control" aria-describedby="speed_units_help">
                        <option value="auto" selected>{{ lang._('Auto') }}</option>
                        <option value="bps">bps</option>
                        <option value="kbps">kbps</option>
                        <option value="Mbps">Mbps</option>
                        <option value="Gbps">Gbps</option>
                        <option value="Tbps">Tbps</option>
                    </select>
                    <span id="speed_units_help" class="help-block">{{ lang._('Display only. This does not cap the test speed or change stored results.') }}</span>
                </div>
            </details>
            <details class="speedtest-disclosure">
                <summary>{{ lang._('About Speedtest') }}</summary>
                <div>
                    <p>{{ lang._('Measurements use the LibreSpeed Rust engine.') }}
                        <a class="speedtest-subtle" href="https://librespeed.org/" target="_blank" rel="noopener noreferrer">{{ lang._('About the engine') }}</a>
                    </p>
                    <p>{{ lang._('Engine version:') }} <span id="version" role="status">{{ lang._('Checking...') }}</span></p>
                    <p>{{ lang._('Test endpoints must use HTTPS with verified certificates. This is independent of whether the OPNsense GUI uses HTTP or HTTPS.') }}</p>
                    <p>{{ lang._('For private endpoints, install a PEM CA bundle at /usr/local/etc/speedtest-community/ca.pem and enable the private CA option. It replaces the engine trust store for that run. Use separate issuing CA and server certificates.') }}</p>
                    <p>{{ lang._('The public server catalog comes from LibreSpeed.org over HTTPS. The registry and selected test servers can see the firewall’s public IP. Results and telemetry are not shared.') }}</p>
                    <p>{{ lang._('The optional firewall-managed server list is at') }} <code>/usr/local/etc/speedtest-community/librespeed-servers.json</code>.</p>
                </div>
            </details>
            <details class="speedtest-disclosure">
                <summary>{{ lang._('Terminal commands') }}</summary>
                <div><pre>opn-speedtest --help
opn-speedtest list
opn-speedtest run --mode latency --format json
opn-speedtest run --server 42 --server 84
opn-speedtest history --days 30 --format json</pre>
                <p>{{ lang._('Terminal commands share the GUI lock and history.') }}</p></div>
            </details>
            <details class="speedtest-disclosure">
                <summary>{{ lang._('Permissions and support') }}</summary>
                <div>
                    <p>{{ lang._('Assign privileges under System > Access > Users or Groups. View results includes charts, dashboard data and exports. Running tests, configuring settings, managing the schedule and clearing history require separate privileges. Grant View results alongside additional privileges. Read-only accounts cannot run tests or change settings.') }}</p>
                    <ul>
                        <li><a href="https://github.com/blackoutsecure/opn-repo/blob/efe2f572eb9016014b5395930e23006124a1f361/net-mgmt/speedtest-community/README.md" target="_blank" rel="noopener noreferrer">{{ lang._('Installation and CLI reference') }}</a></li>
                        <li><a href="https://github.com/librespeed/speedtest-cli-rust" target="_blank" rel="noopener noreferrer">{{ lang._('Measurement engine source') }}</a></li>
                        <li><a href="https://github.com/librespeed/speedtest" target="_blank" rel="noopener noreferrer">{{ lang._('Test server setup') }}</a></li>
                        <li><a href="https://github.com/librespeed/speedtest-rust" target="_blank" rel="noopener noreferrer">{{ lang._('Optional Rust server backend') }}</a></li>
                    </ul>
                </div>
            </details>
        </div>
    </div>
    <footer class="content-box-main speedtest-support">
        <a class="speedtest-subtle" href="https://blackoutsecure.app/" target="_blank" rel="noopener noreferrer">{{ lang._('Maintained by BlackOut Secure') }}</a>
        &middot; <a class="speedtest-subtle" href="https://github.com/blackoutsecure/opn-repo/issues" target="_blank" rel="noopener noreferrer">{{ lang._('Issues and feedback') }}</a>
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
    let configuredServers = new Map();
    let defaultsReady = false;
    let catalogLoading = false;
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
    let detectionGeneration = 0;
    let detectionTimer = null;
    let settingsReady = false;
    let scheduleReady = false;
    let saving = false;
    let historyPage = 1;
    let historyGeneration = 0;
    const savedSettings = {};
    let savedSchedule = null;
    let pollGeneration = 0;
    let pollTimer = null;
    let charts = [];
    let liveChart = null;
    let lastReadout = null;
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
    const defaultManualMode = 'both';
    const modeNames = {both: "{{ lang._('Full test') }}", download: "{{ lang._('Download') }}",
        upload: "{{ lang._('Upload') }}", latency: "{{ lang._('Latency') }}"};
    const speedDivisors = {bps: 0.000001, kbps: 0.001, Mbps: 1, Gbps: 1000, Tbps: 1000000};
    const originNames = {manual: "{{ lang._('GUI') }}", scheduled: "{{ lang._('Scheduled') }}",
        cli: "{{ lang._('CLI / legacy cron') }}", legacy: "{{ lang._('Legacy') }}"};
    const historyDefaults = {
        days: '30', server: 'all', mode: 'all', provider: 'librespeed', outcome: 'all',
        origin: 'all', family: 'all', source: 'all'
    };
    const scheduleFields = ['cadence', 'hour', 'minute', 'weekday', 'mode'];

    function updateControls() {
        const busy = running || starting || saving || detecting;
        const selected = $('#serverid').val();
        const mode = $('#mode').val();
        const alternateMode = canRun && mode !== defaultManualMode && Object.hasOwn(modeNames, mode);
        const specificServer = serversReady && (configuredServers.get(selected)
            || (selected === '-1' ? "{{ lang._('Compare all servers') }}" : selected === 'custom' ? "{{ lang._('Custom server IDs') }}" : ''));
        const catalogEnabled = $('#public_servers').prop('checked');
        const measurementDraft = defaultsReady && differs(currentOptions(), savedSettings);
        const settingsDraft = canConfigure && defaultsReady && settingsReady && differs(settingsOptions(), savedSettings);
        $('#test_controls, #server_controls').prop('disabled', busy || !defaultsReady || !canRun);
        $('#serverid').prop('disabled', !serversReady);
        $('#measurement_options_controls').prop('disabled', busy || !defaultsReady || (!canRun && !canConfigure));
        $('#reportAct').prop('disabled', busy || !engineReady || !serversReady || !defaultsReady || !statusReady || !canRun);
        $('#serverlistAct').prop('disabled', busy || serversLoading || !engineReady);
        $('#detect_server').prop('disabled',
            busy || !engineReady || !serversReady || !defaultsReady || !statusReady || !canRun);
        const overrides = [
            alternateMode && "{{ lang._('Test mode:') }} " + modeNames[mode],
            specificServer && "{{ lang._('Server:') }} " + specificServer,
            measurementDraft && "{{ lang._('Using unsaved measurement options') }}",
            canRun && engineReady && !serversReady && !serversLoading && "{{ lang._('Open server selection settings') }}"
        ].filter(Boolean);
        $('#run_overrides').prop('hidden', !overrides.length);
        $('#open_test_settings').text(overrides.join(' · '));
        $('#restore_measurement').prop('hidden', !measurementDraft && !alternateMode);
        $('#save_settings, #discard_settings').prop('disabled', busy || !settingsDraft || serverEditIndex !== null);
        $('#discard_settings').prop('hidden', !settingsDraft);
        $('#public_servers').prop('disabled', busy || !settingsReady);
        $('#reset_retention').prop('disabled', busy || !defaultsReady || !settingsReady || !canConfigure);
        $('#combine_servers').prop('disabled', busy || !settingsReady || !catalogEnabled);
        $('#custom_server_controls').prop('disabled', busy || !settingsReady);
        $('#servers_json').prop('disabled', serverEditIndex !== null);
        $('#catalog_refresh').prop('disabled', busy || !settingsReady || !defaultsReady || catalogLoading
            || !savedPublicServers || !catalogEnabled);
        $('#catalog_rows button').prop('disabled', busy || !settingsReady || serverEditIndex !== null);
        $('#catalog_allow_all, #catalog_allow_none').prop('disabled', busy || !settingsReady || !defaultsReady
            || catalogLoading || !savedPublicServers || !catalogEnabled);
        $('#schedule_controls').prop('disabled', busy || !scheduleReady);
        $('#apply_schedule').prop('disabled', busy || !scheduleReady || scheduleChanged());
        $('#deletelogAct').prop('disabled', busy);
        $('#check_status').prop('disabled', starting || detecting || statusRetrying);
        $('#custom_servers').prop('disabled', selected !== 'custom' || !serversReady);
        $('#custom_server_group').prop('hidden', selected !== 'custom' || !serversReady);
        $('#comparison_warning').prop('hidden', selected !== '-1'
            && !(selected === 'custom' && $('#custom_servers').val().includes(',')));
        $('#throughput_warning').prop('hidden', mode === 'latency');
    }
    function currentOptions() {
        const options = {};
        optionKeys.forEach(key => options[key] = $('#' + key).val());
        booleanKeys.forEach(key => options[key] = $('#' + key).prop('checked') ? '1' : '0');
        return options;
    }
    function fillMeasurementOptions(values) {
        $('#mode').val(defaultManualMode);
        optionKeys.forEach(key => $('#' + key).val(values[key]));
        booleanKeys.forEach(key => $('#' + key).prop('checked', values[key] === '1'));
    }
    function settingsOptions() {
        return {...currentOptions(), public_servers: $('#public_servers').prop('checked') ? '1' : '0',
            public_selection: publicSelection, combine_servers: $('#combine_servers').prop('checked') ? '1' : '0',
            servers: $('#servers_json').val(), retention_days: $('#retention_days').val(), history_limit: $('#history_limit').val()};
    }
    function differs(values, saved) {
        return Object.entries(values).some(([key, value]) => value !== saved[key]);
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
        updateControls();
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
        const desired = $('#public_servers').prop('checked');
        const enabled = savedPublicServers && desired;
        $('#catalog_panel, #combine_servers_field').prop('hidden', !desired);
        if (!desired) {
            $('#catalog_panel').prop('open', false);
            $('#catalog_search').val('');
            showStatus('#catalog_status', '');
        }
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
        $('#catalog_search').prop('disabled', !enabled || !catalogReceived);
        $('#catalog_allow_all').prop('hidden', publicSelection === 'all' || !enabled);
        $('#catalog_allow_none').prop('hidden', publicSelection === 'none' || !enabled);
        showStatus('#catalog_selection_status', publicSelection === 'all'
            ? "{{ lang._('All official servers are allowed, including new additions. Removing one creates a fixed allow-list.') }}"
            : publicSelection === 'none' ? "{{ lang._('No official servers are allowed.') }}"
            : "{{ lang._('Only selected servers are allowed. New additions require approval.') }}");
        if (desired && !savedPublicServers) showStatus('#catalog_status', "{{ lang._('Save settings to load the official catalog.') }}");
        updateControls();
    }
    function refreshCatalog() {
        if (!canConfigure || !settingsReady || !defaultsReady || catalogLoading
            || !savedPublicServers || !$('#public_servers').prop('checked')) return;
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
            showStatus('#catalog_status', '');
        }, '#catalog_status').always(function() {
            catalogLoading = false;
            updateControls();
        });
    }
    function clearPreview() {
        $('#server_preview, #preview_note, #preview_details').prop('hidden', true);
        $('#preview_details').prop('open', false);
        $('#preview_details dl').empty();
        $('#detected_server').text('');
        showStatus('#detection_status', '');
    }
    function serversReload() {
        if (!canRun || serversLoading) return;
        serversLoading = true;
        serversReady = false;
        clearPreview();
        const serverStatus = '#server_status, #selection_status';
        $('#server_setup_notice').prop('hidden', true);
        showStatus(serverStatus, "{{ lang._('Loading servers...') }}");
        updateControls();
        request('serverlist', {}, function(data) {
            if (!Array.isArray(data)) {
                if (data?.code === 'servers_unconfigured') {
                    showStatus('#server_status', '');
                    showStatus('#selection_status', "{{ lang._('No test server is configured. Review the Servers section or ask an administrator.') }}");
                    $('#server_setup_notice').prop('hidden', false);
                } else {
                    const detail = readableError(data?.error);
                    showStatus(serverStatus, "{{ lang._('Unable to load servers') }}" + (detail ? ': ' + detail : '.'), true);
                }
                return;
            }
            if (!data.length) {
                showStatus(serverStatus, "{{ lang._('No servers were returned. Check the server configuration and reload the list.') }}", true);
                return;
            }
            if (data.some(server => !server || typeof server.id !== 'string' || !/^[1-9][0-9]*$/.test(server.id)
                || typeof server.name !== 'string' || !server.name.trim())) {
                showStatus(serverStatus, "{{ lang._('The server list was invalid. Check the configuration and backend logs.') }}", true);
                return;
            }
            const selected = $('#serverid').val();
            configuredServers = new Map(data.map(server => [server.id, server.name]));
            $('#serverid').empty()
                .append($('<option/>').val('0').text("{{ lang._('Auto (lowest latency)') }}"))
                .append($('<option/>').val('-1').text("{{ lang._('Compare all servers') }}"))
                .append($('<option/>').val('custom').text("{{ lang._('Choose server IDs') }}"));
            data.forEach(server => $('#serverid').append($('<option/>').val(server.id).text('(' + server.id + ') ' + server.name)));
            const available = ['0', '-1', 'custom'].includes(selected) || configuredServers.has(selected);
            $('#serverid').val(available ? selected : '0');
            serversReady = true;
            showStatus(serverStatus, !available && selected
                ? "{{ lang._('The selected server is no longer listed. Selection reset to Auto.') }}" : '');
        }, serverStatus).always(function() {
            serversLoading = false;
            updateControls();
        });
    }
    function finishDetection(message, error = false) {
        detecting = false;
        if (error) {
            $('#detected_server').text('');
        }
        showStatus('#detection_status', message, error);
        updateControls();
    }
    function followDetection(expected, queued, generation) {
        request('detectionstatus', {}, function(state) {
            if (generation !== detectionGeneration) return;
            if (!['idle', 'running', 'busy', 'completed', 'failed'].includes(state?.status)) {
                finishDetection(readableError(state?.error) || "{{ lang._('Could not read the scan status. Try again.') }}", true);
                return;
            }
            if (state.run_id !== expected || state.status === 'idle' || state.status === 'busy') {
                if (Date.now() - queued < 15000) {
                    detectionTimer = setTimeout(() => followDetection(expected, queued, generation), 1500);
                } else {
                    finishDetection("{{ lang._('The scan did not start or the engine is busy. Try again when idle.') }}", true);
                }
                return;
            }
            if (state.status === 'running') {
                if (!Number.isFinite(state.deadline) || Date.now() / 1000 > state.deadline + 30) {
                    finishDetection("{{ lang._('The scan timed out. Check backend logs before retrying.') }}", true);
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
                    || "{{ lang._('No server responded. Check the configured servers and try again.') }}", true);
                return;
            }
            const serverId = String(result.serverid);
            if (!configuredServers.has(serverId)) {
                finishDetection("{{ lang._('The scan returned a server not in the current list. Reload the list and try again.') }}", true);
                return;
            }
            $('#serverid').val(serverId);
            $('#custom_servers').val('');
            $('#detected_server').text('(' + result.serverid + ') ' + result.servername);
            $('#preview_note').prop('hidden', false);
            renderDetails('#preview_details', connectionDetails(result));
            const jitter = Number.isFinite(result.jitter) && result.jitter >= 0
                ? ' · ' + "{{ lang._('Jitter') }}: " + number(result.jitter, ' ms') : '';
            finishDetection("{{ lang._('Detected latency') }}: " + number(result.latency, ' ms') + jitter);
        }, '#detection_status').fail(function() {
            if (generation !== detectionGeneration) return;
            finishDetection("{{ lang._('Connection lost. The scan may still be running.') }}", true);
        });
    }
    function detectServer() {
        if (!canRun || detecting || running || starting || saving
            || !statusReady || !defaultsReady || !engineReady || !serversReady) return;
        if (!$('#measurement_options_form')[0].reportValidity()) return;
        clearPreview();
        detecting = true;
        const generation = ++detectionGeneration;
        $('#server_preview').prop('hidden', false);
        showStatus('#detection_status', "{{ lang._('Checking latency. No download or upload test is running.') }}");
        updateControls();
        request('detect', currentOptions(), function(data) {
            if (generation !== detectionGeneration) return;
            if (data?.result !== 'started' || !/^[a-f0-9]{32}$/.test(data.run_id || '')) {
                finishDetection(readableError(data?.error) || "{{ lang._('Unable to start the scan. Try again.') }}", true);
                return;
            }
            followDetection(data.run_id, Date.now(), generation);
        }, '#detection_status').fail(function() {
            if (generation === detectionGeneration) {
                finishDetection("{{ lang._('Scan response lost. The scan may still be running.') }}", true);
            }
        });
    }
    function number(value, suffix = '') {
        return value === undefined || value === null ? "{{ lang._('Not measured') }}"
            : Number(value).toLocaleString(undefined, {maximumFractionDigits: 2}) + suffix;
    }
    function speedScale(mbps) {
        const preferred = $('#speed_units').val();
        const unit = Object.hasOwn(speedDivisors, preferred) ? preferred
            : mbps >= 1000000 ? 'Tbps' : mbps >= 1000 ? 'Gbps'
            : mbps >= 1 || mbps === 0 ? 'Mbps' : mbps >= 0.001 ? 'kbps' : 'bps';
        return {unit, divisor: speedDivisors[unit]};
    }
    function speed(value) {
        if (value == null) return number(null);
        const {unit, divisor} = speedScale(value);
        const displayed = value / divisor;
        return displayed > 0 && displayed < 0.01 ? '<' + number(0.01, ' ' + unit) : number(displayed, ' ' + unit);
    }
    function metricValue(key, value) {
        return ['download', 'upload'].includes(key) ? speed(value) : number(value, ' ms');
    }
    function byteSize(value) {
        if (!Number.isFinite(value) || value < 0) return '';
        const power = value < 1024 ? 0 : Math.min(4, Math.floor(Math.log2(value) / 10));
        return number(value / 1024 ** power, ' ' + ['B', 'KiB', 'MiB', 'GiB', 'TiB'][power]);
    }
    function connectionDetails(result) {
        return [
            ["{{ lang._('Server sponsor') }}", result?.sponsor],
            ["{{ lang._('Firewall IP seen by server') }}", result?.connection?.ip],
            ["{{ lang._('ISP / network') }}", result?.connection?.isp]
        ];
    }
    function transferDetails(result) {
        return [
            ["{{ lang._('Received') }}", byteSize(result?.bytes_received)],
            ["{{ lang._('Sent') }}", byteSize(result?.bytes_sent)],
            ["{{ lang._('Probe TLS') }}", [result?.tls?.version, result?.tls?.cipher].filter(Boolean).join(' / ')]
        ];
    }
    function fillDetails(list, fields) {
        list.empty();
        const entries = fields.filter(([, value]) => typeof value === 'string' && value.trim());
        entries.forEach(([label, value]) => list.append($('<div/>').append($('<dt/>').text(label)).append($('<dd/>').text(value))));
        return entries.length > 0;
    }
    function renderDetails(selector, fields) {
        const present = fillDetails($(selector + ' dl'), fields);
        $(selector).prop('open', false).prop('hidden', !present);
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
        $('#' + key + '_scale').text(measured ? speed(maximum) : '');
    }
    function renderMetrics(result, live = false) {
        let hasMeasurements = false;
        Object.keys(metricNames).forEach(key => {
            const value = result?.[key];
            const measured = Number.isFinite(value) && value >= 0;
            hasMeasurements ||= measured;
            $('#' + key + '_metric').prop('hidden', !measured);
            $('#' + key).text(metricValue(key, measured ? value : null));
            if (['download', 'upload'].includes(key)) renderGauge(key, value, live);
        });
        $('#test_metrics').prop('hidden', !hasMeasurements);
    }
    function renderResults(results, failed = false) {
        lastReadout = {results, failed};
        const comparison = results.length > 1;
        const result = !comparison && !results[0]?.error ? results[0] : null;
        renderMetrics(result);
        $('#readout_heading').text(comparison ? "{{ lang._('Comparison results') }}" : "{{ lang._('Latest result') }}");
        $('#readout_hint').text(failed ? "{{ lang._('No measurements from the last test.') }}" : "{{ lang._('No results yet.') }}")
            .prop('hidden', !!result || comparison);
        $('#result_meta').prop('hidden', !result);
        $('#test_server').text(result?.servername || '');
        const timestamp = new Date(result?.timestamp);
        const hasTime = Number.isFinite(timestamp.getTime());
        if (hasTime) {
            $('#result_time').attr('datetime', timestamp.toISOString()).text(timestamp.toLocaleString());
        } else {
            $('#result_time').removeAttr('datetime').text('');
        }
        $('#result_time').prop('hidden', !hasTime);
        renderDetails('#result_details', [...connectionDetails(result), ...transferDetails(result)]);
        $('#comparison').prop('hidden', !comparison);
        const rows = $('#comparison_rows').empty();
        if (!comparison) return;
        results.forEach(item => {
            const row = $('<tr/>');
            [item.servername, speed(item.download), speed(item.upload), number(item.latency, ' ms'), number(item.jitter, ' ms'),
                item.error ? "{{ lang._('Failed') }}: " + readableError(item.error) : "{{ lang._('Saved') }}"]
                .forEach(value => row.append($('<td/>').text(value)));
            rows.append(row);
        });
    }
    function renderLive(state) {
        const samples = {};
        ['download', 'upload'].forEach(key => {
            const points = state?.status === 'running' ? state.samples?.[key] : null;
            samples[key] = Array.isArray(points) ? points.filter(point => point
                && Number.isFinite(point.seconds) && point.seconds >= 0
                && Number.isFinite(point.mbps) && point.mbps >= 0) : [];
        });
        if (state?.status === 'running') {
            if (!['download', 'upload'].includes(state.phase)) {
                $('#phase_progress').removeAttr('value');
            } else {
                $('#phase_progress').val(Math.max(0, Math.min(100, Number(state.progress) || 0)));
            }
            $('#readout_heading').text("{{ lang._('Test in progress') }}");
            $('#readout_hint').prop('hidden', true);
            renderMetrics({download: samples.download.at(-1)?.mbps, upload: samples.upload.at(-1)?.mbps}, true);
        }
        const hasSamples = samples.download.length || samples.upload.length;
        $('#live_chart_region').prop('hidden', !hasSamples);
        if (!hasSamples) {
            $('#live_chart_region').prop('open', false);
            if (liveChart) liveChart.destroy();
            liveChart = null;
            return;
        }
        const direction = ['download', 'upload'].includes(state.phase) ? state.phase
            : samples.upload.length ? 'upload' : 'download';
        const point = samples[direction].at(-1);
        $('#live_speed').text(point ? metricNames[direction] + ': ' + speed(point.mbps)
            : "{{ lang._('Waiting for the first speed sample.') }}");
        if (typeof Chart !== 'function') {
            $('#live_plot').prop('hidden', true);
            showStatus('#live_chart_status', "{{ lang._('Live chart unavailable. Progress and the latest speed remain visible.') }}", true);
            return;
        }
        $('#live_plot').prop('hidden', false);
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
        if (!data.series.length) return;
        if (typeof Chart !== 'function') {
            $('#trend_charts').prop('hidden', true);
            showStatus('#history_status', "{{ lang._('Charts could not load. The history table remains available; check that core chart assets are installed.') }}", true);
            return;
        }
        const color = getComputedStyle(document.body).color;
        [['throughput_chart', ['download', 'upload']], ['latency_chart', ['latency', 'jitter']]].forEach(([id, keys]) => {
            const available = keys.some(key => data.series.some(point => Number.isFinite(point[key])));
            $('#' + id + '_group').prop('hidden', !available);
            if (!available) return;
            const {unit, divisor} = id === 'throughput_chart'
                ? speedScale(Math.max(0, ...data.series.map(point => Math.max(point.download ?? 0, point.upload ?? 0))))
                : {unit: 'ms', divisor: 1};
            charts.push(new Chart(document.getElementById(id), {
                type: 'line',
                data: {datasets: keys.map((key, index) => ({
                    label: metricNames[key],
                    data: data.series.map(point => ({x: point.epoch * 1000, y: Number.isFinite(point[key]) ? point[key] / divisor : null})),
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
            const server = $('<td/>').text(item.servername);
            const list = $('<dl/>').addClass('speedtest-result-details');
            if (fillDetails(list, [
                ["{{ lang._('Server ID') }}", String(item.serverid)], ["{{ lang._('Engine') }}", item.engine],
                ["{{ lang._('Source IP') }}", item.options?.source], ["{{ lang._('IP family setting') }}", item.options?.family],
                ...transferDetails(item)
            ])) {
                server.append($('<details/>').addClass('speedtest-disclosure')
                    .append($('<summary/>').text("{{ lang._('Details') }}")).append($('<div/>').append(list)));
            }
            row.append(server).append($('<td/>').text(modeNames[item.mode] || item.mode));
            Object.keys(metricNames).forEach(key => row.append($('<td/>').addClass('numeric').text(metricValue(key, item[key]))));
            row.append($('<td/>').text((originNames[item.origin] || item.origin) + ' / '
                + (item.error ? "{{ lang._('Failed') }}: " + readableError(item.error) : "{{ lang._('Successful') }}")));
            rows.append(row);
        });
        const metrics = $('#history_metrics').empty();
        Object.entries(data.metrics).forEach(([key, value]) => {
            if (!Number.isFinite(value.avg)) return;
            const row = $('<tr/>').append($('<th/>').attr('scope', 'row').text(metricNames[key]));
            ['avg', 'min', 'max'].forEach(kind => row.append($('<td/>').addClass('numeric').text(metricValue(key, value[kind]))));
            metrics.append(row);
        });
        const transferred = data.bytes_received + data.bytes_sent;
        $('#history_summary').text("{{ lang._('Successful') }}: " + data.successful + ' · '
            + "{{ lang._('Failed') }}: " + data.failed + (transferred > 0
                ? ' · ' + "{{ lang._('Recorded transfer') }}: " + byteSize(transferred) : ''));
        $('#history_results').prop('hidden', !data.rows.length);
        $('#history_trends').prop('hidden', !data.series.length);
        $('#chart_note').text("{{ lang._('Chart bucket (UTC days)') }}: " + data.bucket_days);
        populateFilter('#history_server', data.servers, "{{ lang._('All servers') }}");
        populateFilter('#history_source', Object.fromEntries(data.sources.map(source => [source, source])), "{{ lang._('All sources') }}");
        $('#history_pagination').prop('hidden', historyPage === 1 && data.total <= data.limit);
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
        const current = Object.fromEntries(Object.keys(historyDefaults).map(key => [key, $('#history_' + key).val()]));
        const {outcome, source, ...filters} = current;
        $('#reset_history_filters').prop('hidden', !differs(current, historyDefaults));
        $('#history_results').prop('hidden', true);
        showStatus('#history_status', "{{ lang._('Loading history...') }}");
        $('#history_previous, #history_next').prop('disabled', true);
        $.ajax({url: api + 'history', type: 'POST', data: {page: historyPage, ...filters, status: outcome, source: source === 'all' ? '' : source},
            dataType: 'json', timeout: 30000})
            .done(function(data) {
                if (generation !== historyGeneration) return;
                if (!Array.isArray(data?.rows) || !Array.isArray(data?.series) || !data.metrics) {
                    showStatus('#history_status', readableError(data?.error) || "{{ lang._('Unable to load history') }}", true);
                    return;
                }
                if (historyPage > 1 && !data.rows.length) {
                    historyPage = 1;
                    historyReload();
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
        if (lastStatusKey === null) $('#readout_hint').text("{{ lang._('The latest result is unavailable until status can be checked.') }}");
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
                running = true;
                updateControls();
                $('#run_progress').prop('hidden', true);
                renderLive(null);
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
            running = state.status === 'running';
            if (running && (!wasRunning || finishedOtherOperation)) renderResults([]);
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
                showStatus('#test_status', '');
                if (Date.now() / 1000 > state.deadline + 30) {
                    statusProblem("{{ lang._('The test exceeded its expected deadline. Check backend logs; a lock may still be held.') }}");
                    return;
                }
                pollTimer = setTimeout(() => followStatus(state.run_id, queued, generation), 1500);
            } else if (state.status !== 'idle') {
                renderResults(state.results || [], state.status === 'failed');
                const failure = readableError(state.error);
                const message = state.status === 'failed'
                    ? failure || "{{ lang._('The test failed. Check backend logs.') }}"
                    : expected ? "{{ lang._('Test complete. Result saved to history.') }}" : '';
                showStatus('#test_status', message, state.status === 'failed');
                historyLoaded = false;
                if ($('#history').hasClass('active')) historyReload();
            } else {
                renderResults([]);
                showStatus('#test_status', wasRunning ? "{{ lang._('No test is currently running.') }}" : '');
            }
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
    function scheduleDraft() {
        if (!$('#schedule_enabled').prop('checked')) return {...savedSchedule, enabled: '0'};
        const draft = {enabled: '1'};
        scheduleFields.forEach(key => draft[key] = $('#schedule_' + key).val());
        if (draft.cadence === 'hourly') draft.hour = savedSchedule.hour;
        if (draft.cadence !== 'weekly') draft.weekday = savedSchedule.weekday;
        const selection = $('#schedule_selection').val();
        draft.server = selection === 'custom' ? $('#schedule_server').val() : selection;
        return draft;
    }
    function scheduleChanged() {
        return !!savedSchedule && differs(scheduleDraft(), savedSchedule);
    }
    function fillSchedule(schedule) {
        scheduleFields.forEach(key => $('#schedule_' + key).val(schedule[key]));
        const custom = !['0', '-1'].includes(schedule.server);
        $('#schedule_selection').val(custom ? 'custom' : schedule.server);
        $('#schedule_server').val(custom ? schedule.server : '');
        $('#schedule_enabled').prop('checked', schedule.enabled === '1');
        schedulePreview();
    }
    function schedulePreview() {
        if (!scheduleReady) return;
        const enabled = $('#schedule_enabled').prop('checked');
        const cadence = $('#schedule_cadence').val();
        const custom = $('#schedule_selection').val() === 'custom';
        $('#schedule_options').prop('hidden', !enabled).prop('disabled', !enabled);
        $('#schedule_hour').prop('disabled', cadence === 'hourly');
        $('#schedule_hour_field').prop('hidden', cadence === 'hourly');
        $('#schedule_weekday').prop('disabled', cadence !== 'weekly');
        $('#schedule_weekday_field').prop('hidden', cadence !== 'weekly');
        $('#schedule_server').prop('disabled', !custom);
        $('#schedule_server_field').prop('hidden', !custom);
        $('#save_schedule').prop('disabled', !scheduleChanged());
        $('#discard_schedule').prop('hidden', !scheduleChanged());
        const hour = $('#schedule_hour').val(), minute = $('#schedule_minute').val();
        const timeReady = minute !== '' && Number(minute) >= 0 && Number(minute) < 60
            && (cadence === 'hourly' || hour !== '' && Number(hour) >= 0 && Number(hour) < 24);
        const time = cadence === 'hourly' ? "{{ lang._('Every hour at minute') }} " + minute.padStart(2, '0')
            : "{{ lang._('Time on the firewall') }}: " + hour.padStart(2, '0') + ':' + minute.padStart(2, '0');
        $('#schedule_preview').text(!enabled ? (savedSchedule.enabled === '1'
            ? "{{ lang._('Save to turn off scheduled tests.') }}" : "{{ lang._('Scheduled tests are off.') }}") : timeReady ? time : '');
        updateControls();
    }
    function fillServerSettings() {
        $('#servers_json').val(savedSettings.servers);
        publicSelection = savedSettings.public_selection;
        $('#combine_servers').prop('checked', savedSettings.combine_servers === '1');
        renderCustomServers();
        renderCatalog();
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
        function openSettings(group) {
            $(group).prop('open', true);
            $('#setup_tab').tab('show');
        }
        if (canRun || canConfigure) {
            $('#open_test_settings').on('click', function(event) {
                event.preventDefault();
                openSettings('#measurement_options');
                $('#measurement_settings_heading').trigger('focus');
            });
            $('#measurement_options_form')[0].addEventListener('invalid', () => openSettings('#measurement_options'), true);
            if (canRun) $('#custom_servers')[0].addEventListener('invalid', () => openSettings('#measurement_options'));
            $('#measurement_options_form').on('submit', event => event.preventDefault()).on('input change', function(event) {
                if (event?.target?.id !== 'mode') {
                    clearPreview();
                    showStatus('#settings_status', '');
                }
                updateControls();
            });
            $('#reset_measurement, #restore_measurement').on('click', function() {
                if (running || starting || saving || detecting || !defaultsReady) return;
                const reset = this.id === 'reset_measurement';
                fillMeasurementOptions(reset ? recommendedOptions : savedSettings);
                $('#measurement_options_form').trigger('change');
                if (!reset) $('#reset_measurement').trigger('focus');
            });
            request('defaults', {}, function(data) {
                if (!data || data.error) {
                    showStatus('#run_defaults_status, #settings_status', readableError(data?.error)
                        || "{{ lang._('Unable to load saved defaults. Reload the page to retry.') }}", true);
                    return;
                }
                fillMeasurementOptions({...recommendedOptions, ...data});
                Object.assign(savedSettings, currentOptions());
                for (const key of Object.keys(recommendedRetention)) {
                    savedSettings[key] = data[key] ?? recommendedRetention[key];
                    $('#' + key).val(savedSettings[key]);
                }
                savedPublicServers = data.public_servers === '1';
                savedSettings.public_servers = savedPublicServers ? '1' : '0';
                $('#public_servers').prop('checked', savedPublicServers);
                defaultsReady = true;
                if (canConfigure) renderCatalog();
                else updateControls();
                if ($('#catalog_panel').prop('open') && !catalogReceived) refreshCatalog();
            }, '#run_defaults_status, #settings_status');
        }
        $('#check_status').on('click', function() {
            if (starting || detecting || statusRetrying) return;
            statusRetrying = true;
            showStatus('#test_status', "{{ lang._('Checking test status...') }}");
            updateControls();
            followStatus();
        });
        $(window).on('pagehide', function() {
            ++pollGeneration;
            ++detectionGeneration;
            clearTimeout(pollTimer);
            clearTimeout(detectionTimer);
        });
        $(window).on('pageshow', function(event) {
            if (!event.originalEvent?.persisted) return;
            clearPreview();
            detecting = false;
            statusReady = false;
            statusRetrying = statusNeedsAttention;
            updateControls();
            followStatus();
        });
        $(document).on('visibilitychange', function() {
            if (!document.hidden && statusReady && !running && !starting && !detecting && !saving && !statusNeedsAttention) followStatus();
        });
        followStatus();
        if (canSchedule) {
            request('/api/speedtest/schedule/get', {}, function(data) {
                if (!data?.schedule || data.error) {
                    showStatus('#schedule_status', readableError(data?.error) || "{{ lang._('Unable to load the schedule. Reload before saving.') }}", true);
                    return;
                }
                const schedule = data.schedule;
                savedSchedule = Object.fromEntries(['enabled', 'server', ...scheduleFields].map(key => [key, schedule[key]]));
                scheduleReady = true;
                fillSchedule(savedSchedule);
                $('#schedule_timezone').text("{{ lang._('Firewall timezone') }}: " + (schedule.timezone || "{{ lang._('System default') }}"));
                $('#schedule_conflicts').text(schedule.other_jobs
                    ? "{{ lang._('Other speedtest jobs are enabled. Disable them in OPNsense cron before enabling this schedule.') }}" : '');
            }, '#schedule_status');
            $('#schedule_form').on('input change', function() {
                schedulePreview();
                showStatus('#schedule_status', '');
            });
            $('#schedule_selection').on('change', function() {
                if ($('#schedule_selection').val() !== 'custom') $('#schedule_server').val('');
            });
            $('#discard_schedule').on('click', function() {
                if (!scheduleReady || running || starting || saving || detecting) return;
                fillSchedule(savedSchedule);
                showStatus('#schedule_status', '');
                $('#schedule_enabled').trigger('focus');
            });
            $('#schedule_form').on('submit', function(event) {
                event.preventDefault();
                if (!scheduleReady || running || starting || saving || detecting || !this.reportValidity() || !scheduleChanged()) return;
                const schedule = scheduleDraft();
                saving = true;
                updateControls();
                request('/api/speedtest/schedule/set', {schedule: schedule}, function(data) {
                    if (data?.result === 'saved' || data?.saved === true) {
                        savedSchedule = schedule;
                        fillSchedule(savedSchedule);
                    }
                    if (data?.saved === true) $('#schedule_recovery').prop('open', true);
                    showStatus('#schedule_status', data?.result === 'saved'
                        ? "{{ lang._('Schedule saved and applied.') }}"
                        : readableError(data?.error) || Object.values(data?.validations || {}).join(' ')
                            || "{{ lang._('Could not save the schedule. Check the options and try again.') }}", data?.result !== 'saved');
                }, '#schedule_status').always(function() { saving = false; schedulePreview(); });
            });
            $('#apply_schedule').on('click', function() {
                if (!scheduleReady || scheduleChanged() || running || starting || saving || detecting) return;
                saving = true;
                updateControls();
                request('/api/speedtest/schedule/apply', {}, function(data) {
                    showStatus('#schedule_status', readableError(data?.error) || (data?.result === 'saved'
                        ? "{{ lang._('Saved schedule applied.') }}" : "{{ lang._('Unable to apply cron. Check backend logs.') }}"), data?.result !== 'saved');
                }, '#schedule_status').always(function() { saving = false; schedulePreview(); });
            });
        }
        updateControls();
        if (canConfigure) {
            $('#open_server_setup').on('click', function(event) {
                event.preventDefault();
                openSettings('#server_options');
                $('#server_settings_heading').trigger('focus');
            });
            $('#retention_form')[0].addEventListener('invalid', () => openSettings('#retention_options'), true);
            $('#retention_form').on('submit', event => event.preventDefault()).on('input change', updateControls);
            $('#reset_retention').on('click', function() {
                if (running || starting || saving || detecting || !settingsReady || !defaultsReady) return;
                Object.entries(recommendedRetention).forEach(([key, value]) => $('#' + key).val(value));
                updateControls();
                showStatus('#settings_status', "{{ lang._('Recommended retention selected. Export history before saving shorter limits.') }}");
            });
            $('#discard_settings').on('click', function() {
                if (running || starting || saving || detecting || !settingsReady || !defaultsReady || serverEditIndex !== null) return;
                fillMeasurementOptions(savedSettings);
                Object.keys(recommendedRetention).forEach(key => $('#' + key).val(savedSettings[key]));
                $('#public_servers').prop('checked', savedPublicServers);
                fillServerSettings();
                clearPreview();
                showStatus('#settings_status', '');
                $('#setup_tab').trigger('focus');
            });
            $('#catalog_panel').on('toggle', function() {
                if ($('#catalog_panel').prop('open') && !catalogReceived) refreshCatalog();
            });
            $('#catalog_refresh').on('click', refreshCatalog);
            $('#catalog_allow_all').on('click', () => setPublicSelection('all'));
            $('#catalog_allow_none').on('click', () => setPublicSelection('none'));
            $('#public_servers').on('change', function() {
                renderCatalog();
                showStatus('#settings_status', '');
            });
            $('#combine_servers').on('change', updateControls);
            $('#catalog_search').on('input', renderCatalog);
            $('#servers_json').on('input', function() { renderCustomServers(); updateControls(); });
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
                const general = data?.speedtest?.general;
                if (typeof general?.servers !== 'string') {
                    showStatus('#settings_status', "{{ lang._('Unable to load server settings') }}", true);
                    return;
                }
                Object.assign(savedSettings, {servers: general.servers, public_selection: general.public_selection || 'all',
                    combine_servers: general.combine_servers === '1' ? '1' : '0'});
                settingsReady = true;
                fillServerSettings();
                if ($('#catalog_panel').prop('open') && !catalogReceived) refreshCatalog();
            }).fail(() => showStatus('#settings_status', "{{ lang._('Unable to load server settings') }}", true));
        }
        $('#save_settings').on('click', function() {
            if (running || starting || saving || detecting || !settingsReady || !defaultsReady || !canConfigure || serverEditIndex !== null) return;
            if (!$('#measurement_options_form')[0].reportValidity()) return;
            if (!$('#retention_form')[0].reportValidity()) return;
            const options = settingsOptions();
            if (!differs(options, savedSettings)) return;
            if (options.combine_servers === '1' && options.public_servers === '1') {
                const allowed = approvedPublicIds();
                if ((customServers() || []).some(server => catalog.some(official =>
                    allowed.includes(official.id) && (String(server.id) === official.id
                        || String(server.server ?? '').replace(/\/+$/, '') === official.server.replace(/\/+$/, ''))))) {
                    showStatus('#settings_status', "{{ lang._('Custom and allowed official servers share an ID or URL. Edit the custom entry or remove the official server from the allowed list before combining.') }}", true);
                    return;
                }
            }
            if (Object.keys(recommendedRetention).some(key => Number(options[key]) > 0
                && (!Number(savedSettings[key]) || Number(options[key]) < Number(savedSettings[key])))
                && !window.confirm("{{ lang._('Shorter retention will permanently prune old records after the next measurement. Export CSV and JSONL first. Save these limits?') }}")) return;
            saving = true;
            updateControls();
            $.ajax({url: '/api/speedtest/settings/set', type: 'POST', data: {speedtest: {general: options}}, dataType: 'json', timeout: 30000})
                .done(function(data) {
                    if (data?.result !== 'saved') {
                        showStatus('#settings_status', readableError(data?.error) || Object.values(data?.validations || {}).join(' ')
                            || "{{ lang._('Settings were not saved. Check the fields and try again.') }}", true);
                        return;
                    }
                    const serverChanges = ['public_servers', 'public_selection', 'combine_servers', 'servers']
                        .some(key => options[key] !== savedSettings[key]);
                    Object.assign(savedSettings, options);
                    savedPublicServers = options.public_servers === '1';
                    fillServerSettings();
                    showStatus('#settings_status', "{{ lang._('Settings saved.') }}");
                    if ($('#catalog_panel').prop('open') && !catalogReceived) refreshCatalog();
                    if (serverChanges) serversReload();
                }).fail(xhr => showStatus('#settings_status', xhr.responseJSON?.errorMessage || "{{ lang._('Unable to save settings; check permissions, server JSON, and backend logs.') }}", true))
                .always(function() {
                    saving = false;
                    updateControls();
                });
        });
        function engineUnavailable() {
            $('#version').text("{{ lang._('Unavailable') }}");
        }
        request('version', {}, function(data) {
            if (typeof data?.message !== 'string' || !data.message || data.error) {
                engineUnavailable();
                showStatus('#engine_status', readableError(data?.error)
                    || "{{ lang._('Measurement engine unavailable. See About Speedtest in Settings.') }}", true);
                updateControls();
                return;
            }
            const version = data.message.match(/^librespeed-cli\s+(v[^\s]+)(?:\s+\(built on 1970-01-01 00:00:00 UTC\))?$/i);
            $('#version').text(version ? version[1] : data.message);
            engineReady = true;
            updateControls();
            serversReload();
        }, '#engine_status').fail(engineUnavailable);
        $('#serverlistAct').on('click', function() {
            if (running || starting || saving || detecting || !engineReady) return;
            serversReload();
        });
        $('#serverid').on('change', function() {
            if ($('#serverid').val() !== 'custom') $('#custom_servers').val('');
            clearPreview();
            updateControls();
        });
        $('#custom_servers').on('input', updateControls);
        $('#detect_server').on('click', detectServer);
        $('#speed_units').on('change', function() {
            historyLoaded = false;
            if (lastReadout && !running && !starting) renderResults(lastReadout.results, lastReadout.failed);
        });
        $('#live_chart_region').on('toggle', () => liveChart?.resize());
        $('#history_trends').on('toggle', () => charts.forEach(chart => chart.resize()));
        $('a[href="#history"]').on('shown.bs.tab', function() {
            if (!historyLoaded) historyReload();
            charts.forEach(chart => chart.resize());
        });
        $('a[href="#measurement"]').on('shown.bs.tab', function() {
            if (liveChart) liveChart.resize();
        });
        $('#history_filters').on('submit', event => event.preventDefault()).on('change', function() { historyPage = 1; historyReload(); });
        $('#reset_history_filters').on('click', function() {
            Object.entries(historyDefaults).forEach(([key, value]) => $('#history_' + key).val(value));
            $('#history_more_filters').prop('open', false);
            $('#history_days').trigger('focus');
            historyPage = 1;
            historyReload();
        });
        $('#history_previous').on('click', function() { if (historyPage > 1) { historyPage--; historyReload(); } });
        $('#history_next').on('click', function() { if (historyPage < 200) { historyPage++; historyReload(); } });
        $('#refresh_history').on('click', historyReload);
        $('#test_form').on('submit', function(event) {
            event.preventDefault();
            if (!canRun || !engineReady || !serversReady || !defaultsReady || !statusReady || running || starting || saving || detecting || !this.reportValidity()
                || !$('#measurement_options_form')[0].reportValidity()) return;
            const selected = $('#serverid').val();
            if (selected === 'custom' && !$('#custom_servers')[0].reportValidity()) return;
            const options = currentOptions();
            const mode = $('#mode').val();
            const server = selected === 'custom' ? $('#custom_servers').val() : selected;
            if (selected !== '0' && selected !== '-1') options.exclude = '';
            ++pollGeneration;
            clearTimeout(pollTimer);
            starting = true;
            running = true;
            updateControls();
            clearPreview();
            showStatus('#test_status', "{{ lang._('Starting test...') }}");
            request('start/' + encodeURIComponent(server) + '/' + mode, options, function(data) {
                if (data?.result !== 'started' || !data.run_id) {
                    running = false;
                    updateControls();
                    showStatus('#test_status', readableError(data?.error) || "{{ lang._('Unable to start a test. Check backend logs.') }}", true);
                    scheduleStatusCheck(pollGeneration);
                    return;
                }
                renderResults([]);
                renderLive(null);
                $('#readout_heading').text("{{ lang._('Test in progress') }}");
                $('#readout_hint').text("{{ lang._('Waiting for measurement data.') }}");
                followStatus(data.run_id);
            }, '#test_status').fail(function() {
                statusProblem("{{ lang._('Start response lost. The test may have started; check its status before retrying.') }}");
            }).always(function() {
                starting = false;
                updateControls();
            });
        });
        $('#deletelogAct').on('click', function() {
            if (running || starting || saving || detecting || !window.confirm("{{ lang._('Permanently clear all speedtest history? Export CSV and JSONL first if you need a copy.') }}")) return;
            saving = true;
            updateControls();
            request('deletelog', {}, function(data) {
                if (!data || data.error || data.result !== 'ok') {
                    showStatus('#history_status', readableError(data?.error) || "{{ lang._('Unable to clear history') }}", true);
                    return;
                }
                renderResults([]);
                renderLive(null);
                clearPreview();
                showStatus('#test_status', '');
                historyPage = 1;
                historyReload();
            }, '#history_status').always(() => { saving = false; updateControls(); });
        });
    });
</script>
