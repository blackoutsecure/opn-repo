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
        Chart: function(canvas, config) { chartConfigs.push(config); this.destroy = () => {}; this.resize = () => {}; },
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
    server: 'Lab', total: 1, progress: 50, deadline: Date.now() / 1000 + 60});
assert.equal(page.elements.get('#run_progress').properties.hidden, false);
assert.match(page.elements.get('#readout_hint').message, /in progress/);
page.elements.get('#units').val('Mbps').handlers.change();
assert.match(page.elements.get('#readout_hint').message, /in progress/,
             'Changing units during a run must not show the empty-state prompt');
vm.runInContext('followStatus()', page.context);
page.request('/status').resolve({status: 'completed', run_id: 'a'.repeat(32),
    results: [{serverid: 42, servername: 'Lab', download: 80, latency: 1, jitter: 0, mode: 'download'}]});
assert.equal(page.elements.get('#reportAct').properties.disabled, false);
assert.match(page.elements.get('#test_status').message, /Results saved to history/);
assert.equal(page.elements.get('#download').message, '80 Mbps');
assert.equal(page.elements.get('#upload').message, 'Not measured');
assert.equal(page.elements.get('#jitter').message, '0 ms', 'Zero is a measured value');
assert.equal(page.elements.get('#jitter').classes.has('is-empty'), false);

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
page.request('/history').resolve({rows: [], series: [{epoch: 1700000000, download: 80, upload: 20, latency: 2, jitter: 0}],
    metrics: {}, successful: 1, failed: 0, bytes_received: 1, bytes_sent: 1,
    servers: {}, sources: [], total: 1, limit: 50, bucket_days: 1});
assert.equal(page.elements.get('#trend_charts').properties.hidden, false);
assert.equal(page.chartConfigs.length, 2);
assert.equal(page.chartConfigs[0].data.datasets[0].data[0].y, 80);

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
