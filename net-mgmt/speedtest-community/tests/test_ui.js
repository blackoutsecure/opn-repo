const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const markup = fs.readFileSync(process.argv[2], 'utf8');
const pluginLogo = '/ui/img/speedtest-community/speedtest-logo.png';
assert.ok(fs.existsSync(require('node:path').join(__dirname, '../src/opnsense/www/img/speedtest-community/speedtest-logo.png')),
          'The plugin logo must be included in the package source');
assert.ok(markup.includes(pluginLogo), 'The run header uses the packaged logo');
const rawScript = markup.match(/<script>([\s\S]*?)<\/script>/)[1];
const measurement = markup.slice(markup.indexOf('id="measurement"'), markup.indexOf('id="history"'));
const setup = markup.slice(markup.indexOf('id="setup"'), markup.indexOf('<script>'));
for (const [details] of markup.slice(0, markup.indexOf('<script>')).matchAll(/<details\b[^>]*>/g)) {
    assert.match(details, /\sopen(?:\s|>)/, 'Page disclosures open when their contents are available');
}
assert.ok(!measurement.includes('id="units"'), 'Throughput units are selected automatically');
const statusButton = measurement.match(/<button[^>]*id="check_status"[^>]*>/);
assert.ok(statusButton && /\shidden(?:\s|>)/.test(statusButton[0]),
          'The test status recovery action is hidden until needed');
assert.match(statusButton[0], /aria-describedby="test_status"/,
             'The recovery action is associated with its status message');
assert.ok(measurement.indexOf('id="check_status"') < measurement.indexOf('class="speedtest-readout"'),
          'The recovery action belongs with the status message, not the result readout');
assert.ok(!measurement.includes('id="duration"') && setup.includes('id="duration"'),
          'Measurement options belong in settings, not the run screen');
assert.ok(!measurement.includes('id="mode"') && setup.includes('id="mode"'),
          'Manual test mode belongs in Settings, not the run screen');
for (const control of ['serverid', 'speed_units', 'detect_server', 'serverlistAct']) {
    assert.ok(!measurement.includes(`id="${control}"`) && setup.includes(`id="${control}"`),
              control + ' belongs in Settings, not the run screen');
}
for (const section of ['catalog_panel', 'custom_servers_panel']) {
    const details = setup.match(new RegExp(`<details id="${section}"[^>]*>`));
    assert.ok(details && !/\shidden(?:\s|>)/.test(details[0]),
              section + ' is an independently expandable section, even with no servers enabled');
}
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
    const timers = new Map();
    let timerId = 0;
    function element(selector) {
        const result = {
            properties: {}, attributes: {}, handlers: {}, classes: new Set(), children: [],
            value: ({'#serverid': '0', '#speed_units': 'auto',
                '#history_days': '30', '#history_provider': 'librespeed',
                '#history_mode': 'all', '#history_server': 'all', '#history_outcome': 'all',
                '#history_origin': 'all', '#history_family': 'all', '#history_source': 'all'})[selector] || '', message: '',
            0: {id: typeof selector === 'string' && selector.startsWith('#') ? selector.slice(1) : '', listeners: {},
                addEventListener(event, handler) { this.listeners[event] = handler; }, reportValidity: () => true},
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
            on(events, handler) { events.split(' ').forEach(event => this.handlers[event] = handler); return this; },
            toggleClass(name, enabled) { enabled ? this.classes.add(name) : this.classes.delete(name); return this; },
            addClass(name) { this.classes.add(name); return this; },
            hasClass(name) { return this.classes.has(name); },
            attr(key, value) {
                if (value === undefined) return this.attributes[key];
                this.attributes[key] = value;
                return this;
            },
            removeAttr(key) { this.attributes[key] = null; return this; },
            empty() { this.children = []; return this; },
            append(child) {
                this.children.push(child);
                if (child && typeof child === 'object') child.parent = this;
                return this;
            },
            remove() { this.parent.children = this.parent.children.filter(child => child !== this); return this; },
            tab(action) { this.properties.tab = action; return this; },
            trigger(event) {
                this.properties.trigger = event;
                if (this.handlers[event]) this.handlers[event].call(this[0]);
                return this;
            }
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
        if (typeof selector === 'string' && selector.includes(', ')) {
            const matches = selector.split(', ').map($);
            return {
                prop(key, value) { matches.forEach(match => match.prop(key, value)); return this; },
                text(value) {
                    if (value === undefined) return matches.map(match => match.text()).join('');
                    matches.forEach(match => match.text(value));
                    return this;
                },
                toggleClass(name, enabled) { matches.forEach(match => match.toggleClass(name, enabled)); return this; },
                on(events, handler) { matches.forEach(match => match.on(events, handler)); return this; }
            };
        }
        if (!elements.has(selector)) {
            elements.set(selector, element(selector));
        }
        return elements.get(selector);
    }
    const tabIds = ['#measurement_tab', '#history_tab',
        ...(source.includes('const canSchedule = true;') ? ['#schedule_tab'] : []), '#setup_tab'];
    const tabElements = tabIds.map(id => $(id));
    $('#measurement').classes.add('active');
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
    const context = vm.createContext({$, URL, TypeError, window: {location: {reload() {}}, confirm: () => true},
        Chart: function(canvas, config) {
            chartConfigs.push(config);
            this.data = config.data;
            this.options = config.options;
            this.destroy = () => {};
            this.resize = () => {};
            this.update = () => {};
        },
        getComputedStyle: () => ({color: '#333'}), document: {body: {}, getElementById: () => ({})},
        setTimeout: (callback, delay) => { const id = ++timerId; timers.set(id, {callback, delay}); return id; },
        clearTimeout: id => timers.delete(id)});
    vm.runInContext(source, context);
    return {elements, requests, context, tabs, chartConfigs, timers,
        request: suffix => requests.findLast(r => r.options.url.endsWith(suffix))};
}
function runTimer(page, delay) {
    const entry = [...page.timers].find(([, timer]) => timer.delay === delay);
    assert.ok(entry, 'Expected a ' + delay + 'ms timer');
    page.timers.delete(entry[0]);
    entry[1].callback();
}
const defaults = {public_servers: '1', duration: '10', timeout: '15', concurrent: '3', chunks: '100', upload_size: '1024',
                  family: 'auto', source: '', exclude: '', icmp: '0', http2: '0', no_pre_allocate: '0', private_ca: '0'};
function completeDetection(page, name = 'Lab', alreadyStarted = false) {
    if (!alreadyStarted) page.elements.get('#detect_server').trigger('click');
    const detection = page.request('/detect');
    assert.ok(detection, 'The preview button starts an explicit latency probe');
    assert.equal(page.elements.get('#reportAct').properties.disabled, true);
    detection.resolve({result: 'started', run_id: 'd'.repeat(32)});
    page.request('/detectionstatus').resolve({status: 'completed', run_id: 'd'.repeat(32),
        results: [{serverid: 42, servername: name, latency: 2.5, jitter: 0.3, sponsor: 'Lab sponsor',
            connection: {ip: '192.0.2.9', isp: 'Example ISP'}}]});
    assert.equal(page.elements.get('#detected_server').message, '(42) ' + name);
    assert.equal(page.elements.get('#serverid').value, '42', 'The one-time scan selects its winning server');
    assert.equal(page.elements.get('#detection_status').message, 'Detected latency: 2.5 ms · Jitter: 0.3 ms');
    assert.equal(page.elements.get('#preview_details').properties.hidden, false);
    assert.equal(page.elements.get('#preview_details').properties.open, true, 'A new scan shows its connection details');
    assert.equal(detailValue(page, '#preview_details', 'Firewall IP seen by server'), '192.0.2.9');
}
function detailValue(page, section, label) {
    return detailField(page, section, label)?.message;
}
function detailField(page, section, label) {
    return page.elements.get(section + ' dl').children.find(entry => entry.children[0].message === label)?.children[1];
}
function openCatalog(page) {
    vm.runInContext('$("#setup").addClass("active"); $("#server_options").prop("open", true); $("#catalog_panel").prop("open", true)', page.context);
    page.elements.get('#setup_tab').trigger('shown.bs.tab');
}
function customServerRow(page, index = 0) {
    const [actions, nameCell, urlCell] = page.elements.get('#custom_server_rows').children[index].children;
    const [url, advanced] = urlCell.children;
    const advancedFields = advanced.children[1].children[1].children;
    return {remove: actions.children[0], name: nameCell.children[0], label: nameCell.children[1], url, advanced,
        id: advancedFields[0].children[0], downloadPath: advancedFields[2].children[0]};
}
function publicServerRow(page, index = 0) {
    const [checkbox, change] = page.elements.get('#catalog_rows').children[index].children[2].children[0].children;
    return {checkbox, change};
}
const page = fixture();
page.request('/defaults').resolve(defaults);
assert.equal(page.elements.get('#save_settings').properties.disabled, true);
page.elements.get('#save_settings').handlers.click();
assert.equal(page.requests.some(r => r.options.url.endsWith('/settings/set')), false,
             'Saving before the server GET completes must not overwrite saved configuration');
page.request('/settings/get').resolve({speedtest: {general: {servers: '[{"id":42}]'}}});
assert.equal(page.elements.get('#save_settings').properties.disabled, true, 'An unchanged form needs no saving');
assert.equal(page.elements.get('#public_servers').properties.checked, true);
for (const key of ['duration', 'timeout', 'concurrent', 'chunks', 'upload_size', 'family', 'source', 'exclude']) {
    page.elements.get('#' + key).val('custom');
}
for (const key of ['icmp', 'http2', 'no_pre_allocate', 'private_ca']) {
    page.elements.get('#' + key).prop('checked', true);
}
page.elements.get('#retention_days').val('365');
page.elements.get('#reset_measurement').trigger('click');
for (const [key, value] of Object.entries(defaults)) {
    if (['public_servers'].includes(key)) continue;
    if (['icmp', 'http2', 'no_pre_allocate', 'private_ca'].includes(key)) {
        assert.equal(page.elements.get('#' + key).properties.checked, false);
    } else {
        assert.equal(page.elements.get('#' + key).value, value, 'Reset measurement option ' + key);
    }
}
assert.equal(page.elements.get('#retention_days').value, '365', 'Reset must not change retention');
assert.equal(page.elements.get('#servers_json').value, '[{"id":42}]', 'Reset must not change server definitions');
assert.equal(page.requests.some(r => r.options.url.endsWith('/settings/set')), false,
             'Restoring values on the page must not save configuration');
page.elements.get('#retention_days').val('0');
page.elements.get('#open_test_settings').handlers.click({preventDefault() {}});
assert.equal(page.elements.get('#setup_tab').properties.tab, 'show');
assert.equal(page.elements.get('#measurement_settings_heading').properties.trigger, 'focus');
page.elements.get('#measurement_options_form')[0].reportValidity = () => false;
page.elements.get('#measurement_options_form')[0].listeners.invalid();
assert.equal(page.elements.get('#setup_tab').properties.tab, 'show',
             'Invalid measurement settings must be revealed before reporting the error');
assert.equal(page.elements.get('#measurement_options').properties.open, true);
page.elements.get('#save_settings').handlers.click();
assert.equal(page.requests.some(r => r.options.url.endsWith('/settings/set')), false,
             'Invalid measurement settings must not be saved');
page.elements.get('#measurement_options_form')[0].reportValidity = () => true;
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

const manager = fixture();
assert.equal(manager.request('/settings/catalog'), undefined);
vm.runInContext('$("#server_options").prop("open", true); $("#catalog_panel").prop("open", true)', manager.context);
manager.request('/defaults').resolve(defaults);
manager.request('/settings/get').resolve({speedtest: {general: {servers: ''}}});
assert.equal(manager.request('/settings/catalog'), undefined, 'An open disclosure in an inactive tab must not fetch the catalog');
assert.equal(manager.elements.get('#catalog_summary').message, 'All allowed');
assert.equal(manager.elements.get('#custom_summary').message, '0 configured');
const official = {id: '52', name: 'New York', server: 'https://nyc.example.net/', sponsorName: 'Clouvider',
    sponsorURL: 'https://www.clouvider.example/',
    dlURL: 'garbage.php', ulURL: 'empty.php', pingURL: 'empty.php', getIpURL: 'getIP.php'};
openCatalog(manager);
manager.request('/settings/catalog').resolve({servers: [official]});
assert.equal(manager.elements.get('#catalog_rows').children.length, 1);
const catalogSponsor = manager.elements.get('#catalog_rows').children[0].children[1].children[0];
assert.equal(catalogSponsor.message, 'Clouvider');
assert.equal(catalogSponsor.attributes.href, official.sponsorURL);
manager.elements.get('#catalog_search').val('missing').handlers.input();
assert.equal(manager.elements.get('#catalog_no_matches').properties.hidden, false);
manager.elements.get('#catalog_search').val('clouvider').handlers.input();
assert.equal(publicServerRow(manager).checkbox.properties.checked, true);
publicServerRow(manager).checkbox.trigger('change');
assert.equal(vm.runInContext('publicSelection', manager.context), 'none');
assert.equal(publicServerRow(manager).checkbox.properties.checked, false);
assert.equal(publicServerRow(manager).change.message, 'Changed');
assert.equal(manager.elements.get('#catalog_pending').properties.hidden, false);
publicServerRow(manager).checkbox.trigger('change');
assert.equal(vm.runInContext('publicSelection', manager.context), '52');
manager.elements.get('#add_custom_server').trigger('click');
const firstRow = customServerRow(manager);
assert.equal(firstRow.name.properties.trigger, 'focus');
assert.equal(firstRow.label.message, 'Added');
assert.equal(manager.elements.get('#custom_summary').message, '1 configured');
assert.equal(manager.elements.get('#custom_pending').properties.hidden, false);
assert.equal(firstRow.advanced.properties.open, true, 'Endpoint options open by default for custom rows');
manager.elements.get('#save_settings').trigger('click');
assert.equal(manager.request('/settings/set'), undefined, 'An incomplete inline row must not be submitted');
assert.match(manager.elements.get('#custom_server_status').message, /server name/);
firstRow.name.val('My New York').trigger('input');
firstRow.url.val('https://custom.example.net/').trigger('input');
const custom = {id: 10000, name: 'My New York', server: 'https://custom.example.net/',
    dlURL: 'garbage.php', ulURL: 'empty.php', pingURL: 'empty.php', getIpURL: 'getIP.php'};
assert.deepEqual(JSON.parse(manager.elements.get('#servers_json').value), [custom]);
manager.elements.get('#catalog_refresh').handlers.click();
manager.request('/settings/catalog').resolve({servers: [{...official, name: 'Updated upstream'}]});
assert.equal(JSON.parse(manager.elements.get('#servers_json').value)[0].name, 'My New York');
assert.equal(vm.runInContext('publicSelection', manager.context), '52', 'Catalog refresh preserves selected IDs');
manager.elements.get('#catalog_search').val('').handlers.input();
manager.elements.get('#catalog_refresh').handlers.click();
manager.request('/settings/catalog').resolve({servers: [official, {...official, id: '84', name: 'New official', server: 'https://other.example.net/'}]});
assert.equal(publicServerRow(manager, 1).checkbox.properties.checked, false,
             'A restrictive allow-list must not automatically allow newly published servers');
firstRow.url.val('https://user:password@custom.example.net/').trigger('input');
manager.elements.get('#save_settings').trigger('click');
assert.equal(manager.request('/settings/set'), undefined, 'Credentials in the backend URL must not be submitted');
assert.match(manager.elements.get('#custom_server_status').message, /without credentials/);
firstRow.url.val(custom.server).trigger('input');
manager.elements.get('#add_custom_server').trigger('click');
const secondRow = customServerRow(manager, 1);
secondRow.name.val('Second site').trigger('input');
secondRow.url.val('https://second.example.net/').trigger('input');
secondRow.id.val(String(custom.id)).trigger('input');
manager.elements.get('#save_settings').trigger('click');
assert.equal(manager.request('/settings/set'), undefined, 'Duplicate inline IDs must not be submitted');
assert.match(manager.elements.get('#custom_server_status').message, /Server row 2: .*unique positive/);
assert.equal(secondRow.advanced.properties.open, true, 'An invalid advanced field must be revealed');
assert.equal(manager.elements.get('#custom_servers_panel').properties.open, true);
secondRow.remove.trigger('click');
assert.deepEqual(JSON.parse(manager.elements.get('#servers_json').value), [custom], 'Remove preserves other inline edits');
manager.elements.get('#public_servers').prop('checked', false).handlers.change();
assert.equal(manager.elements.get('#catalog_table').properties.hidden, true);
assert.equal(manager.elements.get('#catalog_panel').properties.open, true, 'Turning off the catalog must not collapse its settings');
assert.equal(manager.elements.get('#catalog_summary').message, 'Off');
assert.equal(manager.elements.get('#catalog_refresh').properties.disabled, true, 'Opting out prevents catalog fetches');
assert.equal(manager.requests.filter(r => r.options.url.endsWith('/settings/catalog')).length, 3);
assert.equal(manager.request('/settings/set'), undefined, 'Catalog and custom edits remain unsaved until Save settings');
manager.elements.get('#save_settings').handlers.click();
const customSave = manager.request('/settings/set').options.data.speedtest.general;
assert.equal(customSave.public_servers, '0');
assert.equal(customSave.public_selection, '52');
assert.equal(customSave.combine_servers, '0');
assert.equal(JSON.parse(customSave.servers)[0].name, 'My New York');

const approvedManager = fixture();
approvedManager.request('/defaults').resolve(defaults);
approvedManager.request('/settings/get').resolve({speedtest: {general: {
    servers: JSON.stringify([{...custom, dlURL: 'backend/download'}]), public_selection: '52,84', combine_servers: '1'
}}});
const existingRow = customServerRow(approvedManager);
existingRow.name.val('Renamed site').trigger('input');
assert.equal(JSON.parse(approvedManager.elements.get('#servers_json').value)[0].id, custom.id, 'Editing a name retains the saved ID');
assert.equal(existingRow.downloadPath.val(), 'backend/download', 'Existing endpoint overrides remain editable');
assert.equal(existingRow.label.message, 'Edited');
approvedManager.elements.get('#discard_settings').trigger('click');
assert.equal(customServerRow(approvedManager).name.val(), custom.name, 'Discard restores the saved inline row');
assert.equal(customServerRow(approvedManager).label.properties.hidden, true);
assert.equal(approvedManager.elements.get('#custom_pending').properties.hidden, true);
assert.equal(approvedManager.request('/settings/set'), undefined);
approvedManager.context.window.confirm = () => false;
customServerRow(approvedManager).remove.trigger('click');
assert.equal(approvedManager.elements.get('#custom_server_rows').children.length, 1, 'Removing the last saved row can be canceled');
approvedManager.context.window.confirm = () => true;
customServerRow(approvedManager).remove.trigger('click');
assert.equal(approvedManager.elements.get('#servers_json').value, '', 'Removing the last row restores the fallback only after saving');
approvedManager.elements.get('#discard_settings').trigger('click');
approvedManager.elements.get('#servers_json').val(JSON.stringify([{...custom, name: 'Raw edit'}])).trigger('input');
assert.equal(customServerRow(approvedManager).name.val(), 'Raw edit', 'Raw JSON edits refresh the inline rows');
approvedManager.elements.get('#discard_settings').trigger('click');
assert.equal(approvedManager.elements.get('#combine_servers').properties.checked, true);
openCatalog(approvedManager);
approvedManager.request('/settings/catalog').resolve({servers: [official]});
assert.equal(approvedManager.elements.get('#catalog_rows').children.length, 2,
             'Missing approved IDs stay visible for removal');
publicServerRow(approvedManager, 1).checkbox.trigger('change');
assert.equal(vm.runInContext('publicSelection', approvedManager.context), '52');
approvedManager.elements.get('#save_settings').handlers.click();
assert.equal(approvedManager.request('/settings/set').options.data.speedtest.general.combine_servers, '1');
approvedManager.request('/settings/set').resolve({result: 'failed'});
const previouslySubmitted = approvedManager.request('/settings/set');
const customDraft = approvedManager.elements.get('#servers_json').value;
approvedManager.elements.get('#public_servers').prop('checked', false).trigger('change');
assert.equal(approvedManager.elements.get('#catalog_reset').properties.disabled, false,
             'The allow-list can be reset without enabling the catalog');
approvedManager.elements.get('#catalog_reset').trigger('click');
assert.equal(vm.runInContext('publicSelection', approvedManager.context), 'all');
assert.equal(approvedManager.elements.get('#public_servers').properties.checked, false);
assert.equal(approvedManager.elements.get('#servers_json').value, customDraft);
assert.equal(approvedManager.request('/settings/set'), previouslySubmitted, 'Reset never saves on its own');
approvedManager.elements.get('#public_servers').prop('checked', true).trigger('change');
approvedManager.elements.get('#catalog_allow_none').trigger('click');
assert.equal(vm.runInContext('publicSelection', approvedManager.context), 'none');

const retentionPage = fixture();
retentionPage.request('/defaults').resolve({...defaults, retention_days: '0', history_limit: '0'});
retentionPage.request('/settings/get').resolve({speedtest: {general: {servers: ''}}});
assert.equal(retentionPage.elements.get('#retention_days').value, '0', 'Saved unlimited age must not be reset on page load');
assert.equal(retentionPage.elements.get('#history_limit').value, '0', 'Saved unlimited count must not be reset on page load');
retentionPage.elements.get('#reset_retention').handlers.click();
assert.equal(retentionPage.elements.get('#retention_days').value, '31');
assert.equal(retentionPage.elements.get('#history_limit').value, '10000');
assert.equal(retentionPage.request('/settings/set'), undefined, 'Recommended retention must not save or prune immediately');
retentionPage.context.window.confirm = () => false;
retentionPage.elements.get('#save_settings').handlers.click();
assert.equal(retentionPage.request('/settings/set'), undefined, 'Enabling pruning over saved unlimited retention requires confirmation');
retentionPage.context.window.confirm = () => true;
retentionPage.elements.get('#save_settings').handlers.click();
assert.equal(retentionPage.request('/settings/set').options.data.speedtest.general.retention_days, '31');
assert.equal(retentionPage.request('/settings/set').options.data.speedtest.general.history_limit, '10000');
retentionPage.request('/settings/set').resolve({result: 'saved'});
assert.equal(retentionPage.elements.get('#save_settings').properties.disabled, true);
assert.equal(retentionPage.elements.get('#settings_status').message, 'Settings saved.');
retentionPage.elements.get('#retention_days').val('7');
retentionPage.elements.get('#retention_form').trigger('change');
retentionPage.elements.get('#discard_settings').trigger('click');
assert.equal(retentionPage.elements.get('#retention_days').value, '31',
             'Discard restores the last confirmed saved values without a page reload');
assert.equal(retentionPage.elements.get('#discard_settings').properties.hidden, true);

vm.runInContext('historyReload()', page.context);
const staleHistory = page.request('/history');
vm.runInContext('historyReload()', page.context);
page.request('/history').resolve({error: 'Current history failed'});
staleHistory.resolve({error: 'Stale history failed'});
assert.equal(page.elements.get('#history_status').message, 'Current history failed',
             'A stale response must not overwrite the current history state');
assert.equal(vm.runInContext('metricValue("upload", null)', page.context), 'Not measured');
for (const [value, expected] of [[0, '0 Mbps'], [0.0005, '500 bps'], [0.001, '1 kbps'],
    [0.75, '750 kbps'], [1, '1 Mbps'], [999, '999 Mbps'], [1000, '1 Gbps'], [1500, '1.5 Gbps']]) {
    assert.equal(vm.runInContext(`speed(${value})`, page.context), expected);
}
const display = fixture();
vm.runInContext('renderResults([{servername:"Lab",download:800,upload:3,latency:12}])', display.context);
assert.equal(display.elements.get('#download').message, '800 Mbps');
display.elements.get('#speed_units').val('Gbps').trigger('change');
assert.equal(display.elements.get('#download').message, '0.8 Gbps');
assert.equal(display.elements.get('#upload').message, '<0.01 Gbps');
assert.equal(display.elements.get('#latency').message, '12 ms');
assert.equal(vm.runInContext('speed(0)', display.context), '0 Gbps');
vm.runInContext('renderCharts({series:[{epoch:1700000000,download:800}]})', display.context);
assert.equal(display.chartConfigs[0].options.scales.y.title.text, 'Gbps');
assert.equal(display.chartConfigs[0].data.datasets[0].data[0].y, 0.8);
display.elements.get('#speed_units').val('auto').trigger('change');
assert.equal(display.elements.get('#download').message, '800 Mbps');
page.request('/status').resolve({status: 'idle'});
page.request('/version').resolve({message: 'librespeed-cli v1.2.1 (built on 1970-01-01 00:00:00 UTC)'});
assert.equal(page.elements.get('#version').message, 'v1.2.1');
assert.equal(page.elements.get('#engine_status')?.message ?? '', '');
page.request('/serverlist').resolve([{id: '42', name: 'Lab'}]);
assert.equal(page.request('/detect'), undefined, 'Opening the page must not probe test servers');
assert.equal(page.elements.get('#reportAct').properties.disabled, false, 'Running a test needs no preview');
completeDetection(page);
page.elements.get('#serverid').val('custom').trigger('change');
page.elements.get('#custom_servers').val('42,84').trigger('input');
assert.equal(page.elements.get('#custom_server_group').properties.hidden, false);
assert.equal(page.elements.get('#comparison_warning').properties.hidden, false);
assert.equal(page.elements.get('#server_preview').properties.hidden, true);
page.elements.get('#serverid').val('42').trigger('change');
assert.equal(page.elements.get('#custom_server_group').properties.hidden, true);
assert.equal(page.elements.get('#custom_servers').value, '', 'Leaving custom selection resets the unused IDs');
page.elements.get('#serverid').val('42');
vm.runInContext('$("#mode").val("download")', page.context);
vm.runInContext('renderResults([{serverid:42,servername:"Old",download:50}])', page.context);
page.elements.get('#test_form').handlers.submit.call(page.elements.get('#test_form')[0], {preventDefault() {}});
const start = page.request('/start/42/download');
assert.ok(start, 'The UI must queue a native background measurement rather than hold a long HTTP request');
assert.equal(page.elements.get('#download').message, '50 Mbps', 'Keep the old result until the new run is accepted');
assert.equal(page.elements.get('#preview_details').properties.hidden, true, 'A new test clears the preview');
start.resolve({result: 'started', run_id: 'a'.repeat(32)});
assert.equal(page.elements.get('#test_metrics').properties.hidden, true, 'An accepted run drops the old measurements');
assert.equal(page.elements.get('#result_meta').properties.hidden, true);
page.request('/status').resolve({status: 'running', run_id: 'a'.repeat(32), phase: 'download',
    mode: 'download', server: 'Lab', total: 1, progress: 50, deadline: Date.now() / 1000 + 60,
    samples: {download: [{seconds: 1, mbps: 20}, {seconds: 2, mbps: 40}], upload: []}});
assert.equal(page.elements.get('#run_progress').properties.hidden, false);
assert.equal(page.elements.get('#phase_progress').value, 50);
assert.equal(page.elements.get('#upload_metric').properties.hidden, true);
assert.equal(page.elements.get('#download').message, '40 Mbps');
assert.equal(page.elements.get('#download_scale').message, '50 Mbps');
assert.equal(page.elements.get('#download_needle').attributes.transform, 'rotate(54 110 110)');
assert.equal(page.elements.get('#upload_needle').attributes.opacity, '0');
assert.equal(page.elements.get('#live_chart_region').properties.hidden, false);
assert.equal(page.chartConfigs[0].data.datasets[0].data.length, 2);
assert.equal(page.chartConfigs[0].options.scales.y.title.text, 'Mbps');
vm.runInContext(`renderLive({status:'running', mode:'download', phase:'download',
    samples:{download:[{seconds:1,mbps:40},{seconds:2,mbps:1200}]}})`, page.context);
assert.equal(page.elements.get('#download').message, '1.2 Gbps');
assert.equal(page.elements.get('#download_scale').message, '2 Gbps');
vm.runInContext('renderGauge("download", 40, true)', page.context);
assert.equal(page.elements.get('#download_scale').message, '2 Gbps',
             'A live gauge keeps its expanded range when speed falls instead of misleadingly advancing its needle');
assert.equal(page.chartConfigs[0].options.scales.y.title.text, 'Gbps');
assert.equal(vm.runInContext('liveChart.data.datasets[0].data[0].y', page.context), 0.04,
             'A live unit change must rescale earlier samples onto the same axis');
vm.runInContext(`followStatus('${'a'.repeat(32)}')`, page.context);
page.request('/status').resolve({status: 'completed', run_id: 'a'.repeat(32),
    phase: 'finished', server: 'Lab', samples: {download: [{seconds: 2, mbps: 40}], upload: []},
    results: [{serverid: 42, servername: 'Atlanta, United States (New sponsor)', download: 80, latency: 1, jitter: 0, mode: 'download',
        timestamp: '2026-01-02T03:04:05.000Z', bytes_received: 1048576, tls: {version: 'TLS 1.3', cipher: 'TLS_AES_256_GCM_SHA384'},
        sponsor: 'New sponsor', sponsor_url: 'https://partner.example.net/', connection: {ip: '2001:db8::1', isp: 'New ISP'}}]});
assert.equal(page.elements.get('#reportAct').properties.disabled, false);
assert.match(page.elements.get('#test_status').message, /Result saved to history/);
assert.equal(page.elements.get('#download').message, '80 Mbps');
assert.equal(page.elements.get('#result_time').attributes.datetime, '2026-01-02T03:04:05.000Z');
assert.equal(page.elements.get('#result_meta').properties.hidden, false);
assert.equal(page.elements.get('#result_details').properties.open, true, 'Test details open on a new result');
assert.equal(detailValue(page, '#result_details', 'Test server'), 'Atlanta, United States');
assert.deepEqual(page.elements.get('#result_details dl').children.slice(0, 2).map(entry => entry.children[0].message),
                 ['Test server', 'Server sponsor'], 'The server appears immediately before its sponsor');
const resultSponsor = detailField(page, '#result_details', 'Server sponsor').children[0];
assert.equal(resultSponsor.message, 'New sponsor');
assert.equal(resultSponsor.attributes.href, 'https://partner.example.net/');
assert.equal(resultSponsor.attributes.target, '_blank');
assert.equal(resultSponsor.attributes.rel, 'noopener noreferrer');
assert.equal(detailValue(page, '#result_details', 'Firewall IP seen by server'), '2001:db8::1');
assert.equal(detailValue(page, '#result_details', 'ISP / network'), 'New ISP');
assert.equal(detailValue(page, '#result_details', 'Received'), '1 MiB');
assert.equal(detailField(page, '#result_details', 'Probe TLS'), undefined, 'Probe TLS metadata is not displayed');
assert.equal(detailValue(page, '#result_details', 'Sent'), undefined);
assert.equal(page.elements.get('#upload_metric').properties.hidden, true);
assert.equal(page.elements.get('#jitter').message, '0 ms', 'Zero is a measured value');
assert.equal(page.elements.get('#jitter_metric').properties.hidden, false);
assert.equal(page.elements.get('#live_chart_region').properties.hidden, true, 'The live chart closes after completion');
const previousResult = page.elements.get('#download').message;
page.elements.get('#serverid').val('0');
page.elements.get('#serverlistAct').handlers.click();
page.request('/serverlist').resolve([{id: '42', name: 'Lab'}]);
assert.equal(page.requests.filter(r => r.options.url.endsWith('/detect')).length, 1,
             'Reloading the list must not start another probe');
page.elements.get('#detect_server').trigger('click');
assert.equal(page.requests.filter(r => r.options.url.endsWith('/detect')).length, 2,
             'An explicit preview always runs a fresh latency check');
page.request('/detect').resolve({result: 'started', run_id: 'e'.repeat(32)});
page.request('/detectionstatus').resolve({status: 'failed', run_id: 'e'.repeat(32),
    error: 'Speedtest failed: No reachable servers'});
assert.equal(page.elements.get('#detected_server').message, '');
assert.equal(page.elements.get('#preview_details').properties.hidden, true);
assert.equal(page.elements.get('#detection_status').message, 'No reachable servers');
assert.equal(page.elements.get('#download').message, previousResult, 'Detection must not replace the last test readout');
assert.equal(page.elements.get('#reportAct').properties.disabled, false);
page.elements.get('#measurement_options_form').handlers.change();
page.elements.get('a[href="#measurement"]').handlers['shown.bs.tab']();
assert.equal(page.requests.filter(r => r.options.url.endsWith('/detect')).length, 2,
             'Returning from edited advanced settings does not automatically probe');
page.elements.get('#detect_server').trigger('click');
page.request('/detect').reject();
assert.match(page.elements.get('#detection_status').message, /response lost/);
assert.equal(page.elements.get('#reportAct').properties.disabled, false);
vm.runInContext('renderGauge("download", 0)', page.context);
assert.equal(page.elements.get('#download_needle').attributes.opacity, '1', 'A measured zero still has a needle');
assert.equal(page.elements.get('#download_arc').attributes['stroke-dasharray'], '0 100');
vm.runInContext('renderGauge("download", null)', page.context);
assert.equal(page.elements.get('#download_needle').attributes.opacity, '0', 'A missing value is not a measured zero');

const live = fixture();
vm.runInContext(`renderLive({status:'running', mode:'both', phase:'selecting', server:'Lab',
    samples:{download:[],upload:[]}})`, live.context);
assert.equal(live.elements.get('#phase_progress').attributes.value, null,
             'Server selection has indeterminate progress');
vm.runInContext(`renderLive({status:'running', mode:'both', phase:'ping', server:'Lab',
    samples:{download:[],upload:[]}})`, live.context);
assert.equal(live.elements.get('#phase_progress').attributes.value, null,
             'Latency has indeterminate progress');
vm.runInContext(`renderLive({status:'running', mode:'both', phase:'upload', progress:25, server:'Lab',
    samples:{download:[{seconds:1,mbps:80}],upload:[{seconds:1,mbps:24}]}})`, live.context);
assert.equal(live.elements.get('#phase_progress').value, 25);
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
assert.equal(race.request('/detect'), undefined, 'Detection waits for any active measurement to finish');
assert.equal(race.elements.get('#serverlistAct').properties.disabled, true);
vm.runInContext('followStatus()', race.context);
race.request('/status').resolve({status: 'completed', results: []});
completeDetection(race);
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
completeDetection(busy);
assert.equal(busy.elements.get('#reportAct').properties.disabled, false,
             'Controls must recover when the other run finishes');

vm.runInContext('followStatus()', busy.context);
busy.request('/status').resolve({status: 'busy'});
vm.runInContext('followStatus()', busy.context);
busy.request('/status').resolve({status: 'completed', results: [
    {serverid: 42, servername: 'Earlier', download: 80, latency: 1, jitter: 0}]});
assert.equal(busy.elements.get('#test_status').message, '',
             'An unrelated operation must not announce an old test as newly completed');
assert.equal(busy.elements.get('#download').message, '80 Mbps');
assert.equal(busy.elements.get('#deletelogAct').properties.disabled, false);

vm.runInContext('followStatus()', busy.context);
busy.request('/status').resolve({status: 'busy'});
vm.runInContext('followStatus()', busy.context);
busy.request('/status').resolve({status: 'failed', error: 'Speedtest failed: Older failure', results: []});
assert.equal(busy.elements.get('#test_status').message, 'Older failure');

vm.runInContext('followStatus()', busy.context);
busy.request('/status').resolve({status: 'busy'});
vm.runInContext(`followStatus('${'b'.repeat(32)}')`, busy.context);
busy.request('/status').resolve({status: 'completed', run_id: 'b'.repeat(32), results: []});
assert.match(busy.elements.get('#test_status').message, /Test complete\. Result saved to history/,
             'A queued test that owns the completed run must retain its completion message');

const automaticStatus = fixture();
automaticStatus.request('/defaults').resolve(defaults);
automaticStatus.request('/version').resolve({message: 'librespeed-cli v1.2.1'});
automaticStatus.request('/serverlist').resolve([{id: '42', name: 'Lab'}]);
automaticStatus.request('/status').resolve({status: 'idle'});
completeDetection(automaticStatus);
assert.equal(automaticStatus.elements.get('#check_status').properties.hidden, true,
             'A healthy status needs no refresh control');
runTimer(automaticStatus, 30000);
automaticStatus.request('/status').resolve({status: 'running', run_id: 'c'.repeat(32), phase: 'download',
    mode: 'both', server: 'Lab', total: 1, progress: 10, deadline: Date.now() / 1000 + 60,
    samples: {download: [{seconds: 1, mbps: 1500}], upload: []}});
assert.equal(automaticStatus.elements.get('#download').message, '1.5 Gbps',
             'An externally started test is picked up and its units are scaled automatically');
assert.equal(automaticStatus.elements.get('#check_status').properties.hidden, true);
assert.equal(automaticStatus.elements.get('#reportAct').properties.disabled, true);
runTimer(automaticStatus, 1500);
const externalResult = {status: 'completed', run_id: 'c'.repeat(32), updated: 123,
    results: [{serverid: 42, servername: 'Earlier', download: 1200, latency: 1}]};
automaticStatus.request('/status').resolve(externalResult);
assert.equal(automaticStatus.elements.get('#download').message, '1.2 Gbps');
assert.equal(automaticStatus.elements.get('#reportAct').properties.disabled, false);

runTimer(automaticStatus, 30000);
automaticStatus.elements.get('#serverlistAct').handlers.click();
automaticStatus.request('/serverlist').resolve([{id: '42', name: 'Lab'}]);
automaticStatus.elements.get('#detect_server').trigger('click');
automaticStatus.request('/status').resolve({status: 'busy'});
assert.doesNotMatch(automaticStatus.elements.get('#test_status').message, /another test/i,
                    'An in-flight idle check must not mistake our server scan for another test');
completeDetection(automaticStatus, 'Lab', true);
vm.runInContext('historyLoaded = true', automaticStatus.context);
runTimer(automaticStatus, 30000);
automaticStatus.request('/status').resolve(externalResult);
assert.equal(detailValue(automaticStatus, '#preview_details', 'Firewall IP seen by server'), '192.0.2.9',
             'Unchanged status polls must not overwrite newly detected connection details');
assert.equal(vm.runInContext('historyLoaded', automaticStatus.context), true,
             'Unchanged status polls must not invalidate loaded history');
automaticStatus.elements.get('#mode').val('latency');
automaticStatus.elements.get('#measurement_options_form').handlers.change({target: {id: 'mode'}});
assert.equal(automaticStatus.elements.get('#run_overrides').properties.hidden, false);
assert.match(automaticStatus.elements.get('#open_test_settings').message, /Test mode: Latency/);
assert.equal(automaticStatus.elements.get('#throughput_warning').properties.hidden, true);
assert.equal(automaticStatus.elements.get('#preview_details').properties.hidden, false,
             'Changing the manual test mode does not invalidate a latency preview');
automaticStatus.elements.get('#measurement').classes.delete('active');
automaticStatus.elements.get('#duration').val('8');
automaticStatus.elements.get('#measurement_options_form').trigger('input');
assert.equal(automaticStatus.elements.get('#server_preview').properties.hidden, true,
             'Editing a measurement option removes the old preview');
assert.equal(automaticStatus.elements.get('#run_overrides').properties.hidden, false);
automaticStatus.elements.get('#restore_measurement').trigger('click');
assert.equal(automaticStatus.elements.get('#duration').value, '10');
assert.equal(automaticStatus.elements.get('#mode').value, 'both', 'Reset restores the full manual test mode');
assert.equal(automaticStatus.elements.get('#open_test_settings').message, 'Server: Lab',
             'Resetting measurement options must not release the selected server');
automaticStatus.elements.get('#serverid').val('0').trigger('change');
assert.equal(automaticStatus.elements.get('#run_overrides').properties.hidden, true);
const detections = automaticStatus.requests.filter(r => r.options.url.endsWith('/detect')).length;
runTimer(automaticStatus, 30000);
automaticStatus.request('/status').resolve(externalResult);
assert.equal(automaticStatus.requests.filter(r => r.options.url.endsWith('/detect')).length, detections,
             'Idle status checks must not initiate scans while the user is editing settings');
automaticStatus.elements.get('#measurement').classes.add('active');
automaticStatus.elements.get('a[href="#measurement"]').handlers['shown.bs.tab']();
assert.equal(automaticStatus.requests.filter(r => r.options.url.endsWith('/detect')).length, detections,
             'Returning to the run tab must not automatically re-probe');
const statusRequests = automaticStatus.requests.filter(r => r.options.url.endsWith('/status')).length;
vm.runInContext('document.hidden = true', automaticStatus.context);
runTimer(automaticStatus, 30000);
assert.equal(automaticStatus.requests.filter(r => r.options.url.endsWith('/status')).length, statusRequests,
             'Idle polling pauses while the browser tab is hidden');
vm.runInContext('document.hidden = false', automaticStatus.context);
vm.runInContext('$(document).handlers.visibilitychange()', automaticStatus.context);
assert.equal(automaticStatus.requests.filter(r => r.options.url.endsWith('/status')).length, statusRequests + 1,
             'Returning to the browser tab refreshes status immediately');
automaticStatus.request('/status').resolve(externalResult);
runTimer(automaticStatus, 30000);
automaticStatus.request('/status').resolve({status: 'idle'});
assert.equal(automaticStatus.elements.get('#download').message, 'Not measured',
             'An externally cleared result disappears on the next status check');
assert.equal(automaticStatus.elements.get('#test_status').message, '',
             'A cleared result must not retain a stale completion message');

const recovery = fixture();
recovery.request('/defaults').resolve(defaults);
recovery.request('/version').resolve({message: 'librespeed-cli v1.2.1'});
recovery.request('/serverlist').resolve([{id: '42', name: 'Lab'}]);
recovery.request('/status').resolve({status: 'idle'});
completeDetection(recovery);
runTimer(recovery, 30000);
recovery.request('/status').reject();
assert.match(recovery.elements.get('#test_status').message, /Retrying/);
assert.equal(recovery.elements.get('#reportAct').properties.disabled, true,
             'A new test must not start when its current status is unknown');
runTimer(recovery, 3000);
recovery.request('/status').reject();
runTimer(recovery, 3000);
recovery.request('/status').reject();
assert.equal(recovery.elements.get('#check_status').properties.hidden, false);
assert.equal(recovery.elements.get('#check_status').properties.disabled, false);
recovery.elements.get('#check_status').handlers.click();
assert.equal(recovery.elements.get('#check_status').properties.disabled, true,
             'Only one manual status check may be requested at a time');
recovery.request('/status').resolve({error: 'Status snapshot is invalid'});
assert.equal(recovery.elements.get('#check_status').properties.hidden, false);
assert.equal(recovery.elements.get('#check_status').properties.disabled, false);
assert.equal(recovery.elements.get('#test_status').message, 'Status snapshot is invalid');
recovery.elements.get('#check_status').handlers.click();
recovery.request('/status').resolve({status: 'idle'});
assert.equal(recovery.elements.get('#check_status').properties.hidden, true);
assert.equal(recovery.elements.get('#test_status').message, '');
assert.equal(recovery.elements.get('#reportAct').properties.disabled, false);

runTimer(recovery, 30000);
recovery.request('/status').reject();
runTimer(recovery, 3000);
recovery.request('/status').resolve({status: 'idle'});
assert.equal(recovery.elements.get('#test_status').message, '',
             'A successful automatic retry clears the temporary connection error');
assert.equal(recovery.elements.get('#check_status').properties.hidden, true);
runTimer(recovery, 30000);
recovery.request('/status').resolve({status: 'running', run_id: 'f'.repeat(32), phase: 'ping',
    server: 'Lab', total: 1, deadline: Date.now() / 1000 - 60});
assert.equal(recovery.elements.get('#check_status').properties.hidden, false,
             'An overdue test offers a way to check its status again');
assert.equal(recovery.elements.get('#reportAct').properties.disabled, true);
recovery.elements.get('#check_status').handlers.click();
recovery.request('/status').resolve({status: 'completed', run_id: 'f'.repeat(32), results: []});
assert.equal(recovery.elements.get('#check_status').properties.hidden, true);
assert.equal(recovery.elements.get('#reportAct').properties.disabled, false);

const restored = fixture();
restored.request('/defaults').resolve(defaults);
restored.request('/version').resolve({message: 'librespeed-cli v1.2.1'});
restored.request('/serverlist').resolve([{id: '42', name: 'Lab'}]);
restored.request('/status').resolve({status: 'idle'});
restored.elements.get('#detect_server').trigger('click');
const abandonedDetection = restored.request('/detect');
vm.runInContext('$(window).handlers.pagehide()', restored.context);
vm.runInContext('$(window).handlers.pageshow({originalEvent: {persisted: true}})', restored.context);
const restoreStatusRequests = restored.requests.filter(r => r.options.url.endsWith('/status')).length;
vm.runInContext('$(document).handlers.visibilitychange()', restored.context);
assert.equal(restored.requests.filter(r => r.options.url.endsWith('/status')).length, restoreStatusRequests,
             'Restoring a visible page must not duplicate the status request already in flight');
abandonedDetection.resolve({result: 'started', run_id: 'd'.repeat(32)});
assert.equal(restored.request('/detectionstatus'), undefined, 'A stale detection response cannot resume after page restore');
restored.request('/status').resolve({status: 'busy'});
runTimer(restored, 1500);
restored.request('/status').resolve({status: 'idle'});
assert.equal(restored.elements.get('#server_preview').properties.hidden, true);
assert.equal(restored.requests.filter(r => r.options.url.endsWith('/detect')).length, 1,
             'Restoring the page may resume status polling, not start new probes');
completeDetection(restored);
assert.equal(restored.elements.get('#reportAct').properties.disabled, false,
             'Returning from the browser back/forward cache resumes status and server detection');

const restoredStarting = fixture();
restoredStarting.request('/defaults').resolve(defaults);
restoredStarting.request('/version').resolve({message: 'librespeed-cli v1.2.1'});
restoredStarting.request('/serverlist').resolve([{id: '42', name: 'Lab'}]);
restoredStarting.request('/status').resolve({status: 'idle'});
restoredStarting.elements.get('#test_form').handlers.submit.call(
    restoredStarting.elements.get('#test_form')[0], {preventDefault() {}});
const pendingStart = restoredStarting.request('/start/0/both');
assert.ok(pendingStart, 'A new page submits a full test without opening Settings');
vm.runInContext('$(window).handlers.pagehide()', restoredStarting.context);
vm.runInContext('$(window).handlers.pageshow({originalEvent: {persisted: true}})', restoredStarting.context);
restoredStarting.request('/status').resolve({status: 'idle'});
assert.equal(restoredStarting.elements.get('#reportAct').properties.disabled, true,
             'A restored idle snapshot must not permit another test while a start response is pending');
restoredStarting.elements.get('#test_form').handlers.submit.call(
    restoredStarting.elements.get('#test_form')[0], {preventDefault() {}});
assert.equal(restoredStarting.requests.filter(r => r.options.url.includes('/start/')).length, 1);
const refreshes = restoredStarting.requests.filter(r => r.options.url.endsWith('/serverlist')).length;
restoredStarting.elements.get('#serverlistAct').handlers.click();
assert.equal(restoredStarting.requests.filter(r => r.options.url.endsWith('/serverlist')).length, refreshes,
             'Server refresh stays disabled until the start response arrives');
pendingStart.resolve({result: 'started', run_id: 'a'.repeat(32)});
restoredStarting.request('/status').resolve({status: 'running', run_id: 'a'.repeat(32),
    phase: 'ping', server: 'Lab', total: 1, deadline: Date.now() / 1000 + 60});
assert.equal(restoredStarting.elements.get('#reportAct').properties.disabled, true);

const optionsPage = fixture();
optionsPage.request('/defaults').resolve(defaults);
optionsPage.request('/version').resolve({message: 'librespeed-cli v1.2.1'});
optionsPage.request('/serverlist').resolve([{id: '42', name: 'Lab'}, {id: '84', name: 'Other'}]);
optionsPage.request('/status').resolve({status: 'idle'});
optionsPage.elements.get('#measurement_options_form')[0].reportValidity = () => false;
optionsPage.elements.get('#test_form').handlers.submit.call(optionsPage.elements.get('#test_form')[0], {preventDefault() {}});
assert.equal(optionsPage.requests.some(r => r.options.url.includes('/start/')), false,
             'A manual test must not start with invalid measurement settings');
optionsPage.elements.get('#measurement_options_form')[0].reportValidity = () => true;
optionsPage.elements.get('#serverid').val('custom').trigger('change');
optionsPage.elements.get('#custom_servers')[0].reportValidity = () => false;
optionsPage.elements.get('#test_form').handlers.submit.call(optionsPage.elements.get('#test_form')[0], {preventDefault() {}});
assert.equal(optionsPage.requests.some(r => r.options.url.includes('/start/')), false,
             'Invalid custom IDs in Settings must block a test');
optionsPage.elements.get('#custom_servers')[0].reportValidity = () => true;
const submittedOptions = {duration: '3', timeout: '4', concurrent: '2', chunks: '5', upload_size: '32',
    family: 'ipv4', source: '127.0.0.1', exclude: '84', icmp: '1', http2: '1',
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
    assert.equal(JSON.stringify(request.options.data), JSON.stringify({...submittedOptions,
        exclude: ['0', '-1'].includes(selector) ? submittedOptions.exclude : ''}));
    request.resolve({error: 'Fixture reset'});
}

const detectionRace = fixture();
detectionRace.request('/defaults').resolve(defaults);
detectionRace.request('/version').resolve({message: 'librespeed-cli v1.2.1'});
detectionRace.request('/serverlist').resolve([{id: '42', name: 'Lab'}]);
detectionRace.request('/status').resolve({status: 'idle'});
detectionRace.elements.get('#detect_server').trigger('click');
detectionRace.request('/detect').resolve({result: 'started', run_id: 'd'.repeat(32)});
detectionRace.request('/detectionstatus').resolve({status: 'completed', run_id: 'c'.repeat(32),
    results: [{serverid: 42, servername: 'Stale server', latency: 1}]});
assert.doesNotMatch(detectionRace.elements.get('#detected_server').message, /Stale server/,
                    'A queued scan must not display an earlier scan as its own result');
vm.runInContext('followDetection("d".repeat(32), Date.now() - 16000, detectionGeneration)', detectionRace.context);
detectionRace.request('/detectionstatus').resolve({status: 'idle'});
assert.match(detectionRace.elements.get('#detection_status').message, /did not start/);
assert.equal(detectionRace.elements.get('#reportAct').properties.disabled, false);
detectionRace.elements.get('#serverid').val('42').trigger('change');
detectionRace.elements.get('#detect_server').trigger('click');
detectionRace.request('/detect').resolve({result: 'started', run_id: 'e'.repeat(32)});
detectionRace.request('/detectionstatus').resolve({status: 'completed', run_id: 'e'.repeat(32),
    results: [{serverid: 84, servername: 'Unlisted server', latency: 1}]});
assert.match(detectionRace.elements.get('#detection_status').message, /not in the current list/);
assert.equal(detectionRace.elements.get('#serverid').value, '42', 'A scan must not replace the choice with an unlisted server');

vm.runInContext(`renderResults([{serverid:42,servername:'Lab',download:20,
    connection:{ip:'192.0.2.9',isp:'Example ISP'}}])`, detectionRace.context);
detectionRace.elements.get('#deletelogAct').handlers.click();
detectionRace.request('/deletelog').resolve({result: 'ok'});
assert.equal(detectionRace.elements.get('#result_details').properties.hidden, true,
             'Clearing history removes the displayed snapshot too');
assert.equal(detectionRace.elements.get('#download').message, 'Not measured');

const schedulePage = fixture();
schedulePage.request('/defaults').resolve(defaults);
schedulePage.request('/schedule/get').resolve({schedule: {enabled: '0', cadence: 'daily', hour: '3',
    minute: '15', weekday: '1', server: '0', mode: 'both', timezone: 'UTC', other_jobs: 0}});
assert.equal(schedulePage.elements.get('#schedule_options').properties.hidden, true, 'Disabled scheduling hides unused settings');
assert.equal(schedulePage.elements.get('#save_schedule').properties.disabled, true);
for (const cadence of ['hourly', 'daily', 'weekdays', 'weekly']) {
    schedulePage.elements.get('#schedule_enabled').prop('checked', true);
    schedulePage.elements.get('#schedule_cadence').val(cadence);
    schedulePage.elements.get('#schedule_hour').val('5');
    schedulePage.elements.get('#schedule_minute').val('20');
    schedulePage.elements.get('#schedule_weekday').val('2');
    schedulePage.elements.get('#schedule_selection').val('custom');
    schedulePage.elements.get('#schedule_server').val('42,84');
    schedulePage.elements.get('#schedule_mode').val('latency');
    schedulePage.elements.get('#schedule_form').trigger('change');
    assert.equal(schedulePage.elements.get('#schedule_options').properties.hidden, false);
    assert.equal(schedulePage.elements.get('#schedule_hour').properties.disabled, cadence === 'hourly');
    assert.equal(schedulePage.elements.get('#schedule_weekday').properties.disabled, cadence !== 'weekly');
    schedulePage.elements.get('#schedule_form').handlers.submit.call(
        schedulePage.elements.get('#schedule_form')[0], {preventDefault() {}});
    const request = schedulePage.request('/schedule/set');
    assert.deepEqual(JSON.parse(JSON.stringify(request.options.data.schedule)), {enabled: '1', cadence,
        hour: cadence === 'hourly' ? '3' : '5', minute: '20', weekday: cadence === 'weekly' ? '2' : '1',
        server: '42,84', mode: 'latency'});
    request.resolve({result: 'saved'});
}
schedulePage.elements.get('#schedule_server').val('');
schedulePage.elements.get('#schedule_enabled').prop('checked', false);
schedulePage.elements.get('#schedule_form').trigger('change');
schedulePage.elements.get('#schedule_form').handlers.submit.call(schedulePage.elements.get('#schedule_form')[0], {preventDefault() {}});
assert.equal(schedulePage.request('/schedule/set').options.data.schedule.server, '42,84',
             'Turning off a schedule keeps its saved setup, not incomplete hidden values');
schedulePage.request('/schedule/set').resolve({result: 'failed', saved: true, error: 'Cron could not be applied'});
assert.equal(schedulePage.elements.get('#schedule_recovery').properties.open, true);
assert.equal(schedulePage.elements.get('#apply_schedule').properties.disabled, false);

const filtersPage = fixture();
vm.runInContext('historyReload()', filtersPage.context);
for (const [selector, value] of Object.entries({'#history_days': '90', '#history_server': '42',
    '#history_mode': 'latency', '#history_provider': 'librespeed', '#history_outcome': 'failed',
    '#history_origin': 'scheduled', '#history_family': 'ipv6', '#history_source': '::1'})) {
    filtersPage.elements.get(selector).val(value);
}
vm.runInContext('historyReload()', filtersPage.context);
assert.deepEqual(JSON.parse(JSON.stringify(filtersPage.request('/history').options.data)), {page: 1, days: '90',
    server: '42', mode: 'latency', provider: 'librespeed', status: 'failed',
    origin: 'scheduled', family: 'ipv6', source: '::1'});
vm.runInContext('$("#history_more_filters").prop("open", true)', filtersPage.context);
filtersPage.elements.get('#reset_history_filters').trigger('click');
assert.equal(filtersPage.elements.get('#history_more_filters').properties.open, true,
             'Resetting filters preserves the expanded controls');
assert.deepEqual(JSON.parse(JSON.stringify(filtersPage.request('/history').options.data)), {page: 1, days: '30',
    server: 'all', mode: 'all', provider: 'librespeed', status: 'all',
    origin: 'all', family: 'all', source: ''});

const unconfigured = fixture();
unconfigured.request('/defaults').resolve(defaults);
unconfigured.request('/settings/get').resolve({speedtest: {general: {servers: ''}}});
unconfigured.request('/version').resolve({message: 'librespeed-cli v1.2.1'});
unconfigured.request('/serverlist').resolve({code: 'servers_unconfigured',
    error: 'Speedtest failed: ValueError: Configure the server list'});
assert.equal(unconfigured.elements.get('#server_setup_notice').properties.hidden, false);
assert.equal(unconfigured.elements.get('#reportAct').properties.disabled, true);
unconfigured.elements.get('#test_form').handlers.submit.call(unconfigured.elements.get('#test_form')[0], {preventDefault() {}});
assert.equal(unconfigured.requests.some(r => r.options.url.includes('/start/')), false,
             'An unconfigured server list must prevent programmatic submission');
unconfigured.elements.get('#open_server_setup').handlers.click({preventDefault() {}});
assert.equal(unconfigured.elements.get('#setup_tab').properties.tab, 'show');
assert.equal(unconfigured.elements.get('#server_settings_heading').properties.trigger, 'focus');

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
assert.match(unconfigured.elements.get('#readout_hint').message, /No results yet/);
assert.equal(unconfigured.elements.get('#reportAct').properties.disabled, false);
runTimer(unconfigured, 30000);
unconfigured.request('/status').resolve({status: 'completed', results: []});
assert.equal(unconfigured.elements.get('#test_status').message, 'Test could not start',
             'A rejected start resumes automatic checks without hiding its error');
unconfigured.elements.get('#test_form').handlers.submit.call(unconfigured.elements.get('#test_form')[0], {preventDefault() {}});
unconfigured.request('/start/0/both').reject();
assert.match(unconfigured.elements.get('#test_status').message, /Start response lost/);
assert.equal(unconfigured.elements.get('#check_status').properties.hidden, false,
             'A lost start response exposes a contextual status check');
vm.runInContext('followStatus("a".repeat(32), Date.now() - 16000)', unconfigured.context);
unconfigured.request('/status').resolve({status: 'idle'});
assert.match(unconfigured.elements.get('#test_status').message, /did not start/);
assert.match(unconfigured.elements.get('#readout_hint').message, /No results yet/);
assert.equal(unconfigured.elements.get('#run_progress').properties.hidden, true);
assert.equal(unconfigured.elements.get('#check_status').properties.hidden, false);
unconfigured.elements.get('#check_status').handlers.click();
unconfigured.request('/status').resolve({status: 'idle'});
assert.equal(unconfigured.elements.get('#check_status').properties.hidden, true);
assert.equal(unconfigured.elements.get('#reportAct').properties.disabled, false);

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

const emptyHistory = {rows: [], series: [], metrics: {}, successful: 0, failed: 0,
    bytes_received: 0, bytes_sent: 0, servers: {}, sources: [], total: 0, limit: 50};
vm.runInContext('historyReload()', page.context);
page.request('/history').resolve(emptyHistory);
assert.equal(page.elements.get('#trend_charts').properties.hidden, true);
assert.equal(page.elements.get('#history_results').properties.hidden, true);
assert.equal(page.elements.get('#history_management').properties.hidden, true);
assert.equal(page.elements.get('#history_status').message, 'No test results yet.');
assert.equal(page.elements.get('#history_status').classes.has('text-danger'), false);
vm.runInContext('historyReload()', page.context);
page.request('/history').resolve({...emptyHistory, servers: {'42': 'Saved server'}});
assert.equal(page.elements.get('#history_management').properties.hidden, false,
             'Exports cover saved tests even if the current filters match none');
assert.match(page.elements.get('#history_status').message, /No tests match these filters/);
vm.runInContext('historyReload()', page.context);
page.request('/history').resolve({error: 'The history service did not respond. Check that configd is running.'});
assert.match(page.elements.get('#history_status').message, /configd/);
assert.equal(page.elements.get('#history_status').classes.has('text-danger'), true);
vm.runInContext('historyReload()', page.context);
page.request('/history').reject('timeout');
assert.match(page.elements.get('#history_status').message, /timed out/);
vm.runInContext('historyReload()', page.context);
const priorCharts = page.chartConfigs.length;
page.request('/history').resolve({rows: [], series: [{epoch: 1700000000, download: 1500, upload: 20, latency: 2, jitter: 0}],
    metrics: {download: {avg: 1500, min: 1500, max: 1500}}, successful: 1, failed: 0, bytes_received: 1, bytes_sent: 1,
    servers: {}, sources: [], total: 1, limit: 50, bucket_days: 1});
assert.equal(page.elements.get('#trend_charts').properties.hidden, false);
assert.equal(page.chartConfigs.length, priorCharts + 2);
const throughput = page.chartConfigs[priorCharts];
assert.equal(throughput.options.scales.y.title.text, 'Gbps');
assert.equal(throughput.data.datasets[0].data[0].y, 1.5);
assert.equal(throughput.data.datasets[1].data[0].y, 0.02);
assert.equal(page.chartConfigs[priorCharts + 1].options.scales.y.title.text, 'ms');
assert.equal(page.elements.get('#history_metrics').children[0].children[1].message, '1.5 Gbps');

const failed = fixture();
failed.request('/defaults').resolve({error: 'Defaults unavailable'});
assert.equal(failed.elements.get('#run_defaults_status').message, 'Defaults unavailable');
failed.request('/status').resolve({status: 'completed', results: [{servername: 'Lab', latency: 5}]});
assert.equal(failed.elements.get('#latency').message, '5 ms', 'A defaults failure must not hide the last result');
failed.request('/settings/get').resolve({});
assert.equal(failed.elements.get('#save_settings').properties.disabled, true);
assert.equal(failed.elements.get('#settings_status').message, 'Unable to load server settings');
failed.request('/version').resolve({message: 'librespeed-cli v1.2.1 (custom build)'});
assert.equal(failed.elements.get('#version').message, 'librespeed-cli v1.2.1 (custom build)',
             'Unexpected engine metadata must remain visible');
const badVersion = fixture();
badVersion.request('/version').resolve({message: {}});
assert.equal(badVersion.elements.get('#version').message, 'Unavailable');
assert.match(badVersion.elements.get('#engine_status').message, /measurement engine unavailable/i);
assert.equal(badVersion.requests.some(r => r.options.url.endsWith('/serverlist')), false);
const viewerSource = fs.existsSync(process.argv[2] + '.viewer')
    ? fs.readFileSync(process.argv[2] + '.viewer', 'utf8').match(/<script>([\s\S]*?)<\/script>/)[1]
    : scriptTokens(rawScript, false);
const viewer = fixture(viewerSource);
viewer.request('/version').resolve({message: 'librespeed-cli v1.2.1'});
assert.equal(viewer.elements.has('#open_server_setup'), false);
assert.equal(viewer.elements.get('#reportAct').properties.disabled, true);
assert.equal(viewer.elements.get('#measurement_options_controls').properties.disabled, true);
assert.equal(viewer.elements.has('#reset_measurement'), false, 'Viewer has no unused measurement editor');
assert.equal(viewer.requests.some(r => r.options.url.includes('/schedule/')), false);
viewer.request('/status').resolve({status: 'idle'});
viewer.elements.get('#serverlistAct').handlers.click();
assert.equal(viewer.request('/serverlist'), undefined, 'Viewer does not need to load a list to read saved results');
assert.equal(viewer.request('/detect'), undefined, 'Viewer page loads cannot start probes');
const viewerLatest = fixture(viewerSource);
viewerLatest.request('/status').resolve({status: 'completed', results: [
    {serverid: 42, servername: 'Lab', sponsor: 'Lab sponsor', connection: {ip: '192.0.2.9', isp: 'Example ISP'}}]});
viewerLatest.request('/version').resolve({message: 'librespeed-cli v1.2.1'});
assert.equal(detailValue(viewerLatest, '#result_details', 'Firewall IP seen by server'), '192.0.2.9',
             'A viewer can see the latest saved status without triggering a new probe');
assert.equal(viewerLatest.elements.get('#test_status').message, '', 'Loading a saved result is not a new completion');
assert.equal(viewerLatest.request('/detect'), undefined);
assert.equal(viewerLatest.elements.get('#result_details').properties.open, true, 'Saved result details open on page load');
assert.equal(detailValue(viewerLatest, '#result_details', 'Test server'), 'Lab');
assert.equal(viewerLatest.elements.get('#result_meta').properties.hidden, true,
             'Without a recorded timestamp, the header stays empty');
vm.runInContext(`renderResults([{serverid:42,servername:'Lab',sponsor:'Lab sponsor',sponsor_url:'javascript:void(0)'}])`, viewerLatest.context);
const unsafeSponsor = detailField(viewerLatest, '#result_details', 'Server sponsor');
assert.equal(unsafeSponsor.message, 'Lab sponsor');
assert.equal(unsafeSponsor.children.length, 0, 'Unsafe sponsor URLs must remain plain text');
vm.runInContext(`renderResults([{serverid:42,servername:'Lab',connection:{ip:'192.0.2.9',isp:''}}])`, viewerLatest.context);
assert.equal(detailValue(viewerLatest, '#result_details', 'ISP / network'), 'Not reported by the test server');
viewerLatest.elements.get('#result_details').prop('open', false);
viewerLatest.elements.get('#speed_units').val('Gbps').trigger('change');
assert.equal(viewerLatest.elements.get('#result_details').properties.open, false,
             'Changing display units must not reopen details the viewer collapsed');
const runner = fixture(script.replace('const canConfigure = true;', 'const canConfigure = false;'));
runner.request('/defaults').resolve(defaults);
runner.request('/version').resolve({message: 'librespeed-cli v1.2.1'});
runner.request('/serverlist').resolve([{id: '42', name: 'Lab'}]);
runner.request('/status').resolve({status: 'idle'});
completeDetection(runner);
assert.equal(runner.elements.get('#measurement_options_controls').properties.disabled, false);
runner.elements.get('#duration').val('5');
runner.elements.get('#reset_measurement').trigger('click');
assert.equal(runner.elements.get('#duration').value, '10', 'Run-only users can restore temporary measurement settings');
runner.elements.get('#duration').val('5');
vm.runInContext('$("#mode").val("latency")', runner.context);
runner.elements.get('#test_form').handlers.submit.call(runner.elements.get('#test_form')[0], {preventDefault() {}});
assert.equal(runner.request('/start/42/latency').options.data.duration, '5',
             'Run-only users can use both the selected server and temporary measurement overrides');
assert.equal(runner.requests.some(r => r.options.url.endsWith('/settings/set')), false);
vm.runInContext('renderResults([{error:"failed",servername:"One"},{error:"failed",servername:"Two"}])', page.context);
assert.equal(page.elements.get('#result_meta').properties.hidden, true, 'An all-failed comparison must not show stale successful values');
assert.equal(page.elements.get('#download').message, 'Not measured');
assert.equal(page.elements.get('#comparison').properties.hidden, false, 'Failed comparisons remain visible');
assert.equal(page.elements.get('#result_details').properties.hidden, true);
console.log('Server detection, gauges, navigation, status, results, history, settings and viewer controls passed');
