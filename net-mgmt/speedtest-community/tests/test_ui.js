const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const rawScript = fs.readFileSync(process.argv[2], 'utf8').match(/<script>([\s\S]*?)<\/script>/)[1];
// CI substitutes only script tokens; native OPNsense separately compiles the full Volt template.
function scriptTokens(source, privileged) {
    return source.replace(/\{\{\s*lang\._\('((?:\\.|[^'])*)'\)\s*\}\}/g,
        (_, text) => JSON.stringify(text.replace(/\\'/g, "'")).slice(1, -1))
        .replace(/\{% if can(?:Run|Configure|Schedule) %\}true\{% else %\}false\{% endif %\}/g, String(privileged));
}
const script = scriptTokens(rawScript, true);
function fixture(source = script) {
    const elements = new Map();
    const nodes = new WeakMap();
    const requests = [];
    const chartConfigs = [];
    function element(selector) {
        const result = {
            properties: {}, attributes: {}, handlers: {}, classes: new Set(), children: [],
            value: ({'#units': 'Mbps', '#serverid': '0',
                '#history_days': '30', '#history_provider': 'librespeed',
                '#history_mode': 'all', '#history_server': 'all', '#history_outcome': 'all',
                '#history_origin': 'all', '#history_family': 'all', '#history_source': 'all'})[selector] || '', message: '',
            0: {addEventListener() {}, reportValidity: () => true},
            prop(key, value) {
                if (value === undefined) return this.properties[key];
                this.properties[key] = value;
                return this;
            },
            val(value) {
                if (value === undefined) return this.value;
                this.value = value;
                return this;
            },
            text(value) { if (value === undefined) return this.message; this.message = value; return this; },
            on(event, handler) { this.handlers[event] = handler; return this; },
            toggleClass(name, enabled) { enabled ? this.classes.add(name) : this.classes.delete(name); return this; },
            addClass(name) { this.classes.add(name); return this; },
            attr(key, value) {
                if (value === undefined) return this.attributes[key];
                this.attributes[key] = value;
                return this;
            },
            removeAttr(key) { this.attributes[key] = null; return this; },
            empty() { this.children = []; return this; },
            append(child) { this.children.push(child); return this; },
            tab(action) { this.properties.tab = action; return this; },
            trigger(event) { this.properties.trigger = event; return this; }
        };
        nodes.set(result[0], result);
        return result;
    }
    function $(selector) {
        if (typeof selector === 'function') {
            selector();
            return;
        }
        if (selector && typeof selector === 'object' && nodes.has(selector)) return nodes.get(selector);
        if (typeof selector === 'string' && selector.startsWith('<')) return element(selector);
        if (!elements.has(selector)) {
            elements.set(selector, element(selector));
        }
        return elements.get(selector);
    }
    const tabIds = ['#measurement_tab', '#history_tab',
        ...(source.includes('const canSchedule = true;') ? ['#schedule_tab'] : []), '#setup_tab'];
    const tabElements = tabIds.map(id => $(id));
    const tabs = {
        length: tabElements.length, handlers: {},
        on(event, handler) { this.handlers[event] = handler; return this; },
        attr(key, value) { tabElements.forEach(tab => tab.attr(key, value)); return this; },
        index(node) { return tabElements.findIndex(tab => tab[0] === node); },
        eq(index) { return tabElements[index]; }
    };
    elements.set('.speedtest-tabs a[role="tab"]', tabs);
    $.ajax = options => {
        const handlers = {done: [], fail: [], always: []};
        const request = {
            options,
            resolve(data) { handlers.done.forEach(fn => fn(data)); handlers.always.forEach(fn => fn()); },
            reject(reason = 'error') { handlers.fail.forEach(fn => fn({}, reason)); handlers.always.forEach(fn => fn()); }
        };
        for (const key of Object.keys(handlers)) {
            request[key] = callback => { handlers[key].push(callback); return request; };
        }
        requests.push(request);
        return request;
    };
    const context = vm.createContext({$, window: {location: {reload() {}}, confirm: () => true},
        Chart: function(canvas, config) {
            chartConfigs.push(config);
            this.data = config.data;
            this.options = config.options;
            this.destroy = () => {};
            this.resize = () => {};
            this.update = () => {};
        },
        getComputedStyle: () => ({color: '#333'}), document: {body: {}, getElementById: () => ({})},
        setTimeout: () => 1, clearTimeout() {}});
    vm.runInContext(source, context);
    return {elements, requests, context, tabs, chartConfigs,
        request: suffix => requests.findLast(r => r.options.url.endsWith(suffix))};
}
const defaults = {public_servers: '1', duration: '10', timeout: '15', concurrent: '3', chunks: '100', upload_size: '1024',
                  family: 'auto', source: '', exclude: '', icmp: '0', http2: '0', no_pre_allocate: '0', private_ca: '0'};
const page = fixture();
page.request('/defaults').resolve(defaults);
assert.equal(page.elements.get('#save_settings').properties.disabled, true);
page.elements.get('#save_settings').handlers.click();
assert.equal(page.requests.some(r => r.options.url.endsWith('/settings/set')), false,
             'Saving before the server GET completes must not overwrite saved configuration');
page.request('/settings/get').resolve({speedtest: {general: {servers: '[{"id":42}]'}}});
assert.equal(page.elements.get('#save_settings').properties.disabled, false);
assert.equal(page.elements.get('#public_servers').properties.checked, true);
page.elements.get('#save_settings').handlers.click();
const save = page.request('/settings/set');
assert.equal(save.options.data.speedtest.general.servers, '[{"id":42}]');
assert.equal(save.options.data.speedtest.general.public_servers, '1');
for (const [key, value] of Object.entries(defaults)) {
    assert.equal(save.options.data.speedtest.general[key], value, 'Saved defaults must include ' + key);
}
assert.equal(page.elements.get('#test_controls').properties.disabled, true);
save.resolve({result: 'failed', error: 'Invalid server JSON'});
assert.equal(page.elements.get('#save_settings').properties.disabled, false);
assert.equal(page.elements.get('#settings_status').message, 'Invalid server JSON');
assert.ok(page.requests.every(r => r.options.url.startsWith('/api/speedtest/')),
          'All API requests must retain the HTTP or HTTPS GUI origin');

vm.runInContext('historyReload()', page.context);
const staleHistory = page.request('/history');
vm.runInContext('historyReload()', page.context);
page.request('/history').resolve({error: 'Current history failed'});
staleHistory.resolve({error: 'Stale history failed'});
assert.equal(page.elements.get('#history_status').message, 'Current history failed',
             'A stale response must not overwrite the current history state');
assert.equal(vm.runInContext('metricValue("upload", null)', page.context), 'Not measured');
page.elements.get('#units').val('MBps');
assert.equal(vm.runInContext('speed(80)', page.context), '10 MB/s');
page.elements.get('#units').val('MiBps');
assert.equal(vm.runInContext('speed(83.88608)', page.context), '10 MiB/s');
page.request('/status').resolve({status: 'idle'});
page.request('/version').resolve({message: 'librespeed-cli v1.2.1 (built on 1970-01-01 00:00:00 UTC)'});
assert.equal(page.elements.get('#version').message, 'LibreSpeed CLI v1.2.1');
page.request('/serverlist').resolve([{id: '42', name: 'Lab'}]);
page.elements.get('#serverid').val('42');
vm.runInContext('$("#mode").val("download")', page.context);
vm.runInContext('renderResults([{serverid:42,servername:"Old",download:50}])', page.context);
page.elements.get('#test_form').handlers.submit.call(page.elements.get('#test_form')[0], {preventDefault() {}});
const start = page.request('/start/42/download');
assert.ok(start, 'The UI must queue a native background measurement rather than hold a long HTTP request');
assert.equal(page.elements.get('#download').message, 'Not measured', 'Starting a new run clears the old measurement');
assert.equal(page.elements.get('#test_results').properties.hidden, true);
start.resolve({result: 'started', run_id: 'a'.repeat(32)});
page.request('/status').resolve({status: 'running', run_id: 'a'.repeat(32), phase: 'download',
    mode: 'download', server: 'Lab', total: 1, progress: 50, deadline: Date.now() / 1000 + 60,
    samples: {download: [{seconds: 1, mbps: 20}, {seconds: 2, mbps: 40}], upload: []}});
assert.equal(page.elements.get('#run_progress').properties.hidden, false);
assert.equal(page.elements.get('#selecting_progress').value, 100);
assert.equal(page.elements.get('#ping_progress').value, 100);
assert.equal(page.elements.get('#download_progress').value, 50);
assert.equal(page.elements.get('#upload_stage').properties.hidden, true);
assert.equal(page.elements.get('#download').message, '4.77 MiB/s');
assert.equal(page.elements.get('#live_chart_region').properties.hidden, false);
assert.equal(page.chartConfigs[0].data.datasets[0].data.length, 2);
page.elements.get('#units').val('MBps').handlers.change();
assert.equal(page.elements.get('#download').message, '5 MB/s');
assert.equal(page.chartConfigs[0].data.datasets[0].data[1].y, 5);
assert.equal(page.chartConfigs[0].options.scales.y.title.text, 'MB/s');
assert.match(page.elements.get('#readout_hint').message, /running averages/,
             'Changing units during a run must not show the empty-state prompt');
vm.runInContext('followStatus()', page.context);
page.request('/status').resolve({status: 'completed', run_id: 'a'.repeat(32),
    phase: 'finished', server: 'Lab', samples: {download: [{seconds: 2, mbps: 40}], upload: []},
    results: [{serverid: 42, servername: 'Lab', download: 80, latency: 1, jitter: 0, mode: 'download'}]});
assert.equal(page.elements.get('#reportAct').properties.disabled, false);
assert.match(page.elements.get('#test_status').message, /Results saved to history/);
assert.equal(page.elements.get('#download').message, '10 MB/s');
assert.equal(page.elements.get('#upload').message, 'Not measured');
assert.equal(page.elements.get('#jitter').message, '0 ms', 'Zero is a measured value');
assert.equal(page.elements.get('#jitter').classes.has('is-empty'), false);
assert.equal(page.elements.get('#live_chart_region').properties.hidden, false,
             'The last live trace remains visible after completion');

const live = fixture();
vm.runInContext(`renderLive({status:'running', mode:'both', phase:'selecting', server:'Lab',
    samples:{download:[],upload:[]}})`, live.context);
assert.equal(live.elements.get('#selecting_progress').attributes.value, null,
             'Server selection has indeterminate progress');
assert.equal(live.elements.get('#ping_status').message, 'Waiting');
vm.runInContext(`renderLive({status:'running', mode:'both', phase:'ping', server:'Lab',
    samples:{download:[],upload:[]}})`, live.context);
assert.equal(live.elements.get('#ping_progress').attributes.value, null,
             'Latency has indeterminate progress');
vm.runInContext(`renderLive({status:'running', mode:'both', phase:'upload', progress:25, server:'Lab',
    samples:{download:[{seconds:1,mbps:80}],upload:[{seconds:1,mbps:24}]}})`, live.context);
assert.equal(live.elements.get('#download_progress').value, 100);
assert.equal(live.elements.get('#upload_progress').value, 25);
assert.equal(live.elements.get('#live_speed').message, 'Upload: 24 Mbps');
assert.equal(live.chartConfigs[0].data.datasets[0].data[0].y, 80);
assert.equal(live.chartConfigs[0].data.datasets[1].data[0].y, 24);
vm.runInContext(`renderLive({status:'running', mode:'both', phase:'selecting', server:'Next server',
    samples:{download:[],upload:[]}})`, live.context);
assert.equal(live.elements.get('#live_chart_region').properties.hidden, true,
             'A comparison must not carry the previous server trace forward');
assert.equal(live.elements.get('#download').message, 'Not measured');
vm.runInContext('Chart = undefined', live.context);
vm.runInContext(`renderLive({status:'running', mode:'both', phase:'download', progress:10, server:'Lab',
    samples:{download:[{seconds:1,mbps:12}],upload:[]}})`, live.context);
assert.match(live.elements.get('#live_chart_status').message, /unavailable/i);
assert.equal(live.elements.get('#download').message, '12 Mbps',
             'Current speed remains available if the chart asset fails to load');

const race = fixture();
race.request('/defaults').resolve(defaults);
race.request('/version').resolve({message: 'librespeed-cli v1.2.1'});
race.request('/status').resolve({status: 'running', run_id: 'b'.repeat(32), phase: 'ping',
    server: 'Lab', total: 1, progress: 10, deadline: Date.now() / 1000 + 60});
race.request('/serverlist').resolve([{id: '42', name: 'Lab'}]);
assert.equal(race.elements.get('#serverlistAct').properties.disabled, true);
vm.runInContext('followStatus()', race.context);
race.request('/status').resolve({status: 'completed', results: []});
assert.equal(race.elements.get('#serverlistAct').properties.disabled, false,
             'Server refresh must recover after a concurrent run ends');

const busy = fixture();
busy.request('/defaults').resolve(defaults);
busy.request('/version').resolve({message: 'librespeed-cli v1.2.1'});
busy.request('/serverlist').resolve([{id: '42', name: 'Lab'}]);
busy.request('/status').resolve({status: 'busy'});
assert.equal(busy.elements.get('#reportAct').properties.disabled, true,
             'A run using a different history must disable new measurements');
assert.equal(busy.elements.get('#deletelogAct').properties.disabled, true);
assert.match(busy.elements.get('#test_status').message, /another test/i);
vm.runInContext('followStatus()', busy.context);
busy.request('/status').resolve({status: 'idle'});
assert.equal(busy.elements.get('#reportAct').properties.disabled, false,
             'Controls must recover when the other run finishes');

const optionsPage = fixture();
optionsPage.request('/defaults').resolve(defaults);
optionsPage.request('/version').resolve({message: 'librespeed-cli v1.2.1'});
optionsPage.request('/serverlist').resolve([{id: '42', name: 'Lab'}, {id: '84', name: 'Other'}]);
optionsPage.request('/status').resolve({status: 'idle'});
vm.runInContext('$("#mode")', optionsPage.context);
const submittedOptions = {duration: '3', timeout: '4', concurrent: '2', chunks: '5', upload_size: '32',
    family: 'ipv4', source: '127.0.0.1', exclude: '', icmp: '1', http2: '1',
    no_pre_allocate: '1', private_ca: '1'};
for (const [key, value] of Object.entries(submittedOptions)) {
    if (['icmp', 'http2', 'no_pre_allocate', 'private_ca'].includes(key)) {
        optionsPage.elements.get('#' + key).prop('checked', value === '1');
    } else {
        optionsPage.elements.get('#' + key).val(value);
    }
}
for (const [mode, selector, custom, expectedServer] of [
    ['both', '0', '', '0'], ['download', '42', '', '42'],
    ['upload', 'custom', '42,84', '42%2C84'], ['latency', '-1', '', '-1']
]) {
    optionsPage.elements.get('#mode').val(mode);
    optionsPage.elements.get('#serverid').val(selector);
    optionsPage.elements.get('#custom_servers').val(custom);
    optionsPage.elements.get('#test_form').handlers.submit.call(
        optionsPage.elements.get('#test_form')[0], {preventDefault() {}});
    const request = optionsPage.request('/start/' + expectedServer + '/' + mode);
    assert.ok(request, 'Every measurement mode and server selection must be submitted');
    assert.equal(JSON.stringify(request.options.data), JSON.stringify(submittedOptions));
    request.resolve({error: 'Fixture reset'});
}

const schedulePage = fixture();
schedulePage.request('/defaults').resolve(defaults);
schedulePage.request('/schedule/get').resolve({schedule: {enabled: '0', cadence: 'daily', hour: '3',
    minute: '15', weekday: '1', server: '0', mode: 'both', timezone: 'UTC', other_jobs: 0}});
for (const cadence of ['hourly', 'daily', 'weekdays', 'weekly']) {
    schedulePage.elements.get('#schedule_enabled').prop('checked', true);
    schedulePage.elements.get('#schedule_cadence').val(cadence);
    schedulePage.elements.get('#schedule_hour').val('5');
    schedulePage.elements.get('#schedule_minute').val('20');
    schedulePage.elements.get('#schedule_weekday').val('2');
    schedulePage.elements.get('#schedule_server').val('42,84');
    schedulePage.elements.get('#schedule_mode').val('latency');
    schedulePage.elements.get('#schedule_cadence, #schedule_hour, #schedule_minute, #schedule_weekday').handlers.change();
    assert.equal(schedulePage.elements.get('#schedule_hour').properties.disabled, cadence === 'hourly');
    assert.equal(schedulePage.elements.get('#schedule_weekday').properties.disabled, cadence !== 'weekly');
    schedulePage.elements.get('#schedule_form').handlers.submit.call(
        schedulePage.elements.get('#schedule_form')[0], {preventDefault() {}});
    const request = schedulePage.request('/schedule/set');
    assert.equal(JSON.stringify(request.options.data.schedule), JSON.stringify({enabled: '1', cadence,
        hour: '5', minute: '20', weekday: '2', server: '42,84', mode: 'latency'}));
    request.resolve({result: 'saved'});
}

const filtersPage = fixture();
vm.runInContext('historyReload()', filtersPage.context);
for (const [selector, value] of Object.entries({'#history_days': '90', '#history_server': '42',
    '#history_mode': 'latency', '#history_provider': 'librespeed', '#history_outcome': 'failed',
    '#history_origin': 'scheduled', '#history_family': 'ipv6', '#history_source': '::1'})) {
    filtersPage.elements.get(selector).val(value);
}
vm.runInContext('historyReload()', filtersPage.context);
assert.equal(JSON.stringify(filtersPage.request('/history').options.data), JSON.stringify({page: 1, days: '90',
    server: '42', mode: 'latency', provider: 'librespeed', status: 'failed',
    origin: 'scheduled', family: 'ipv6', source: '::1'}));

const unconfigured = fixture();
unconfigured.request('/defaults').resolve(defaults);
unconfigured.request('/settings/get').resolve({speedtest: {general: {servers: ''}}});
unconfigured.request('/version').resolve({message: 'librespeed-cli v1.2.1'});
unconfigured.request('/serverlist').resolve({code: 'servers_unconfigured',
    error: 'Speedtest failed: ValueError: Configure the LibreSpeed server list'});
assert.equal(unconfigured.elements.get('#server_setup_notice').properties.hidden, false);
assert.equal(unconfigured.elements.get('#reportAct').properties.disabled, true);
unconfigured.elements.get('#test_form').handlers.submit.call(unconfigured.elements.get('#test_form')[0], {preventDefault() {}});
assert.equal(unconfigured.requests.some(r => r.options.url.includes('/start/')), false,
             'An unconfigured server list must prevent programmatic submission');
unconfigured.elements.get('#open_server_setup').handlers.click({preventDefault() {}});
assert.equal(unconfigured.elements.get('#setup_tab').properties.tab, 'show');
assert.equal(unconfigured.elements.get('#servers_json').properties.trigger, 'focus');

unconfigured.elements.get('#serverlistAct').handlers.click();
unconfigured.request('/serverlist').resolve({error: 'Speedtest failed: ValueError: Invalid server JSON'});
assert.equal(unconfigured.elements.get('#server_setup_notice').properties.hidden, true);
assert.equal(unconfigured.elements.get('#server_status').message, 'Unable to load servers: Invalid server JSON');
assert.equal(unconfigured.elements.get('#server_status').classes.has('text-danger'), true);
unconfigured.request('/status').resolve({status: 'completed', results: []});
assert.equal(unconfigured.elements.get('#server_status').message, 'Unable to load servers: Invalid server JSON',
             'Run status updates must not hide a server-list error');
unconfigured.elements.get('#serverlistAct').handlers.click();
unconfigured.request('/serverlist').reject();
assert.match(unconfigured.elements.get('#server_status').message, /service could not be reached/i);
unconfigured.elements.get('#serverlistAct').handlers.click();
unconfigured.request('/serverlist').resolve([null]);
assert.match(unconfigured.elements.get('#server_status').message, /server list was invalid/i);
assert.equal(unconfigured.elements.get('#reportAct').properties.disabled, true);
unconfigured.elements.get('#serverlistAct').handlers.click();
unconfigured.request('/serverlist').resolve([{id: '42', name: 'Lab'}]);
assert.equal(unconfigured.elements.get('#server_setup_notice').properties.hidden, true);
assert.equal(unconfigured.elements.get('#server_status').message, '');
assert.equal(unconfigured.elements.get('#reportAct').properties.disabled, false);
vm.runInContext('$("#mode").val("both")', unconfigured.context);
unconfigured.elements.get('#test_form').handlers.submit.call(unconfigured.elements.get('#test_form')[0], {preventDefault() {}});
unconfigured.request('/start/0/both').resolve({error: 'Speedtest failed: ValueError: Test could not start'});
assert.equal(unconfigured.elements.get('#test_status').message, 'Test could not start');
assert.match(unconfigured.elements.get('#readout_hint').message, /Run a test/);
assert.equal(unconfigured.elements.get('#reportAct').properties.disabled, false);
unconfigured.elements.get('#test_form').handlers.submit.call(unconfigured.elements.get('#test_form')[0], {preventDefault() {}});
unconfigured.request('/start/0/both').reject();
assert.match(unconfigured.elements.get('#readout_hint').message, /unknown/);
unconfigured.elements.get('#units').val('MBps').handlers.change();
assert.match(unconfigured.elements.get('#readout_hint').message, /unknown/,
             'A lost start response must remain uncertain when units change');
vm.runInContext('followStatus("a".repeat(32), Date.now() - 16000)', unconfigured.context);
unconfigured.request('/status').resolve({status: 'idle'});
assert.match(unconfigured.elements.get('#test_status').message, /did not start/);
assert.match(unconfigured.elements.get('#readout_hint').message, /Run a test/);
assert.equal(unconfigured.elements.get('#run_progress').properties.hidden, true);

let prevented = false;
page.tabs.handlers.keydown.call(page.elements.get('#measurement_tab')[0],
    {key: 'ArrowRight', preventDefault() { prevented = true; }});
assert.equal(prevented, true);
assert.equal(page.elements.get('#history_tab').properties.tab, 'show');
assert.equal(page.elements.get('#history_tab').properties.trigger, 'focus');
page.tabs.handlers['shown.bs.tab'].call(page.elements.get('#history_tab')[0]);
assert.equal(page.elements.get('#measurement_tab').attributes['aria-selected'], 'false');
assert.equal(page.elements.get('#measurement_tab').attributes.tabindex, '-1');
assert.equal(page.elements.get('#history_tab').attributes['aria-selected'], 'true');
assert.equal(page.elements.get('#history_tab').attributes.tabindex, '0');
page.tabs.handlers.keydown.call(page.elements.get('#history_tab')[0], {key: 'End', preventDefault() {}});
assert.equal(page.elements.get('#setup_tab').properties.tab, 'show');
page.tabs.handlers.keydown.call(page.elements.get('#measurement_tab')[0], {key: 'ArrowLeft', preventDefault() {}});
assert.equal(page.elements.get('#setup_tab').properties.trigger, 'focus');

vm.runInContext('historyReload()', page.context);
page.request('/history').resolve({rows: [], series: [], metrics: {}, successful: 0, failed: 0,
    bytes_received: 0, bytes_sent: 0, servers: {}, sources: [], total: 0, limit: 50});
assert.equal(page.elements.get('#trend_charts').properties.hidden, true);
assert.match(page.elements.get('#log_block').children[0].children[0].message, /No measurements/);
vm.runInContext('historyReload()', page.context);
const priorCharts = page.chartConfigs.length;
page.request('/history').resolve({rows: [], series: [{epoch: 1700000000, download: 80, upload: 20, latency: 2, jitter: 0}],
    metrics: {}, successful: 1, failed: 0, bytes_received: 1, bytes_sent: 1,
    servers: {}, sources: [], total: 1, limit: 50, bucket_days: 1});
assert.equal(page.elements.get('#trend_charts').properties.hidden, false);
assert.equal(page.chartConfigs.length, priorCharts + 2);
assert.equal(page.chartConfigs[priorCharts].data.datasets[0].data[0].y, 10);

const failed = fixture();
failed.request('/defaults').resolve(defaults);
failed.request('/settings/get').resolve({});
assert.equal(failed.elements.get('#save_settings').properties.disabled, true);
assert.equal(failed.elements.get('#settings_status').message, 'Unable to load server settings');
failed.request('/version').resolve({message: 'librespeed-cli v1.2.1 (custom build)'});
assert.equal(failed.elements.get('#version').message, 'librespeed-cli v1.2.1 (custom build)',
             'Unexpected engine metadata must remain visible');
const badVersion = fixture();
badVersion.request('/version').resolve({message: {}});
assert.match(badVersion.elements.get('#version').message, /setup is incomplete/i);
assert.equal(badVersion.requests.some(r => r.options.url.endsWith('/serverlist')), false);
const viewerSource = fs.existsSync(process.argv[2] + '.viewer')
    ? fs.readFileSync(process.argv[2] + '.viewer', 'utf8').match(/<script>([\s\S]*?)<\/script>/)[1]
    : scriptTokens(rawScript, false);
const viewer = fixture(viewerSource);
viewer.request('/defaults').resolve(defaults);
viewer.request('/version').resolve({message: 'librespeed-cli v1.2.1'});
viewer.request('/serverlist').resolve({code: 'servers_unconfigured'});
assert.equal(viewer.elements.get('#server_setup_notice').properties.hidden, false);
assert.equal(viewer.elements.has('#open_server_setup'), false);
assert.equal(viewer.elements.get('#reportAct').properties.disabled, true);
assert.equal(viewer.requests.some(r => r.options.url.includes('/schedule/')), false);
vm.runInContext('renderResults([{error:"failed",servername:"One"},{error:"failed",servername:"Two"}])', page.context);
assert.equal(page.elements.get('#latest_success').properties.hidden, true, 'An all-failed comparison must not show stale successful values');
assert.equal(page.elements.get('#download').message, 'Not measured');
assert.equal(page.elements.get('#test_results').properties.hidden, false, 'Failed comparisons remain visible');
assert.equal(page.elements.get('#comparison').properties.hidden, false);
console.log('First-run guidance, navigation, status, results, history, settings and viewer controls passed');
