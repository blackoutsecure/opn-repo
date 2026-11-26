{#
 * Copyright 2021 Miha Kralj
 * Copyright 2026
 * SPDX-License-Identifier: BSD-2-Clause
#}

<style>
    .opn-speedtest {
        --opn-speedtest-orange: #C03E14;
        --opn-speedtest-green: #9BD275;
        --opn-speedtest-blue: #31708f;
        --opn-speedtest-track: rgba(80, 80, 80, 0.22);
        --opn-speedtest-rule: rgba(110, 110, 110, 0.28);
    }
    .opn-speedtest-header {
        display: flex;
        align-items: center;
        gap: 1.25rem;
        padding: 0.5rem 0 1.25rem;
    }
    .opn-speedtest-mark {
        flex: 0 0 4.75rem;
        width: 4.75rem;
        height: 4.75rem;
    }
    .opn-speedtest-heading h2 {
        margin: 0 0 0.25rem;
    }
    .opn-speedtest-heading p {
        max-width: 70ch;
        margin: 0;
        color: inherit;
        opacity: 0.78;
    }
    .opn-speedtest-stats {
        display: grid;
        grid-template-columns: repeat(4, minmax(0, 1fr));
        margin-bottom: 1.25rem;
        border-top: 1px solid var(--opn-speedtest-rule);
        border-bottom: 1px solid var(--opn-speedtest-rule);
    }
    .opn-speedtest-stat {
        min-width: 0;
        padding: 1rem 1.25rem;
        border-right: 1px solid var(--opn-speedtest-rule);
    }
    .opn-speedtest-stat:last-child {
        border-right: 0;
    }
    .opn-speedtest-stat strong {
        display: block;
        overflow-wrap: anywhere;
        font-size: 1.35rem;
        font-variant-numeric: tabular-nums;
    }
    .opn-speedtest-stat span,
    .opn-speedtest-stat small {
        display: block;
        opacity: 0.72;
    }
    .opn-speedtest-stat span {
        margin-top: 0.2rem;
        font-weight: 600;
    }
    .opn-speedtest-controls {
        padding: 1.15rem;
    }
    .opn-speedtest-controls .form-control,
    .opn-speedtest-controls .btn {
        min-height: 34px;
    }
    .opn-source-badges {
        min-height: 1.9rem;
        margin-bottom: 0.75rem;
    }
    .opn-source-badge {
        display: inline-block;
        margin: 0 0.5rem 0.4rem 0;
    }
    .opn-gauge-panel {
        padding: 1.35rem 0.75rem 0.9rem;
        border-top: 1px solid var(--opn-speedtest-rule);
        border-bottom: 1px solid var(--opn-speedtest-rule);
    }
    .opn-gauge-grid {
        display: grid;
        grid-template-columns: repeat(3, minmax(0, 1fr));
    }
    .opn-gauge {
        min-width: 0;
        padding: 0 1.1rem;
        text-align: center;
        border-right: 1px solid var(--opn-speedtest-rule);
    }
    .opn-gauge:last-child {
        border-right: 0;
    }
    .opn-gauge svg {
        display: block;
        width: 100%;
        max-width: 15rem;
        height: auto;
        margin: 0 auto;
        overflow: visible;
    }
    .opn-gauge-track,
    .opn-gauge-arc {
        fill: none;
        stroke-width: 12;
        stroke-linecap: round;
    }
    .opn-gauge-track {
        stroke: var(--opn-speedtest-track);
    }
    .opn-gauge-arc {
        stroke: var(--opn-speedtest-orange);
        stroke-dasharray: 0 100;
        transition: stroke-dasharray 320ms ease-out;
    }
    .opn-gauge[data-gauge="upload"] .opn-gauge-arc {
        stroke: var(--opn-speedtest-green);
    }
    .opn-gauge[data-gauge="latency"] .opn-gauge-arc {
        stroke: var(--opn-speedtest-blue);
    }
    .opn-gauge-value {
        fill: currentColor;
        font-size: 2.3rem;
        font-weight: 700;
        font-variant-numeric: tabular-nums;
    }
    .opn-gauge-unit {
        fill: currentColor;
        font-size: 0.9rem;
        opacity: 0.68;
    }
    .opn-gauge-name {
        margin-top: -0.55rem;
        font-size: 1rem;
        font-weight: 600;
    }
    .opn-gauge-detail {
        margin-top: 0.2rem;
        opacity: 0.7;
    }
    .opn-speedtest-running .opn-gauge-arc {
        animation: opn-speedtest-pulse 900ms ease-in-out infinite alternate;
    }
    @keyframes opn-speedtest-pulse {
        from { opacity: 0.35; }
        to { opacity: 1; }
    }
    @media (prefers-reduced-motion: reduce) {
        .opn-speedtest-running .opn-gauge-arc {
            animation: none;
        }
        .opn-gauge-arc {
            transition: none;
        }
    }
    .opn-result-details {
        margin: 0;
    }
    .opn-result-details dt {
        clear: left;
        float: left;
        width: 12rem;
        margin: 0;
        padding: 0.45rem 0.75rem 0.45rem 0;
        text-align: left;
    }
    .opn-result-details dd {
        margin: 0;
        padding: 0.45rem 0;
        overflow-wrap: anywhere;
    }
    #speedtest-selection-probes {
        max-height: 11rem;
        overflow: auto;
    }
    .opn-history {
        padding: 1rem 1.25rem 0.5rem;
    }
    .opn-history-heading {
        display: flex;
        align-items: baseline;
        justify-content: space-between;
        gap: 1rem;
        margin-bottom: 0.35rem;
    }
    .opn-history svg {
        display: block;
        width: 100%;
        height: 11rem;
    }
    .opn-history-grid {
        stroke: var(--opn-speedtest-rule);
        stroke-width: 1;
    }
    .opn-history-line {
        fill: none;
        stroke-width: 3;
        stroke-linecap: round;
        stroke-linejoin: round;
    }
    #opn-history-download {
        stroke: var(--opn-speedtest-orange);
    }
    #opn-history-upload {
        stroke: var(--opn-speedtest-green);
    }
    .opn-history-label {
        fill: currentColor;
        font-size: 12px;
        opacity: 0.64;
    }
    .opn-history-legend span {
        display: inline-flex;
        align-items: center;
        margin-right: 1rem;
    }
    .opn-history-legend i {
        width: 1.5rem;
        height: 0.22rem;
        margin-right: 0.4rem;
        background: var(--opn-speedtest-orange);
    }
    .opn-history-legend .upload {
        background: var(--opn-speedtest-green);
    }
    .opn-engine-status {
        display: grid;
        grid-template-columns: 13rem minmax(0, 1fr);
        gap: 0.65rem 1rem;
        padding: 0.8rem 0;
        border-top: 1px solid var(--opn-speedtest-rule);
    }
    .opn-engine-status:first-of-type {
        border-top: 0;
    }
    .opn-engine-actions {
        display: flex;
        flex-wrap: wrap;
        gap: 0.6rem;
        margin-top: 0.9rem;
    }
    @media (max-width: 767px) {
        .opn-speedtest-header {
            align-items: flex-start;
        }
        .opn-speedtest-mark {
            flex-basis: 3.8rem;
            width: 3.8rem;
            height: 3.8rem;
        }
        .opn-speedtest-stats {
            grid-template-columns: repeat(2, minmax(0, 1fr));
        }
        .opn-speedtest-stat:nth-child(2) {
            border-right: 0;
        }
        .opn-speedtest-stat:nth-child(-n+2) {
            border-bottom: 1px solid var(--opn-speedtest-rule);
        }
        .opn-gauge-grid {
            grid-template-columns: 1fr;
        }
        .opn-gauge {
            padding: 0.5rem 0;
            border-right: 0;
            border-bottom: 1px solid var(--opn-speedtest-rule);
        }
        .opn-gauge:last-child {
            border-bottom: 0;
        }
        .opn-result-details dt {
            width: 9rem;
        }
        .opn-history-heading {
            align-items: flex-start;
            flex-direction: column;
        }
    }
</style>

<div class="opn-speedtest">
    <div class="opn-speedtest-header">
        <svg class="opn-speedtest-mark" viewBox="0 0 96 96" role="img"
             aria-label="{{ lang._('Speedtest measurement mark') }}">
            <path d="M48 6 82 19v27c0 21-13 35-34 44C27 81 14 67 14 46V19L48 6Z"
                  fill="none" stroke="#C03E14" stroke-width="6" stroke-linejoin="round"/>
            <path d="M25 54h12l7-15 9 27 7-15h11"
                  fill="none" stroke="#9BD275" stroke-width="5"
                  stroke-linecap="round" stroke-linejoin="round"/>
            <path d="M28 34h40" stroke="currentColor" stroke-opacity=".28"
                  stroke-width="3" stroke-linecap="round"/>
        </svg>
        <div class="opn-speedtest-heading">
            <h2>{{ lang._('Speedtest') }}</h2>
            <p>
                {{ lang._('Measure WAN throughput, latency, and target health using the enabled measurement networks and your own custom targets.') }}
            </p>
        </div>
    </div>

    <ul class="nav nav-tabs" data-tabs="tabs" id="speedtest-tabs">
        <li class="active"><a data-toggle="tab" href="#speedtest-run">{{ lang._('Measure') }}</a></li>
        <li><a data-toggle="tab" href="#speedtest-settings">{{ lang._('Sources and targets') }}</a></li>
    </ul>

    <div class="tab-content content-box">
        <div class="tab-pane fade in active" id="speedtest-run">
            <div class="opn-speedtest-stats" role="list"
                 aria-label="{{ lang._('Speedtest history') }}">
                <div class="opn-speedtest-stat" role="listitem">
                    <strong id="stat_samples">0</strong>
                    <span>{{ lang._('Measurements') }}</span>
                    <small>{{ lang._('saved in local history') }}</small>
                </div>
                <div class="opn-speedtest-stat" role="listitem">
                    <strong id="stat_download">0 Mbps</strong>
                    <span>{{ lang._('Average download') }}</span>
                    <small id="stat_download_range">min 0 / max 0 Mbps</small>
                </div>
                <div class="opn-speedtest-stat" role="listitem">
                    <strong id="stat_upload">0 Mbps</strong>
                    <span>{{ lang._('Average upload') }}</span>
                    <small id="stat_upload_range">min 0 / max 0 Mbps</small>
                </div>
                <div class="opn-speedtest-stat" role="listitem">
                    <strong id="stat_latency">0 ms</strong>
                    <span>{{ lang._('Average latency') }}</span>
                    <small id="stat_latency_range">min 0 / max 0 ms</small>
                </div>
            </div>

            <div class="content-box opn-speedtest-controls" id="speedtest-results">
                <div class="alert alert-info" id="speedtest-provider-loading">
                    {{ lang._('Loading enabled measurement sources...') }}
                </div>
                <div id="speedtest-provider-badges" class="opn-source-badges"></div>
                <div class="row">
                    <div class="col-sm-5">
                        <label for="speedtest-provider">{{ lang._('Network source') }}</label>
                        <select id="speedtest-provider" class="form-control">
                            <option value="auto">{{ lang._('Auto - best target across enabled networks') }}</option>
                        </select>
                    </div>
                    <div class="col-sm-4">
                        <label for="speedtest-server">{{ lang._('Measurement target') }}</label>
                        <select id="speedtest-server" class="form-control">
                            <option value="auto">{{ lang._('Automatic best target') }}</option>
                        </select>
                    </div>
                    <div class="col-sm-3">
                        <label class="visible-xs">&nbsp;</label>
                        <div class="btn-group" style="display:flex; margin-top:0.1rem">
                            <button class="btn btn-default" id="serverlistAct" type="button"
                                    title="{{ lang._('Refresh available targets') }}">
                                <i class="fa fa-refresh"></i> {{ lang._('Refresh') }}
                                <i id="serverlistAct_progress"></i>
                            </button>
                            <button class="btn btn-primary" id="reportAct" type="button" disabled>
                                <i class="fa fa-play"></i> {{ lang._('Start') }}
                                <i id="reportAct_progress"></i>
                            </button>
                        </div>
                    </div>
                </div>

                <div class="alert alert-danger" id="speedtest-error" style="display:none; margin-top:1rem"></div>
                <div id="test_results" style="display:none">
                    <div class="opn-gauge-panel">
                        <div class="opn-gauge-grid">
                            <div class="opn-gauge" data-gauge="download"
                                 role="img" aria-label="{{ lang._('Download measurement') }}">
                                <svg viewBox="0 0 180 112" aria-hidden="true">
                                    <path class="opn-gauge-track"
                                          pathLength="100" d="M18 96A72 72 0 0 1 162 96"/>
                                    <path class="opn-gauge-arc" id="download-gauge-arc"
                                          pathLength="100" d="M18 96A72 72 0 0 1 162 96"/>
                                    <text x="90" y="75" text-anchor="middle"
                                          class="opn-gauge-value" id="dlspeed">0.0</text>
                                    <text x="90" y="96" text-anchor="middle"
                                          class="opn-gauge-unit">Mbps</text>
                                </svg>
                                <div class="opn-gauge-name">{{ lang._('Download') }}</div>
                                <div class="opn-gauge-detail" id="download-gauge-detail">{{ lang._('Ready') }}</div>
                            </div>
                            <div class="opn-gauge" data-gauge="upload"
                                 role="img" aria-label="{{ lang._('Upload measurement') }}">
                                <svg viewBox="0 0 180 112" aria-hidden="true">
                                    <path class="opn-gauge-track"
                                          pathLength="100" d="M18 96A72 72 0 0 1 162 96"/>
                                    <path class="opn-gauge-arc" id="upload-gauge-arc"
                                          pathLength="100" d="M18 96A72 72 0 0 1 162 96"/>
                                    <text x="90" y="75" text-anchor="middle"
                                          class="opn-gauge-value" id="ulspeed">0.0</text>
                                    <text x="90" y="96" text-anchor="middle"
                                          class="opn-gauge-unit">Mbps</text>
                                </svg>
                                <div class="opn-gauge-name">{{ lang._('Upload') }}</div>
                                <div class="opn-gauge-detail" id="upload-gauge-detail">{{ lang._('Ready') }}</div>
                            </div>
                            <div class="opn-gauge" data-gauge="latency"
                                 role="img" aria-label="{{ lang._('Latency measurement') }}">
                                <svg viewBox="0 0 180 112" aria-hidden="true">
                                    <path class="opn-gauge-track"
                                          pathLength="100" d="M18 96A72 72 0 0 1 162 96"/>
                                    <path class="opn-gauge-arc" id="latency-gauge-arc"
                                          pathLength="100" d="M18 96A72 72 0 0 1 162 96"/>
                                    <text x="90" y="75" text-anchor="middle"
                                          class="opn-gauge-value" id="latency">0.0</text>
                                    <text x="90" y="96" text-anchor="middle"
                                          class="opn-gauge-unit">ms</text>
                                </svg>
                                <div class="opn-gauge-name">{{ lang._('Latency') }}</div>
                                <div class="opn-gauge-detail" id="latency-gauge-detail">{{ lang._('Ready') }}</div>
                            </div>
                        </div>
                    </div>

                    <dl class="opn-result-details">
                        <dt>{{ lang._('Measurement source') }}</dt>
                        <dd>
                            <strong id="result_provider"></strong>
                            <span class="text-muted" id="result_engine"></span>
                        </dd>
                        <dt>{{ lang._('Selected target') }}</dt>
                        <dd id="result_server"></dd>
                        <dt>{{ lang._('Selection') }}</dt>
                        <dd>
                            <div id="result_selection"></div>
                            <small id="speedtest-selection-probes" class="text-muted"></small>
                        </dd>
                        <dt id="result_warnings_row" style="display:none">{{ lang._('Warnings') }}</dt>
                        <dd id="result_warnings" class="text-warning" style="display:none"></dd>
                        <dt>{{ lang._('External IP') }}</dt>
                        <dd id="client"></dd>
                        <dt>{{ lang._('Shareable result') }}</dt>
                        <dd id="result"></dd>
                    </dl>
                </div>
            </div>

            <div style="margin:0.75rem 0">
                <small id="version" class="text-muted"></small>
                <a href="/ui/cron" class="btn btn-xs btn-default pull-right">
                    {{ lang._('Schedule measurement') }}
                </a>
            </div>

            <div class="content-box" id="logs">
                <div class="opn-history">
                    <div class="opn-history-heading">
                        <div>
                            <strong>{{ lang._('Recent throughput') }}</strong>
                            <div class="help-block">{{ lang._('Last 20 completed measurements, newest at right') }}</div>
                        </div>
                        <div class="opn-history-legend">
                            <span><i></i>{{ lang._('Download') }}</span>
                            <span><i class="upload"></i>{{ lang._('Upload') }}</span>
                        </div>
                    </div>
                    <div id="speedtest-history-empty" class="help-block">
                        {{ lang._('No measurements have been recorded yet.') }}
                    </div>
                    <svg id="speedtest-history-chart" viewBox="0 0 720 150"
                         role="img" aria-label="{{ lang._('Recent download and upload throughput chart') }}"
                         style="display:none">
                        <line class="opn-history-grid" x1="46" x2="706" y1="24" y2="24"/>
                        <line class="opn-history-grid" x1="46" x2="706" y1="69" y2="69"/>
                        <line class="opn-history-grid" x1="46" x2="706" y1="114" y2="114"/>
                        <text class="opn-history-label" x="8" y="28" id="opn-history-max">0</text>
                        <text class="opn-history-label" x="8" y="73" id="opn-history-mid">0</text>
                        <text class="opn-history-label" x="8" y="118">0</text>
                        <polyline class="opn-history-line" id="opn-history-download" points=""/>
                        <polyline class="opn-history-line" id="opn-history-upload" points=""/>
                    </svg>
                </div>
                <table class="table table-condensed">
                    <thead>
                        <tr>
                            <th style="text-align:left" colspan="7">
                                <a href="#"><i class="fa fa-toggle-off text-danger" id="show_advanced_log"></i></a>
                                <small id="togglelog">{{ lang._('Show detailed history') }}</small>
                                <span class="pull-right">
                                    <a href="/api/speedtest/download/csv" class="btn btn-xs btn-primary">
                                        {{ lang._('Export CSV') }}
                                    </a>
                                    <button class="btn btn-xs btn-primary" id="deletelogAct" type="button">
                                        {{ lang._('Clear history') }} <i id="deletelogAct_progress"></i>
                                    </button>
                                </span>
                            </th>
                        </tr>
                        <tr id="log_head" class="speedtest-log-advanced" style="display:none">
                            <th>{{ lang._('Timestamp (GMT)') }}</th>
                            <th>{{ lang._('Source') }}</th>
                            <th>{{ lang._('Target') }}</th>
                            <th>{{ lang._('Download') }}</th>
                            <th>{{ lang._('Upload') }}</th>
                            <th>{{ lang._('Latency') }}</th>
                            <th>{{ lang._('Jitter') }}</th>
                        </tr>
                    </thead>
                    <tbody id="log_block" class="speedtest-log-advanced" style="display:none"></tbody>
                </table>
            </div>
        </div>

        <div class="tab-pane fade" id="speedtest-settings">
            <h2>{{ lang._('Measurement sources') }}</h2>
            <div class="content-box" style="padding-bottom:1.5rem">
                {{ partial("layout_partials/base_form", ['fields':generalForm, 'id':'frm_speedtest_settings']) }}
                <div class="col-md-12 __mt">
                    <button class="btn btn-primary" id="saveSettingsAct" type="button">
                        <b>{{ lang._('Save source settings') }}</b>
                        <i id="saveSettingsAct_progress"></i>
                    </button>
                </div>
            </div>

            <h2>{{ lang._('Native engines') }}</h2>
            <div class="content-box" style="padding:1rem">
                <div class="opn-engine-status">
                    <strong>{{ lang._('Public server CLI') }}</strong>
                    <span id="native-client-status" class="text-muted">{{ lang._('Checking...') }}</span>
                </div>
                <div class="opn-engine-status">
                    <strong>{{ lang._('Rust transfer engine') }}</strong>
                    <span id="rust-engine-status" class="text-muted">{{ lang._('Checking...') }}</span>
                </div>
                <div class="opn-engine-actions">
                    <button class="btn btn-default" id="binAct" type="button">
                        <b>{{ lang._('Install or update native CLI') }}</b>
                        <i id="binAct_progress"></i>
                    </button>
                    <button class="btn btn-default" id="rustAct" type="button">
                        <b>{{ lang._('Build optional Rust engine') }}</b>
                        <i id="rustAct_progress"></i>
                    </button>
                </div>
                <p class="help-block">
                    {{ lang._('The measurement core remains dependency-free by default. The optional Rust engine is pinned, kept only as a compiled binary, and removes the temporary build toolchain after installation.') }}
                </p>
            </div>

            <h2>{{ lang._('Measurement targets') }}</h2>
            <div class="alert alert-info">
                {{ lang._("Refresh imports each enabled network's public target list while preserving individual on/off choices. Custom targets remain in place during refresh.") }}
            </div>
            <div class="alert alert-warning" id="speedtest-refresh-status" style="display:none"></div>
            <div style="margin-bottom:0.75rem">
                <button class="btn btn-default" id="refreshServersAct" type="button">
                    <b>{{ lang._('Refresh public targets') }}</b>
                    <i id="refreshServersAct_progress"></i>
                </button>
            </div>
            <div class="content-box">
                {{ partial('layout_partials/base_bootgrid_table', serverGrid) }}
            </div>
        </div>
    </div>
</div>

{{ partial("layout_partials/base_dialog", [
    'fields':serverForm,
    'id':serverGrid['edit_dialog_id'],
    'label':lang._('Add or edit measurement target')
]) }}

<script>
    let speedtestServers = [];
    let speedtestProviders = [];
    let speedtestSettings = {};

    function speedtestFormat(value) {
        return value === null || value === undefined ? '' : String(value);
    }

    function speedtestNiceMaximum(value) {
        const numeric = Math.max(Number(value) || 0, 0);
        const minimum = 100;
        if (numeric <= minimum) {
            return minimum;
        }
        const magnitude = Math.pow(10, Math.floor(Math.log10(numeric)));
        return Math.ceil((numeric * 1.12) / (magnitude / 2)) * (magnitude / 2);
    }

    function speedtestSetGauge(kind, value, maximum) {
        const numeric = Math.max(Number(value) || 0, 0);
        const ceiling = Math.max(Number(maximum) || 1, 1);
        const amount = Math.min(100, numeric / ceiling * 100);
        $('#' + kind + '-gauge-arc').attr('stroke-dasharray', amount.toFixed(2) + ' 100');
        return amount;
    }

    function speedtestRenderHistory(rows) {
        const valid = (Array.isArray(rows) ? rows : [])
            .filter(function(row) {
                return Number.isFinite(parseFloat(row[5])) && Number.isFinite(parseFloat(row[6]));
            })
            .slice(0, 20)
            .reverse();
        if (!valid.length) {
            $('#speedtest-history-chart').hide();
            $('#speedtest-history-empty').show();
            return;
        }
        const downloads = valid.map(function(row) { return Math.max(0, parseFloat(row[5]) || 0); });
        const uploads = valid.map(function(row) { return Math.max(0, parseFloat(row[6]) || 0); });
        const maximum = speedtestNiceMaximum(Math.max.apply(Math, downloads.concat(uploads)));
        const left = 46;
        const right = 706;
        const top = 24;
        const bottom = 114;
        const points = function(values) {
            const coordinates = values.map(function(value, index) {
                const x = valid.length === 1 ? (left + right) / 2 :
                    left + (right - left) * index / (valid.length - 1);
                const y = bottom - (bottom - top) * Math.min(value / maximum, 1);
                return x.toFixed(2) + "," + y.toFixed(2);
            });
            return coordinates.length === 1
                ? coordinates[0] + " " + coordinates[0]
                : coordinates.join(" ");
        };
        $('#opn-history-download').attr('points', points(downloads));
        $('#opn-history-upload').attr('points', points(uploads));
        $('#opn-history-max').text(maximum.toFixed(maximum < 10 ? 1 : 0));
        $('#opn-history-mid').text((maximum / 2).toFixed(maximum < 10 ? 1 : 0));
        $('#speedtest-history-empty').hide();
        $('#speedtest-history-chart').show();
    }

    function speedtestStatReload() {
        ajaxCall(url = "/api/speedtest/service/showstat", sendData = {}, callback = function(l, status) {
            if (!l || l.error) {
                return;
            }
            $('#stat_samples').text(l.samples);
            $('#stat_latency').text(l.latency.avg + " ms");
            $('#stat_latency_range').text(
                "{{ lang._('min') }} " + l.latency.min + " / " +
                "{{ lang._('max') }} " + l.latency.max + " ms"
            );
            $('#stat_download').text(l.download.avg + " Mbps");
            $('#stat_download_range').text(
                "{{ lang._('min') }} " + l.download.min + " / " +
                "{{ lang._('max') }} " + l.download.max + " Mbps"
            );
            $('#stat_upload').text(l.upload.avg + " Mbps");
            $('#stat_upload_range').text(
                "{{ lang._('min') }} " + l.upload.min + " / " +
                "{{ lang._('max') }} " + l.upload.max + " Mbps"
            );
        });
    }

    function speedtestLogReload() {
        ajaxCall(url = "/api/speedtest/service/showlog", sendData = {}, callback = function(l, status) {
            const body = $('#log_block').empty();
            if (!Array.isArray(l)) {
                speedtestRenderHistory([]);
                return;
            }
            l.forEach(function(row) {
                $('<tr>')
                    .append($('<td>').text(speedtestFormat(row[0])))
                    .append($('<td>').text(speedtestFormat(row[9])))
                    .append($('<td>').text((speedtestFormat(row[2]) + " " + speedtestFormat(row[3])).trim()))
                    .append($('<td>').text(parseFloat(row[5] || 0).toFixed(2)))
                    .append($('<td>').text(parseFloat(row[6] || 0).toFixed(2)))
                    .append($('<td>').text(parseFloat(row[7] || 0).toFixed(2)))
                    .append($('<td>').text(parseFloat(row[10] || 0).toFixed(2)))
                    .appendTo(body);
            });
            speedtestRenderHistory(l);
        });
    }

    function speedtestRenderProviderStatus(data) {
        speedtestProviders = data && Array.isArray(data.providers) ? data.providers : [];
        const select = $('#speedtest-provider');
        select.find('option:not([value="auto"])').remove();
        $('#speedtest-provider-badges').empty();
        let available = 0;
        speedtestProviders.forEach(function(provider) {
            let css = "label-default";
            let suffix = "{{ lang._('disabled') }}";
            if (provider.enabled) {
                css = provider.available ? "label-success" : "label-danger";
                suffix = provider.available ? "{{ lang._('available') }}" : "{{ lang._('unavailable') }}";
                if (provider.available) {
                    available += 1;
                }
            }
            $('<span>')
                .addClass("label " + css + " opn-source-badge")
                .text(provider.label + ": " + suffix)
                .appendTo('#speedtest-provider-badges');
            $('<option>')
                .val(provider.id)
                .prop("disabled", !provider.enabled || !provider.available)
                .text(provider.label + (provider.available && provider.enabled ? "" : " (" + suffix + ")"))
                .appendTo(select);
            if (provider.id === "ookla") {
                $('#native-client-status').text(provider.message);
            }
            if (provider.id === "librespeed") {
                $('#rust-engine-status').text(
                    provider.client === "rust-native"
                        ? provider.message
                        : "{{ lang._('Not installed; dependency-free fallback is active.') }}"
                );
            }
        });
        $('#speedtest-provider-loading').hide();
        $('#reportAct').prop('disabled', available === 0);
        $('#version').text(data && data.message ? data.message : '');
    }

    function speedtestReloadProviders() {
        ajaxCall(url = "/api/speedtest/service/providerlist", sendData = {}, callback = function(data, status) {
            if (data && data.error) {
                $('#speedtest-provider-loading').removeClass('alert-info').addClass('alert-danger').text(data.error);
                return;
            }
            speedtestRenderProviderStatus(data || {});
        });
    }

    function speedtestRenderServers() {
        const selectedProvider = $('#speedtest-provider').val() || 'auto';
        const previous = $('#speedtest-server').val();
        const select = $('#speedtest-server').empty();
        $('<option>').val('auto').text(
            selectedProvider === 'auto'
                ? "{{ lang._('Automatic best target') }}"
                : "{{ lang._('Best target in this network') }}"
        ).appendTo(select);
        const groups = {};
        speedtestServers.forEach(function(server) {
            if (selectedProvider !== 'auto' && server.provider !== selectedProvider) {
                return;
            }
            if (!groups[server.provider]) {
                const label = (speedtestProviders.find(function(provider) {
                    return provider.id === server.provider;
                }) || {}).label || server.provider;
                groups[server.provider] = $('<optgroup>').attr('label', label).appendTo(select);
            }
            const parts = [server.name, server.location, server.country].filter(function(value) {
                return value;
            });
            const serverKey = server.uuid || server.serverId || 'auto';
            $('<option>')
                .val(serverKey)
                .attr('data-provider', server.provider)
                .text(parts.join(", "))
                .appendTo(groups[server.provider]);
        });
        if (previous && select.find('option[value="' + previous.replace(/(["\\])/g, '\\$1') + '"]').length) {
            select.val(previous);
        }
    }

    function speedtestServerlistReload() {
        $('#serverlistAct_progress').addClass('fa fa-spinner fa-pulse');
        ajaxCall(url = "/api/speedtest/service/serverlist/all", sendData = {}, callback = function(data, status) {
            $('#serverlistAct_progress').removeClass('fa fa-spinner fa-pulse');
            if (Array.isArray(data)) {
                speedtestServers = data;
                speedtestRenderServers();
                return;
            }
            speedtestServers = [];
            speedtestRenderServers();
            if (data && data.error) {
                $('#speedtest-error').text(data.error).show();
            }
        });
    }

    function speedtestRefreshServers(automatic) {
        $('#refreshServersAct_progress').addClass('fa fa-spinner fa-pulse');
        ajaxCall(url = "/api/speedtest/settings/refresh_servers/all", sendData = {}, callback = function(data, status) {
            $('#refreshServersAct_progress').removeClass('fa fa-spinner fa-pulse');
            if (data && data.error) {
                $('#speedtest-refresh-status').text(data.error).show();
                speedtestServerlistReload();
                return;
            }
            $('#speedtest-refresh-status')
                .removeClass('alert-warning')
                .addClass('alert-success')
                .text((automatic ? "{{ lang._('Public target lists refreshed automatically') }}" : "{{ lang._('Public target lists refreshed') }}") +
                    ": " + (data.discovered || 0) + " {{ lang._('targets') }}." +
                    ((data.warnings || []).length ? " " + data.warnings.join(" ") : ""))
                .show();
            $("#{{serverGrid['table_id']}}").bootgrid("reload");
            speedtestSettings.lastRefresh = Math.floor(Date.now() / 1000).toString();
            speedtestServerlistReload();
        });
    }

    function speedtestSelectionLabel(selection) {
        if (selection.method === 'manual') {
            return "{{ lang._('Target selected manually') }}";
        }
        if (selection.method === 'latency-fallback') {
            return "{{ lang._('First selected target failed; retried the next healthy target') }}";
        }
        return "{{ lang._('Lowest median endpoint latency with jitter penalty') }}";
    }

    function speedtestRenderResult(result) {
        $('#speedtest-error').hide();
        $('#test_results').removeClass('opn-speedtest-running').show();
        const download = parseFloat(result.download) || 0;
        const upload = parseFloat(result.upload) || 0;
        const latency = parseFloat(result.latency) || 0;
        const downloadMaximum = speedtestNiceMaximum(download);
        const uploadMaximum = speedtestNiceMaximum(upload);
        $('#dlspeed').text(download.toFixed(2));
        $('#ulspeed').text(upload.toFixed(2));
        $('#latency').text(latency.toFixed(2));
        speedtestSetGauge('download', download, downloadMaximum);
        speedtestSetGauge('upload', upload, uploadMaximum);
        speedtestSetGauge('latency', latency, Math.max(100, latency * 1.15));
        $('.opn-gauge[data-gauge="download"]').attr(
            'aria-label', "{{ lang._('Download') }} " + download.toFixed(2) + " Mbps"
        );
        $('.opn-gauge[data-gauge="upload"]').attr(
            'aria-label', "{{ lang._('Upload') }} " + upload.toFixed(2) + " Mbps"
        );
        $('.opn-gauge[data-gauge="latency"]').attr(
            'aria-label', "{{ lang._('Latency') }} " + latency.toFixed(2) + " ms"
        );
        $('#download-gauge-detail').text("{{ lang._('Scale') }} 0-" + downloadMaximum + " Mbps");
        $('#upload-gauge-detail').text("{{ lang._('Scale') }} 0-" + uploadMaximum + " Mbps");
        $('#latency-gauge-detail').text(
            "{{ lang._('Jitter') }} " + (parseFloat(result.jitter) || 0).toFixed(2) + " ms"
        );
        $('#result_provider').text(result.providerLabel || result.provider);
        $('#result_engine').text(result.engine ? " (" + result.engine + ")" : "");
        $('#result_server').text(
            [(result.serverid ? "id: " + result.serverid : ""), result.servername, result.country]
                .filter(function(value) { return value; })
                .join(" \u2014 ")
        );
        $('#client').text(result.clientip || "\u2014");
        const resultBox = $('#result').empty();
        if (result.link) {
            $('<a>').attr('href', result.link).attr('target', '_blank').attr('rel', 'noopener noreferrer')
                .text(result.link).appendTo(resultBox);
        } else {
            resultBox.text("\u2014");
        }
        const selection = result.selection || {};
        $('#result_selection').text(
            speedtestSelectionLabel(selection) +
            (selection.latency === null || selection.latency === undefined
                ? ""
                : " \u2014 " + speedtestFormat(selection.latency) + " ms / " +
                    speedtestFormat(selection.jitter) + " ms jitter")
        );
        const probes = selection.probes || [];
        $('#speedtest-selection-probes').text(probes.map(function(probe) {
            return (probe.providerLabel || probe.provider) + "/" +
                (probe.server || probe.serverId || "{{ lang._('automatic') }}") + ": " +
                (probe.error || (probe.latency + " ms"));
        }).join(" \u2022 "));
        const warnings = result.warnings || [];
        $('#result_warnings_row,#result_warnings').toggle(warnings.length > 0);
        $('#result_warnings').text(warnings.join(" \u2022 "));
    }

    $(document).ready(function() {
        $("#{{serverGrid['table_id']}}").UIBootgrid({
            search: '/api/speedtest/settings/search_server',
            get: '/api/speedtest/settings/get_server',
            set: '/api/speedtest/settings/set_server',
            add: '/api/speedtest/settings/add_server',
            del: '/api/speedtest/settings/del_server',
            toggle: '/api/speedtest/settings/toggle_server'
        });

        const dataGetMap = {'frm_speedtest_settings': "/api/speedtest/settings/get"};
        mapDataToFormUI(dataGetMap).done(function(data) {
            speedtestSettings = data && data.speedtest ? data.speedtest : {};
            formatTokenizersUI();
            $('.selectpicker').selectpicker('refresh');
            const refreshAge = Math.floor(Date.now() / 1000) - parseInt(speedtestSettings.lastRefresh || "0", 10);
            const interval = parseInt(speedtestSettings.refreshInterval || "1440", 10) * 60;
            if (String(speedtestSettings.autoRefresh) === "1" &&
                (!speedtestSettings.lastRefresh || refreshAge >= interval)) {
                speedtestRefreshServers(true);
            } else {
                speedtestServerlistReload();
            }
        });

        speedtestReloadProviders();
        speedtestStatReload();
        speedtestLogReload();
    });

    $(function() {
        $('#speedtest-provider').change(function() {
            speedtestRenderServers();
        });
        $('#serverlistAct').click(function() {
            speedtestServerlistReload();
        });
        $('#refreshServersAct').click(function() {
            speedtestRefreshServers(false);
        });
        $('#speedtest-tabs a[data-toggle="tab"]').on('shown.bs.tab', function(event) {
            if ($(event.target).attr('href') === '#speedtest-settings') {
                $("#{{serverGrid['table_id']}}").bootgrid("reload");
            }
        });

        $('#saveSettingsAct').click(function() {
            saveFormToEndpoint(
                url = "/api/speedtest/settings/set",
                formid = 'frm_speedtest_settings',
                callback_ok = function() {
                    $('#saveSettingsAct_progress').addClass("fa fa-spinner fa-pulse");
                    ajaxGet(url = "/api/speedtest/settings/get", sendData = {}, callback = function(data, status) {
                        speedtestSettings = data && data.speedtest ? data.speedtest : speedtestSettings;
                        speedtestReloadProviders();
                        speedtestServerlistReload();
                        $('#saveSettingsAct_progress').removeClass("fa fa-spinner fa-pulse");
                    });
                }
            );
        });

        $('#reportAct').click(function() {
            const selectedServer = $('#speedtest-server').find('option:selected');
            const providerSelection = $('#speedtest-provider').val() || 'auto';
            const server = selectedServer.val() || 'auto';
            const provider = server === 'auto'
                ? providerSelection
                : selectedServer.attr('data-provider') || providerSelection;
            $('#speedtest-error').hide();
            $('#test_results').addClass('opn-speedtest-running').show();
            $('#reportAct_progress').addClass("fa fa-spinner fa-pulse");
            $('#reportAct').prop('disabled', true);
            $('#result_provider,#result_engine,#result_server,#result_selection,#speedtest-selection-probes').text('');
            $('#dlspeed,#ulspeed,#latency').text('...');
            speedtestSetGauge('download', 8, 100);
            speedtestSetGauge('upload', 8, 100);
            speedtestSetGauge('latency', 8, 100);
            ajaxCall(
                url = "/api/speedtest/service/run/" + encodeURIComponent(provider) + "/" + encodeURIComponent(server),
                sendData = {},
                callback = function(result, status) {
                    $('#reportAct_progress').removeClass("fa fa-spinner fa-pulse");
                    $('#reportAct').prop('disabled', false);
                    if (result && result.error) {
                        $('#test_results').hide().removeClass('opn-speedtest-running');
                        $('#speedtest-error').text(result.error).show();
                    } else if (result) {
                        speedtestRenderResult(result);
                    } else {
                        $('#test_results').hide().removeClass('opn-speedtest-running');
                        $('#speedtest-error').text("{{ lang._('The measurement backend returned no result.') }}").show();
                    }
                    speedtestStatReload();
                    speedtestLogReload();
                }
            );
        });

        $('#show_advanced_log').click(function(event) {
            event.preventDefault();
            const expanded = $(this).hasClass('fa-toggle-on');
            $('.speedtest-log-advanced').toggle(!expanded);
            $(this).toggleClass('fa-toggle-off fa-toggle-on');
            $('#togglelog').text(expanded ? "{{ lang._('Show detailed history') }}" : "{{ lang._('Hide detailed history') }}");
        });

        $('#deletelogAct').click(function() {
            $('#deletelogAct_progress').addClass("fa fa-spinner fa-pulse");
            ajaxCall(url = "/api/speedtest/service/deletelog", sendData = {}, callback = function() {
                speedtestStatReload();
                speedtestLogReload();
                $('#deletelogAct_progress').removeClass("fa fa-spinner fa-pulse");
            });
        });

        $('#binAct').click(function() {
            $('#binAct_progress').addClass("fa fa-spinner fa-pulse");
            $('#binAct').prop('disabled', true);
            ajaxCall(url = "/api/speedtest/service/installsocket", sendData = {}, callback = function() {
                $('#binAct_progress').removeClass("fa fa-spinner fa-pulse");
                $('#binAct').prop('disabled', false);
                speedtestReloadProviders();
            });
        });
        $('#rustAct').click(function() {
            $('#rustAct_progress').addClass("fa fa-spinner fa-pulse");
            $('#rustAct').prop('disabled', true);
            ajaxCall(url = "/api/speedtest/service/installrust", sendData = {}, callback = function(data, status) {
                $('#rustAct_progress').removeClass("fa fa-spinner fa-pulse");
                $('#rustAct').prop('disabled', false);
                speedtestReloadProviders();
            });
        });
    });
</script>
