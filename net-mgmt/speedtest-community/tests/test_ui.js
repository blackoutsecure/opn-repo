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
    const requests = [];
    function $(selector) {
        if (typeof selector === 'function') {
            selector();
            return;
        }
        if (!elements.has(selector)) {
            const element = {
                properties: {}, handlers: {}, value: ({'#units': 'Mbps', '#serverid': '0',
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
                toggleClass() { return this; },
                addClass() { return this; },
                attr() { return this; },
                empty() { return this; },
                append() { return this; }
            };
            elements.set(selector, element);
        }
        return elements.get(selector);
    }
    $.ajax = options => {
        const handlers = {done: [], fail: [], always: []};
        const request = {
            options,
            resolve(data) { handlers.done.forEach(fn => fn(data)); handlers.always.forEach(fn => fn()); },
            reject() { handlers.fail.forEach(fn => fn({}, 'error')); handlers.always.forEach(fn => fn()); }
        };
        for (const key of Object.keys(handlers)) {
            request[key] = callback => { handlers[key].push(callback); return request; };
        }
        requests.push(request);
        return request;
    };
    const context = vm.createContext({$, window: {location: {reload() {}}, confirm: () => true},
        Chart: function() { this.destroy = () => {}; this.resize = () => {}; },
        getComputedStyle: () => ({color: '#333'}), document: {body: {}, getElementById: () => ({})},
        setTimeout: () => 1, clearTimeout() {}});
    vm.runInContext(source, context);
    return {elements, requests, context, request: suffix => requests.findLast(r => r.options.url.endsWith(suffix))};
}
const defaults = {duration: '10', timeout: '8', concurrent: '3', chunks: '100', upload_size: '1024',
                  family: 'auto', source: '', exclude: '', icmp: '0', http2: '0', no_pre_allocate: '0', private_ca: '0'};
const page = fixture();
page.request('/defaults').resolve(defaults);
assert.equal(page.elements.get('#save_settings').properties.disabled, true);
page.elements.get('#save_settings').handlers.click();
assert.equal(page.requests.some(r => r.options.url.endsWith('/settings/set')), false,
             'Saving before the server GET completes must not overwrite saved configuration');
page.request('/settings/get').resolve({speedtest: {general: {servers: '[{"id":42}]'}}});
assert.equal(page.elements.get('#save_settings').properties.disabled, false);
page.elements.get('#save_settings').handlers.click();
const save = page.request('/settings/set');
assert.equal(save.options.data.speedtest.general.servers, '[{"id":42}]');
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
page.request('/version').resolve({message: 'librespeed-cli v1.2.1'});
page.request('/serverlist').resolve([{id: '42', name: 'Lab'}]);
page.elements.get('#serverid').val('42');
vm.runInContext('$("#mode").val("download")', page.context);
page.elements.get('#test_form').handlers.submit.call(page.elements.get('#test_form')[0], {preventDefault() {}});
const start = page.request('/start/42/download');
assert.ok(start, 'The UI must queue a native background measurement rather than hold a long HTTP request');
start.resolve({result: 'started', run_id: 'a'.repeat(32)});
page.request('/status').resolve({status: 'completed', run_id: 'a'.repeat(32),
    results: [{serverid: 42, servername: 'Lab', download: 80, latency: 1, jitter: 0.1, mode: 'download'}]});
assert.equal(page.elements.get('#reportAct').properties.disabled, false);
assert.match(page.elements.get('#test_status').message, /saved in detailed history/);
const failed = fixture();
failed.request('/defaults').resolve(defaults);
failed.request('/settings/get').resolve({});
assert.equal(failed.elements.get('#save_settings').properties.disabled, true);
assert.equal(failed.elements.get('#settings_status').message, 'Unable to load server settings');
const viewerSource = fs.existsSync(process.argv[2] + '.viewer')
    ? fs.readFileSync(process.argv[2] + '.viewer', 'utf8').match(/<script>([\s\S]*?)<\/script>/)[1]
    : scriptTokens(rawScript, false);
const viewer = fixture(viewerSource);
viewer.request('/defaults').resolve(defaults);
assert.equal(viewer.elements.get('#reportAct').properties.disabled, true);
assert.equal(viewer.requests.some(r => r.options.url.includes('/schedule/')), false);
vm.runInContext('renderResults([{error:"failed",servername:"One"},{error:"failed",servername:"Two"}])', page.context);
assert.equal(page.elements.get('#latest_success').properties.hidden, true, 'An all-failed comparison must not show stale successful values');
console.log('Settings safeguards, stale history, units, queued completion, viewer controls and relative API URLs passed');
