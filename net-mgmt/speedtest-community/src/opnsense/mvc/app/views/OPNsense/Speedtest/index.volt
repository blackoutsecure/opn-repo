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
    .opn-run-status {
        margin: 0 0 1rem;
        padding: 0.85rem 1rem 0.65rem;
        border-top: 1px solid var(--opn-speedtest-rule);
        border-bottom: 1px solid var(--opn-speedtest-rule);
    }
    .opn-run-status-head {
        display: flex;
        align-items: baseline;
        justify-content: space-between;
        gap: 1rem;
    }
    .opn-run-status .progress {
        height: 0.45rem;
        margin: 0.65rem 0 0.25rem;
    }
    .opn-run-status svg,
    .opn-result-timeline svg {
        display: block;
        width: 100%;
        height: 7.5rem;
    }
    .opn-live-chart-grid,
    .opn-result-chart-grid {
        stroke: var(--opn-speedtest-rule);
        stroke-width: 1;
    }
    .opn-live-chart-line {
        fill: none;
        stroke-width: 3;
        stroke-linecap: round;
        stroke-linejoin: round;
    }
    #opn-live-download,
    #opn-result-download {
        stroke: var(--opn-speedtest-orange);
    }
    #opn-live-upload,
    #opn-result-upload {
        stroke: var(--opn-speedtest-green);
    }
    .opn-run-status[data-active="false"] .progress {
        opacity: 0.45;
    }
    .opn-source-badge {
        display: inline-block;
        margin: 0 0.5rem 0.4rem 0;
        text-decoration: none;
    }
    a.opn-source-badge:hover,
    a.opn-source-badge:focus {
        color: #fff;
        text-decoration: none;
        filter: brightness(1.08);
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
    .opn-selection-details summary {
        cursor: pointer;
        color: inherit;
        opacity: 0.72;
    }
    .opn-result-client-meta {
        display: block;
        margin-top: 0.2rem;
        opacity: 0.72;
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
    .opn-results-toolbar {
        display: flex;
        align-items: flex-end;
        justify-content: space-between;
        gap: 1rem;
        margin-bottom: 0.75rem;
    }
    .opn-results-toolbar .form-control {
        min-width: 18rem;
    }
    .opn-results-table tbody tr {
        cursor: pointer;
    }
    .opn-results-table tbody tr.is-selected,
    .opn-results-table tbody tr:hover {
        background: rgba(192, 62, 20, 0.08);
    }
    .opn-result-inspector {
        margin-top: 1rem;
        padding-top: 1rem;
        border-top: 1px solid var(--opn-speedtest-rule);
    }
    .opn-result-inspector-grid {
        display: grid;
        grid-template-columns: minmax(0, 1.1fr) minmax(18rem, 1fr);
        gap: 1.5rem;
    }
    .opn-result-field {
        display: grid;
        grid-template-columns: 10rem minmax(0, 1fr);
        gap: 0.35rem 0.75rem;
        margin-bottom: 0.25rem;
    }
    .opn-result-field dt {
        margin: 0;
        opacity: 0.7;
    }
    .opn-result-field dd {
        margin: 0;
        overflow-wrap: anywhere;
    }
    .opn-about-summary {
        display: grid;
        grid-template-columns: repeat(3, minmax(0, 1fr));
        gap: 0;
        margin-bottom: 1rem;
        border-top: 1px solid var(--opn-speedtest-rule);
        border-bottom: 1px solid var(--opn-speedtest-rule);
    }
    .opn-about-summary > div {
        padding: 0.8rem 1rem;
        border-right: 1px solid var(--opn-speedtest-rule);
    }
    .opn-about-summary > div:last-child {
        border-right: 0;
    }
    .opn-about-summary strong,
    .opn-about-summary span {
        display: block;
    }
    .opn-about-dependencies td {
        vertical-align: middle;
        overflow-wrap: anywhere;
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
        .opn-results-toolbar,
        .opn-run-status-head,
        .opn-result-inspector-grid {
            display: block;
        }
        .opn-results-toolbar .form-control {
            min-width: 0;
            margin-bottom: 0.5rem;
        }
        .opn-result-field {
            grid-template-columns: 8rem minmax(0, 1fr);
        }
        .opn-about-summary {
            grid-template-columns: 1fr;
        }
        .opn-about-summary > div {
            border-right: 0;
            border-bottom: 1px solid var(--opn-speedtest-rule);
        }
        .opn-about-summary > div:last-child {
            border-bottom: 0;
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
        <li><a data-toggle="tab" href="#speedtest-results-history">{{ lang._('Results') }}</a></li>
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
                <div id="speedtest-live-status" class="opn-run-status"
                     style="display:none" data-active="false" aria-live="polite">
                    <div class="opn-run-status-head">
                        <strong id="speedtest-live-title">{{ lang._('Preparing measurement') }}</strong>
                        <small id="speedtest-live-time" class="text-muted">0 s</small>
                    </div>
                    <div id="speedtest-live-message" class="text-muted">
                        {{ lang._('Preparing the selected measurement network') }}
                    </div>
                    <div class="progress">
                        <div id="speedtest-live-progress"
                             class="progress-bar progress-bar-warning progress-bar-striped active"
                             role="progressbar" aria-valuemin="0" aria-valuemax="100"
                             aria-valuenow="0" style="width:0%">
                        </div>
                    </div>
                    <svg id="speedtest-live-chart" viewBox="0 0 720 110"
                         role="img" aria-label="{{ lang._('Live download and upload activity') }}"
                         style="display:none">
                        <line class="opn-live-chart-grid" x1="12" x2="708" y1="22" y2="22"/>
                        <line class="opn-live-chart-grid" x1="12" x2="708" y1="88" y2="88"/>
                        <polyline class="opn-live-chart-line" id="opn-live-download" points=""/>
                        <polyline class="opn-live-chart-line" id="opn-live-upload" points=""/>
                    </svg>
                </div>
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
                        </dd>
                        <dt>{{ lang._('Selected target') }}</dt>
                        <dd id="result_server"></dd>
                        <dt>{{ lang._('Packet loss') }}</dt>
                        <dd id="result_packet_loss">{{ lang._('Not reported yet') }}</dd>
                        <dt>{{ lang._('Selection') }}</dt>
                        <dd>
                            <div id="result_selection"></div>
                            <details class="opn-selection-details" id="speedtest-selection-details">
                                <summary id="speedtest-selection-summary">{{ lang._('Target checks') }}</summary>
                                <div id="speedtest-selection-probes" class="text-muted"></div>
                            </details>
                        </dd>
                        <dt id="result_warnings_row" style="display:none">{{ lang._('Warnings') }}</dt>
                        <dd id="result_warnings" class="text-warning" style="display:none"></dd>
                        <dt>{{ lang._('External IP') }}</dt>
                        <dd>
                            <span id="client"></span>
                            <small id="client_geo" class="opn-result-client-meta"></small>
                        </dd>
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
            </div>
        </div>

        <div class="tab-pane fade" id="speedtest-results-history">
            <h2>{{ lang._('Results') }}</h2>
            <p class="help-block">
                {{ lang._('The latest 5,000 results are shown here. Export CSV to retrieve the complete local history.') }}
            </p>
            <div class="opn-results-toolbar">
                <input id="speedtest-results-search" class="form-control" type="search"
                       placeholder="{{ lang._('Filter by date, network, target, or location') }}">
                <div>
                    <a href="/api/speedtest/download/csv" class="btn btn-default">
                        {{ lang._('Export CSV') }}
                    </a>
                    <button class="btn btn-default" id="deletelogAct" type="button">
                        {{ lang._('Clear history') }} <i id="deletelogAct_progress"></i>
                    </button>
                </div>
            </div>
            <div class="content-box table-responsive">
                <table class="table table-condensed opn-results-table">
                    <thead>
                        <tr>
                            <th>{{ lang._('Date') }}</th>
                            <th>{{ lang._('Network') }}</th>
                            <th>{{ lang._('Target') }}</th>
                            <th>{{ lang._('External IP / location') }}</th>
                            <th>{{ lang._('Download') }}</th>
                            <th>{{ lang._('Upload') }}</th>
                            <th>{{ lang._('Latency') }}</th>
                            <th>{{ lang._('Packet loss') }}</th>
                            <th>{{ lang._('Details') }}</th>
                        </tr>
                    </thead>
                    <tbody id="speedtest-results-body"></tbody>
                </table>
                <div id="speedtest-results-empty" class="help-block" style="padding:1rem">
                    {{ lang._('No completed measurements are available.') }}
                </div>
            </div>
            <div id="speedtest-result-inspector" class="opn-result-inspector" style="display:none">
                <h3 id="speedtest-result-title">{{ lang._('Measurement details') }}</h3>
                <div class="opn-result-inspector-grid">
                    <dl id="speedtest-result-fields" class="opn-result-field"></dl>
                    <div class="opn-result-timeline">
                        <strong>{{ lang._('Run timeline') }}</strong>
                        <div id="speedtest-result-timeline-note" class="help-block"></div>
                        <svg id="speedtest-result-timeline-chart" viewBox="0 0 720 140"
                             role="img" aria-label="{{ lang._('Selected measurement throughput timeline') }}">
                            <line class="opn-result-chart-grid" x1="10" x2="710" y1="22" y2="22"/>
                            <line class="opn-result-chart-grid" x1="10" x2="710" y1="110" y2="110"/>
                            <polyline class="opn-live-chart-line" id="opn-result-download" points=""/>
                            <polyline class="opn-live-chart-line" id="opn-result-upload" points=""/>
                        </svg>
                    </div>
                </div>
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
                <div class="col-md-12 __mt">
                    <details>
                        <summary>{{ lang._('Command line and automation help') }}</summary>
                        <p class="help-block">
                            {{ lang._('The plugin exposes the same network selection, progress, and saved-results functions to OPNsense automation.') }}
                        </p>
                        <pre>configctl speedtest about
configctl speedtest version
configctl speedtest providers
configctl speedtest serverlist-provider all
configctl speedtest discover all
configctl speedtest run-provider auto auto
configctl speedtest progress
configctl speedtest results 1000
configctl speedtest showstat
configctl speedtest showlog
configctl speedtest showrecent
configctl speedtest deletelog

configctl speedtest run 0
configctl speedtest run 63762
configctl speedtest serverlist</pre>
                        <p class="help-block">
                            {{ lang._('Direct CLI: /usr/local/opnsense/scripts/OPNsense/speedtest/opn_speedtest.py [version|providers|list|discover|run|progress|results|stat|log|recent|clear].') }}
                        </p>
                    </details>
                </div>
            </div>

            <h2>{{ lang._('Measurement targets') }}</h2>
            <div class="alert alert-info">
                {{ lang._("Public targets are refreshed and managed automatically. Toggle Included to remember whether a public target participates; metadata and endpoints cannot be edited.") }}
            </div>
            <div class="alert alert-warning" id="speedtest-refresh-status" style="display:none"></div>
            <div style="margin-bottom:0.75rem">
                <button class="btn btn-default" id="refreshServersAct" type="button">
                    <b>{{ lang._('Refresh public targets') }}</b>
                    <i id="refreshServersAct_progress"></i>
                </button>
            </div>
            <div class="content-box">
                <h3>{{ lang._('Public targets') }}</h3>
                <p class="help-block">
                    {{ lang._('Provider-managed targets. Refresh updates availability and metadata only; inclusion choices are preserved.') }}
                </p>
                {{ partial('layout_partials/base_bootgrid_table', publicServerGrid) }}
            </div>
            <div class="content-box">
                <h3>{{ lang._('Custom targets') }}</h3>
                <p class="help-block">
                    {{ lang._('Operator-managed targets. These can be added, edited, deleted, enabled, or disabled.') }}
                </p>
                {{ partial('layout_partials/base_bootgrid_table', serverGrid) }}
            </div>

            <h2>{{ lang._('About Speedtest') }}</h2>
            <div class="content-box" style="padding:1rem">
                <div id="speedtest-about-loading" class="text-muted">
                    {{ lang._('Loading installed package and runtime information...') }}
                </div>
                <div id="speedtest-about-content" style="display:none">
                    <div class="opn-about-summary">
                        <div>
                            <strong id="speedtest-about-version"></strong>
                            <span class="text-muted">{{ lang._('Installed package') }}</span>
                        </div>
                        <div>
                            <strong id="speedtest-about-abi"></strong>
                            <span class="text-muted">{{ lang._('OPNsense ABI / architecture') }}</span>
                        </div>
                        <div>
                            <strong id="speedtest-about-hash"></strong>
                            <span class="text-muted">{{ lang._('Build hash') }}</span>
                        </div>
                    </div>
                    <table class="table table-condensed opn-about-dependencies">
                        <thead>
                            <tr>
                                <th>{{ lang._('Runtime component') }}</th>
                                <th>{{ lang._('Version') }}</th>
                                <th>{{ lang._('Use') }}</th>
                                <th>{{ lang._('Status') }}</th>
                            </tr>
                        </thead>
                        <tbody id="speedtest-about-dependencies"></tbody>
                    </table>
                    <div class="help-block">
                        {{ lang._('Third-party Python dependencies') }}:
                        <strong id="speedtest-about-python-deps">{{ lang._('none') }}</strong>
                    </div>
                </div>
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
    let speedtestResults = [];
    let speedtestProgressTimer = null;
    let speedtestProgressRequest = false;
    let speedtestRunRequestActive = false;

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

    function speedtestSamplesByDirection(samples, direction) {
        return (Array.isArray(samples) ? samples : [])
            .filter(function(sample) {
                return sample.direction === direction || (
                    sample.direction === "result" && sample[direction] !== undefined
                );
            })
            .map(function(sample) {
                return {
                    time: parseFloat(sample.time) || 0,
                    value: parseFloat(
                        sample.direction === "result" ? sample[direction] : sample.mbps
                    ) || 0
                };
            });
    }

    function speedtestRenderActivityChart(samples, downloadSelector, uploadSelector) {
        const download = speedtestSamplesByDirection(samples, "download");
        const upload = speedtestSamplesByDirection(samples, "upload");
        const values = download.concat(upload).map(function(sample) { return sample.value; });
        if (!values.length) {
            return false;
        }
        const maximum = speedtestNiceMaximum(Math.max.apply(Math, values));
        const maximumTime = Math.max.apply(
            Math,
            download.concat(upload).map(function(sample) { return sample.time; })
        ) || 1;
        const points = function(series) {
            if (!series.length) {
                return "";
            }
            const coordinates = series.map(function(sample) {
                const x = 12 + 696 * Math.min(sample.time / maximumTime, 1);
                const y = 94 - 76 * Math.min(sample.value / maximum, 1);
                return x.toFixed(2) + "," + y.toFixed(2);
            });
            return coordinates.length === 1
                ? coordinates[0] + " " + coordinates[0]
                : coordinates.join(" ");
        };
        $(downloadSelector).attr("points", points(download));
        $(uploadSelector).attr("points", points(upload));
        return true;
    }

    function speedtestRenderProgress(data) {
        if (!data) {
            return;
        }
        if (speedtestRunRequestActive && data.phase === 'idle') {
            return;
        }
        const active = Boolean(data.active);
        const percent = Math.max(0, Math.min(100, Number(data.percent) || 0));
        $('#speedtest-live-status').show().attr('data-active', active ? 'true' : 'false');
        $('#speedtest-live-title').text(
            speedtestFormat(data.phase).replace(/[-_]/g, " ").replace(/\b\w/g, function(letter) {
                return letter.toUpperCase();
            })
        );
        $('#speedtest-live-message').text(data.message || "{{ lang._('Measurement in progress') }}");
        $('#speedtest-live-time').text(Math.max(0, Number(data.elapsed) || 0).toFixed(0) + " s");
        $('#speedtest-live-progress')
            .css('width', percent + '%')
            .attr('aria-valuenow', percent.toFixed(0));
        if (data.phase === "selecting-target" || data.phase === "target-selected") {
            $('#download-gauge-detail,#upload-gauge-detail,#latency-gauge-detail')
                .text("{{ lang._('Selecting target') }}");
        }
        const samples = Array.isArray(data.samples) ? data.samples : [];
        const hasSamples = speedtestRenderActivityChart(
            samples,
            '#opn-live-download',
            '#opn-live-upload'
        );
        $('#speedtest-live-chart').toggle(hasSamples);
        $('#speedtest-live-progress').toggleClass('active progress-bar-striped', !hasSamples && active);
        const latestDownload = speedtestSamplesByDirection(samples, "download").slice(-1)[0];
        const latestUpload = speedtestSamplesByDirection(samples, "upload").slice(-1)[0];
        if (latestDownload) {
            const maximum = speedtestNiceMaximum(latestDownload.value);
            $('#dlspeed').text(latestDownload.value.toFixed(1));
            speedtestSetGauge("download", latestDownload.value, maximum);
            $('#download-gauge-detail').text("{{ lang._('Live') }}");
        }
        if (latestUpload) {
            const maximum = speedtestNiceMaximum(latestUpload.value);
            $('#ulspeed').text(latestUpload.value.toFixed(1));
            speedtestSetGauge("upload", latestUpload.value, maximum);
            $('#upload-gauge-detail').text("{{ lang._('Live') }}");
        }
        if (data.phase === "complete") {
            $('#speedtest-live-title').text("{{ lang._('Complete') }}");
            $('#speedtest-live-progress').removeClass('progress-bar-warning').addClass('progress-bar-success');
        }
        if (data.phase === "error") {
            $('#speedtest-live-progress').removeClass('progress-bar-warning progress-bar-success').addClass('progress-bar-danger');
        }
    }

    function speedtestStopProgressPolling() {
        if (speedtestProgressTimer !== null) {
            clearInterval(speedtestProgressTimer);
            speedtestProgressTimer = null;
        }
    }

    function speedtestPollProgress() {
        if (speedtestProgressRequest) {
            return;
        }
        speedtestProgressRequest = true;
        ajaxCall(url = "/api/speedtest/service/progress", sendData = {}, callback = function(data, status) {
            speedtestProgressRequest = false;
            speedtestRenderProgress(data);
            if (
                data &&
                data.active === false &&
                (data.phase === 'complete' || data.phase === 'error' || !speedtestRunRequestActive)
            ) {
                speedtestStopProgressPolling();
            }
        });
    }

    function speedtestStartProgressPolling() {
        speedtestRunRequestActive = true;
        speedtestStopProgressPolling();
        $('#test_results').addClass('opn-speedtest-running').show();
        $('#speedtest-live-status')
            .show()
            .attr('data-active', 'true');
        $('#speedtest-live-title').text("{{ lang._('Preparing') }}");
        $('#speedtest-live-message').text("{{ lang._('Preparing the selected measurement network') }}");
        $('#speedtest-live-time').text("0 s");
        $('#speedtest-live-progress').css('width', '0%').attr('aria-valuenow', '0');
        $('#speedtest-live-progress')
            .removeClass('progress-bar-success progress-bar-danger')
            .addClass('progress-bar-warning progress-bar-striped active');
        speedtestRenderActivityChart([], '#opn-live-download', '#opn-live-upload');
        $('#speedtest-live-chart').hide();
        speedtestPollProgress();
        speedtestProgressTimer = setInterval(speedtestPollProgress, 750);
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
            if (!Array.isArray(l)) {
                speedtestRenderHistory([]);
                return;
            }
            speedtestRenderHistory(l);
        });
    }

    function speedtestResultDetails(row) {
        try {
            const details = JSON.parse(row[13] || "{}");
            return details && typeof details === "object" ? details : {};
        } catch (error) {
            return {};
        }
    }

    function speedtestResultTarget(row, details) {
        const server = (details && details.server) || {};
        if (server.name) {
            return server.name;
        }
        const serverId = row[9] === "cloudflare" && row[2] === "edge" ? "" : row[2];
        return [serverId, row[3]].filter(function(value) { return value; }).join(" ");
    }

    function speedtestProviderName(provider) {
        const match = speedtestProviders.find(function(item) {
            return item.id === provider;
        });
        return match ? match.label : provider;
    }

    function speedtestClientLocation(client) {
        if (!client || typeof client !== "object") {
            return "";
        }
        const location = [
            client.city,
            client.region || client.region_name,
            client.country || client.country_name
        ].filter(function(value) { return value; });
        let coordinates = client.loc || client.location || client.coordinates;
        if (!coordinates && (client.lat || client.latitude) && (client.lon || client.longitude)) {
            coordinates = (client.lat || client.latitude) + ", " + (client.lon || client.longitude);
        } else if (coordinates && typeof coordinates === "object") {
            coordinates = [
                coordinates.latitude || coordinates.lat,
                coordinates.longitude || coordinates.lon
            ].filter(function(value) { return value !== undefined && value !== ""; }).join(", ");
        }
        if (coordinates) {
            location.push(String(coordinates));
        }
        return location.join(", ");
    }

    function speedtestClientNetwork(client) {
        if (!client || typeof client !== "object") {
            return "";
        }
        return [
            client.isp,
            client.org || client.as_name,
            client.asn || client.as,
            client.timezone
        ].filter(function(value) { return value; }).join(" / ");
    }

    function speedtestShowResultDetail(row) {
        const details = speedtestResultDetails(row);
        const client = details.client || {};
        const server = details.server || {};
        const network = details.network || {};
        const selection = details.selection || {};
        const samples = details.samples || [];
        const fields = [];
        const addField = function(label, value) {
            if (value === null || value === undefined || value === "") {
                return;
            }
            fields.push(
                $('<dt>').text(label),
                $('<dd>').text(String(value))
            );
        };
        addField("{{ lang._('Date') }}", row[0]);
        addField("{{ lang._('Network') }}", speedtestProviderName(row[9]));
        addField(
            "{{ lang._('Target') }}",
            speedtestResultTarget(row, details)
        );
        addField("{{ lang._('External IP') }}", client.ip || row[1]);
        addField("{{ lang._('Location') }}", speedtestClientLocation(client));
        addField("{{ lang._('ISP / network') }}", speedtestClientNetwork(client));
        addField("{{ lang._('Result') }}", row[5] + " Mbps / " + row[6] + " Mbps");
        addField("{{ lang._('Latency / jitter') }}", row[7] + " ms / " + row[10] + " ms");
        addField(
            "{{ lang._('Packet loss') }}",
            row[14] === ""
                ? "{{ lang._('Not reported by this provider') }}"
                : row[14] + "% " + (row[15] ? "(" + row[15] + ")" : "")
        );
        addField(
            "{{ lang._('Selection') }}",
            selection.method === "manual"
                ? "{{ lang._('Selected manually') }}"
                : "{{ lang._('Checked') }} " + ((selection.probes || []).length) + " {{ lang._('targets') }}"
        );
        addField(
            "{{ lang._('Network details') }}",
            Object.keys(network).length ? JSON.stringify(network) : ""
        );
        addField("{{ lang._('Warnings') }}", (details.warnings || []).join(" \u2022 "));
        addField("{{ lang._('Shareable result') }}", row[8]);
        $('#speedtest-result-title').text(
            speedtestProviderName(row[9]) + " \u2014 " + row[0]
        );
        $('#speedtest-result-fields').empty().append(fields);
        const hasTimeline = speedtestRenderActivityChart(
            samples,
            '#opn-result-download',
            '#opn-result-upload'
        );
        const hasLiveSamples = samples.some(function(sample) {
            return !sample.summary;
        });
        $('#speedtest-result-timeline-chart').toggle(hasTimeline);
        $('#speedtest-result-timeline-note').text(
            hasTimeline && hasLiveSamples
                ? "{{ lang._('Captured transfer activity for this measurement') }}"
                : "{{ lang._('This source reported final totals only; no intermediate samples were available.') }}"
        );
        $('#speedtest-result-inspector').show();
    }

    function speedtestRenderResults(filter) {
        const term = (filter || "").toLowerCase();
        const body = $('#speedtest-results-body').empty();
        const rows = speedtestResults.filter(function(row) {
            const details = speedtestResultDetails(row);
            return !term || [
                row.join(" "),
                JSON.stringify(details)
            ].join(" ").toLowerCase().indexOf(term) !== -1;
        });
        rows.forEach(function(row) {
            const details = speedtestResultDetails(row);
            const client = details.client || {};
            const location = speedtestClientLocation(client);
            const trigger = $('<button>')
                .addClass('btn btn-xs btn-default')
                .text("{{ lang._('View') }}")
                .on('click', function(event) {
                    event.stopPropagation();
                    speedtestShowResultDetail(row);
                });
            $('<tr>')
                .append($('<td>').text(speedtestFormat(row[0])))
                .append($('<td>').text(speedtestProviderName(row[9])))
                .append($('<td>').text(speedtestResultTarget(row, details)))
                .append($('<td>').text(
                    [client.ip || row[1], location].filter(function(value) { return value; }).join(" \u2014 ")
                ))
                .append($('<td>').text(parseFloat(row[5] || 0).toFixed(2) + " Mbps"))
                .append($('<td>').text(parseFloat(row[6] || 0).toFixed(2) + " Mbps"))
                .append($('<td>').text(parseFloat(row[7] || 0).toFixed(2) + " ms"))
                .append($('<td>').text(
                    row[14] === "" ? "\u2014" : parseFloat(row[14]).toFixed(2) + "%"
                ))
                .append($('<td>').append(trigger))
                .on('click', function() {
                    speedtestShowResultDetail(row);
                })
                .appendTo(body);
        });
        $('#speedtest-results-empty').toggle(rows.length === 0);
    }

    function speedtestResultsReload() {
        ajaxCall(url = "/api/speedtest/service/results/5000", sendData = {}, callback = function(data, status) {
            if (!Array.isArray(data)) {
                $('#speedtest-results-body').empty();
                $('#speedtest-results-empty').show();
                return;
            }
            speedtestResults = data;
            speedtestRenderResults($('#speedtest-results-search').val());
        });
    }

    function speedtestAboutReload() {
        ajaxCall(url = "/api/speedtest/service/about", sendData = {}, callback = function(data, status) {
            if (!data || data.error) {
                $('#speedtest-about-loading').text(
                    data && data.error ? data.error : "{{ lang._('Package information is unavailable.') }}"
                );
                return;
            }
            const packageInfo = data.package || {};
            const runtime = data.runtime || {};
            $('#speedtest-about-version').text(packageInfo.product_version || "{{ lang._('development') }}");
            $('#speedtest-about-abi').text(
                [packageInfo.product_abi, packageInfo.product_arch || runtime.architecture]
                    .filter(function(value) { return value; })
                    .join(" / ")
            );
            $('#speedtest-about-hash').text(
                packageInfo.product_hash || "{{ lang._('not packaged') }}"
            );
            const body = $('#speedtest-about-dependencies').empty();
            (data.dependencies || []).forEach(function(dependency) {
                const available = dependency.status === "available";
                const name = dependency.website
                    ? $('<a>')
                        .attr('href', dependency.website)
                        .attr('target', '_blank')
                        .attr('rel', 'noopener noreferrer')
                        .text(dependency.name)
                    : $('<span>').text(dependency.name);
                $('<tr>')
                    .append($('<td>').append(name))
                    .append($('<td>').text(dependency.version || "\u2014"))
                    .append($('<td>').text(dependency.role || ""))
                    .append(
                        $('<td>').append(
                            $('<span>')
                                .addClass('label ' + (available ? 'label-success' : 'label-danger'))
                                .text(dependency.status)
                        )
                    )
                    .appendTo(body);
            });
            const externalPython = data.thirdPartyPythonDependencies || [];
            $('#speedtest-about-python-deps').text(
                externalPython.length ? externalPython.join(", ") : "{{ lang._('none') }}"
            );
            $('#speedtest-about-loading').hide();
            $('#speedtest-about-content').show();
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
            const badge = $('<a>')
                .addClass("label " + css + " opn-source-badge")
                .attr('href', provider.website || '#')
                .attr('target', provider.website ? '_blank' : '')
                .attr('rel', provider.website ? 'noopener noreferrer' : '')
                .attr(
                    'aria-label',
                    provider.label + " - " + suffix + ". " +
                    (provider.website ? "{{ lang._('Open provider site') }}" : "")
                )
                .attr('title', provider.label + " - " + suffix)
                .text(
                    provider.enabled && provider.available
                        ? provider.label
                        : provider.label + " (" + suffix + ")"
                );
            badge.appendTo('#speedtest-provider-badges');
            $('<option>')
                .val(provider.id)
                .prop("disabled", !provider.enabled || !provider.available)
                .text(provider.label + (provider.available && provider.enabled ? "" : " (" + suffix + ")"))
                .appendTo(select);
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
        ajaxCall(
            url = "/api/speedtest/settings/refresh_servers/all/" + (automatic ? "1" : "0"),
            sendData = {},
            callback = function(data, status) {
                $('#refreshServersAct_progress').removeClass('fa fa-spinner fa-pulse');
                if (data && data.error) {
                    $('#speedtest-refresh-status').text(data.error).show();
                    speedtestServerlistReload();
                    return;
                }
                if (data && (data.status === 'unchanged' || data.status === 'disabled')) {
                    speedtestServerlistReload();
                    return;
                }
                if (automatic) {
                    $('#speedtest-refresh-status').hide();
                } else {
                    $('#speedtest-refresh-status')
                        .removeClass('alert-warning')
                        .addClass('alert-success')
                        .text("{{ lang._('Public target lists refreshed') }}" +
                            ": " + (data.discovered || 0) + " {{ lang._('targets') }}." +
                            ((data.warnings || []).length ? " " + data.warnings.join(" ") : ""))
                        .show();
                }
                $("#{{publicServerGrid['table_id']}}").bootgrid("reload");
                $("#{{serverGrid['table_id']}}").bootgrid("reload");
                speedtestSettings.lastRefresh = Math.floor(Date.now() / 1000).toString();
                speedtestServerlistReload();
            }
        );
    }

    function speedtestSelectionLabel(selection) {
        if (selection.method === 'manual') {
            return "{{ lang._('Target selected manually') }}";
        }
        if (selection.method === 'latency-fallback') {
            return "{{ lang._('First selected target failed; retried the next healthy target') }}";
        }
        return "{{ lang._('The most responsive target was selected automatically') }}";
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
        const visibleServerId =
            result.provider === "cloudflare" && result.serverid === "edge"
                ? ""
                : (result.serverid ? "id: " + result.serverid : "");
        $('#result_server').text(
            [visibleServerId, result.servername, result.country]
                .filter(function(value) { return value; })
                .join(" \u2014 ")
        );
        $('#result_packet_loss').text(
            result.packetLossMeasured && result.packetLoss !== null && result.packetLoss !== undefined
                ? Number(result.packetLoss).toFixed(2) + "% " +
                    (result.packetLossMethod ? "(" + result.packetLossMethod + ")" : "")
                : "{{ lang._('Not reported by this provider') }}"
        );
        const client = result.client || {};
        $('#client').text(client.ip || result.clientip || "\u2014");
        $('#client_geo').text([
            speedtestClientLocation(client),
            speedtestClientNetwork(client)
        ].filter(function(value) { return value; }).join(" \u2022 "));
        const resultBox = $('#result').empty();
        if (result.link) {
            $('<a>').attr('href', result.link).attr('target', '_blank').attr('rel', 'noopener noreferrer')
                .text(result.link).appendTo(resultBox);
        } else {
            resultBox.text("\u2014");
        }
        const selection = result.selection || {};
        const probes = selection.probes || [];
        const checked = probes.length;
        $('#result_selection').text(
            speedtestSelectionLabel(selection) +
            (selection.method === 'manual'
                ? ""
                : " \u2014 " + checked + " {{ lang._('targets checked') }}") +
            (selection.latency === null || selection.latency === undefined
                ? ""
                : " \u2014 " + speedtestFormat(selection.latency) + " ms / " +
                    speedtestFormat(selection.jitter) + " ms jitter")
        );
        $('#speedtest-selection-summary').text(
            "{{ lang._('Target checks') }} (" + checked + ")"
        );
        $('#speedtest-selection-details')
            .prop('open', false)
            .toggle(checked > 0);
        $('#speedtest-selection-probes').text(probes.map(function(probe) {
            return (probe.providerLabel || probe.provider) + "/" +
                (probe.server || probe.serverId || "{{ lang._('automatic') }}") + ": " +
                (probe.error || (probe.latency + " ms"));
        }).join(" \u2022 "));
        const warnings = result.warnings || [];
        $('#result_warnings_row,#result_warnings').toggle(warnings.length > 0);
        $('#result_warnings').text(warnings.join(" \u2022 "));
        speedtestRunRequestActive = false;
        speedtestStopProgressPolling();
        speedtestRenderProgress({
            active: false,
            phase: "complete",
            message: "{{ lang._('Measurement complete') }}",
            percent: 100,
            elapsed: (result.samples || []).reduce(function(maximum, sample) {
                return Math.max(maximum, Number(sample.time) || 0);
            }, 0),
            samples: result.samples || []
        });
        speedtestRenderActivityChart(
            result.samples || [],
            '#opn-live-download',
            '#opn-live-upload'
        );
    }

    $(document).ready(function() {
        $("#{{publicServerGrid['table_id']}}").UIBootgrid({
            search: '/api/speedtest/settings/search_public_server/',
            toggle: '/api/speedtest/settings/toggle_public_server/'
        });
        $("#{{serverGrid['table_id']}}").UIBootgrid({
            search: '/api/speedtest/settings/search_custom_server/',
            get: '/api/speedtest/settings/get_server/',
            set: '/api/speedtest/settings/set_server/',
            add: '/api/speedtest/settings/add_server/',
            del: '/api/speedtest/settings/del_server/',
            toggle: '/api/speedtest/settings/toggle_server/'
        });

        const dataGetMap = {'frm_speedtest_settings': "/api/speedtest/settings/get"};
        mapDataToFormUI(dataGetMap).done(function(data) {
            speedtestSettings = data && data.speedtest ? data.speedtest : {};
            formatTokenizersUI();
            $('.selectpicker').selectpicker('refresh');
        });

        speedtestReloadProviders();
        speedtestRefreshServers(true);
        speedtestStatReload();
        speedtestLogReload();
        speedtestAboutReload();
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
            const target = $(event.target).attr('href');
            if (target === '#speedtest-settings') {
                $("#{{publicServerGrid['table_id']}}").bootgrid("reload");
                $("#{{serverGrid['table_id']}}").bootgrid("reload");
            } else if (target === '#speedtest-results-history') {
                speedtestResultsReload();
            }
        });
        $('#speedtest-results-search').on('input', function() {
            speedtestRenderResults($(this).val());
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
            speedtestStartProgressPolling();
            $('#reportAct_progress').addClass("fa fa-spinner fa-pulse");
            $('#reportAct').prop('disabled', true);
            $('#result_provider,#result_server,#result_selection,#speedtest-selection-probes').text('');
            $('#result_packet_loss').text("{{ lang._('Waiting for the provider result') }}");
            $('#dlspeed,#ulspeed,#latency').text('...');
            speedtestSetGauge('download', 8, 100);
            speedtestSetGauge('upload', 8, 100);
            speedtestSetGauge('latency', 8, 100);
            $('#download-gauge-detail,#upload-gauge-detail,#latency-gauge-detail')
                .text("{{ lang._('Preparing') }}");
            ajaxCall(
                url = "/api/speedtest/service/run/" + encodeURIComponent(provider) + "/" + encodeURIComponent(server),
                sendData = {},
                callback = function(result, status) {
                    speedtestRunRequestActive = false;
                    $('#reportAct_progress').removeClass("fa fa-spinner fa-pulse");
                    $('#reportAct').prop('disabled', false);
                    if (result && result.error) {
                        speedtestStopProgressPolling();
                        speedtestRenderProgress({
                            active: false,
                            phase: "error",
                            message: result.error,
                            percent: 0
                        });
                        $('#test_results').hide().removeClass('opn-speedtest-running');
                        $('#speedtest-error').text(result.error).show();
                    } else if (result) {
                        speedtestRenderResult(result);
                    } else {
                        speedtestStopProgressPolling();
                        $('#test_results').hide().removeClass('opn-speedtest-running');
                        $('#speedtest-error').text("{{ lang._('The measurement backend returned no result.') }}").show();
                    }
                    speedtestStatReload();
                    speedtestLogReload();
                    speedtestResultsReload();
                }
            );
        });

        $('#deletelogAct').click(function() {
            $('#deletelogAct_progress').addClass("fa fa-spinner fa-pulse");
            ajaxCall(url = "/api/speedtest/service/deletelog", sendData = {}, callback = function() {
                speedtestStatReload();
                speedtestLogReload();
                speedtestResults = [];
                speedtestRenderResults("");
                $('#speedtest-result-inspector').hide();
                $('#deletelogAct_progress').removeClass("fa fa-spinner fa-pulse");
            });
        });

    });
</script>
