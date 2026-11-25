#!/usr/local/bin/python3
# -*- coding: utf-8 -*-
"""
 * Copyright (C) 2021 M. Kralj
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 * OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
"""
import sys
import csv
import json
import re
import errno
import fcntl
import hashlib
import heapq
import math
import os
from urllib.parse import urlsplit
from datetime import datetime, timezone
import subprocess
import argparse
import base64
import ipaddress
import selectors
import tempfile
import time
import unicodedata
import urllib.error
import urllib.request
import uuid
import syslog
import xml.etree.ElementTree as ET

librespeed = "/usr/local/bin/librespeed-cli"
librespeed_servers = "/usr/local/etc/speedtest-community/librespeed-servers.json"
public_servers_url = "https://librespeed.org/backend-servers/servers.php"
csvfile = "/usr/local/opnsense/scripts/OPNsense/speedtest/speedtest.csv"
lockfile = csvfile + '.lock'
ca_bundle = "/usr/local/etc/speedtest-community/ca.pem"
config_xml = "/conf/config.xml"

parser = argparse.ArgumentParser(
    description='LibreSpeedtest: native Rust measurements with OPNsense history.',
    epilog='For all upstream options and streaming output, use librespeed-cli --help. https://librespeed.org/',
)
parser.add_argument('action', nargs='?', default='run',
                    help='run, detect, detection-status, status, history, list, version, stat, recent, log, clear, or a configured server ID')
parser.add_argument('legacy_mode', nargs='?', help=argparse.SUPPRESS)
parser.add_argument('encoded_options', nargs='?', help=argparse.SUPPRESS)
parser.add_argument('--cli', action='store_true', help=argparse.SUPPRESS)
selection = parser.add_mutually_exclusive_group()
selection.add_argument('--server', action='append', help='configured server ID; repeat to compare servers; 0 selects the fastest')
selection.add_argument('--all-servers', action='store_true', help='compare all configured servers sequentially')
parser.add_argument('--exclude', action='append', help='exclude a configured server ID from automatic selection')
parser.add_argument('--run-id', help=argparse.SUPPRESS)
parser.add_argument('--origin', choices=('manual', 'scheduled', 'cli'), default='cli', help=argparse.SUPPRESS)
parser.add_argument('--mode', choices=('both', 'download', 'upload', 'latency'))
parser.add_argument('--duration', type=int, help='seconds per direction (1-30)')
parser.add_argument('--timeout', type=int, help='HTTP request timeout in seconds (1-15)')
parser.add_argument('--concurrent', type=int, help='concurrent requests (1-8)')
parser.add_argument('--chunks', type=int, help='download chunks (1-1000)')
parser.add_argument('--upload-size', type=int, help='upload payload in KiB (1-16384)')
parser.add_argument('--family', choices=('auto', 'ipv4', 'ipv6'))
parser.add_argument('--source', help='local source IP; routing still follows firewall rules')
parser.add_argument('--icmp', action='store_true', default=None, help='try ICMP latency instead of HTTP (requires permission)')
parser.add_argument('--http2', action='store_true', default=None, help='allow HTTP/2; changes connection concurrency semantics')
parser.add_argument('--no-pre-allocate', action='store_true', default=None, help='reduce upload buffer preallocation')
parser.add_argument('--private-ca', action='store_true', default=None, help='use the configured ca.pem instead of system trust')
for flag, key in (('--no-icmp', 'icmp'), ('--no-http2', 'http2'),
                  ('--pre-allocate', 'no_pre_allocate'), ('--system-ca', 'private_ca')):
    parser.add_argument(flag, dest=key, action='store_false', default=None,
                        help='disable the saved ' + key.replace('_', ' ') + ' option')
parser.add_argument('--format', choices=('json', 'text', 'csv'), help='terminal output format')
parser.add_argument('--config', help='override the saved server list with a local file')
parser.add_argument('--history', default=csvfile, help='CSV history path for terminal use')
parser.add_argument('--days', type=int, default=0, help='history window in days; 0 includes all dates')
parser.add_argument('--page', type=int, default=1, help='history page (50 records per page)')
args = parser.parse_args()
if args.action == 'scheduled':
    args.origin = 'scheduled'
arg = ('-1' if args.all_servers else ','.join(args.server or ['0'])) if args.action == 'run' else args.action
mode = args.mode or args.legacy_mode or 'both'
librespeed_servers, csvfile = args.config or librespeed_servers, args.history
history_file, state_file = csvfile + '.jsonl', csvfile + '.state.json'
detection = args.action in ('detect', 'detection-status')
if detection:
    state_file = csvfile + '.detect.json'
if args.action == 'detect':
    arg, mode = '0', 'latency'
output_format = args.format or ('text' if args.cli else 'json')
terminal = args.cli or args.format is not None
exit_status = 0
fields = ['Timestamp', 'ClientIp', 'ServerId', 'ServerName', 'Country', 'DlSpeed', 'UlSpeed', 'Latency', 'Link'] 

RUN_TIMEOUT = 100
DEFAULT_OPTIONS = {'duration': 10, 'timeout': 15, 'concurrent': 3, 'chunks': 100, 'upload_size': 1024,
                   'family': 'auto', 'source': '', 'icmp': False, 'http2': False,
                   'no_pre_allocate': False, 'private_ca': False, 'exclude': ''}
HISTORY_DEFAULTS = {'retention_days': 31, 'history_limit': 10000}
active_run = None

def native_settings(section='general'):
    try:
        node = ET.parse(config_xml).find('./OPNsense/speedtest/' + section)
    except FileNotFoundError:
        return {}
    return {} if node is None else {child.tag: child.text or '' for child in node}

def normalize_settings(settings):
    options = {}
    for key, value in settings.items():
        if key in ('public_servers', 'combine_servers'):
            if value not in ('0', '1'):
                raise ValueError('Invalid boolean setting: ' + key)
            continue
        if key == 'public_selection':
            public_server_selection(settings)
            continue
        if key not in DEFAULT_OPTIONS:
            if key in ('servers', *HISTORY_DEFAULTS):
                continue
            raise ValueError('Unknown LibreSpeed setting: ' + key)
        default = DEFAULT_OPTIONS[key]
        if type(default) is int:
            if not re.fullmatch(r'[0-9]+', str(value)):
                raise ValueError('Invalid integer setting: ' + key)
            value = int(value)
        elif type(default) is bool:
            if value not in ('0', '1'):
                raise ValueError('Invalid boolean setting: ' + key)
            value = value == '1'
        options[key] = value
    return options

def emit(value):
    global exit_status
    if isinstance(value, dict) and value.get('error'):
        exit_status = 1
    if output_format == 'json':
        print(json.dumps(value, allow_nan=False))
    elif output_format == 'csv':
        writer = csv.writer(sys.stdout)
        def cell(item):
            if isinstance(item, (dict, list)):
                return json.dumps(item, allow_nan=False)
            if isinstance(item, str) and (item.lstrip().startswith(('=', '+', '-', '@')) or item.startswith(('\t', '\r'))):
                return "'" + item
            return item
        if isinstance(value, dict):
            writer.writerow(value.keys())
            writer.writerow(cell(item) for item in value.values())
        elif value and all(isinstance(item, dict) for item in value):
            columns = list(dict.fromkeys(key for item in value for key in item))
            writer.writerow(columns)
            writer.writerows([cell(item.get(key, '')) for key in columns] for item in value)
        else:
            writer.writerows([cell(item) for item in row] for row in value)
    elif isinstance(value, dict):
        for key, data in value.items():
            print(f'{key}: {json.dumps(data) if isinstance(data, (dict, list)) else data}')
    else:
        for data in value:
            print(json.dumps(data) if isinstance(data, (dict, list)) else data)
    if terminal and exit_status:
        raise SystemExit(exit_status)

def measurement_options(settings=None):
    options = dict(DEFAULT_OPTIONS)
    options.update(normalize_settings(native_settings() if settings is None else settings))
    if settings is None:
        options.update({key: getattr(args, key) for key in options if getattr(args, key) is not None})
        if args.exclude is not None:
            options['exclude'] = ','.join(args.exclude)
    if settings is None and args.encoded_options:
        supplied = json.loads(base64.b64decode(args.encoded_options, validate=True))
        if not isinstance(supplied, dict) or supplied.keys() - options.keys():
            raise ValueError('Invalid LibreSpeed options')
        options.update(supplied)
    for key, maximum in (('duration', 30), ('timeout', 15), ('concurrent', 8),
                         ('chunks', 1000), ('upload_size', 16384)):
        if type(options[key]) is not int or not 1 <= options[key] <= maximum:
            raise ValueError(f'{key} must be an integer between 1 and {maximum}')
    for key in ('icmp', 'http2', 'no_pre_allocate', 'private_ca'):
        if type(options[key]) is not bool:
            raise ValueError(f'{key} must be a boolean')
    if options['family'] not in ('auto', 'ipv4', 'ipv6'):
        raise ValueError('Invalid IP family')
    if not isinstance(options['source'], str):
        raise ValueError('Invalid source address')
    if options['source']:
        source = ipaddress.ip_address(options['source'])
        if source.is_unspecified or source.is_multicast:
            raise ValueError('Use a unicast source address assigned to the firewall')
        if options['family'] != 'auto' and options['family'] != f'ipv{source.version}':
            raise ValueError('Source address does not match the selected IP family')
    if not isinstance(options['exclude'], str):
        raise ValueError('Invalid server exclusions')
    if options['exclude']:
        server_ids(options['exclude'])
    return options

def history_policy(settings=None):
    from_config = settings is None
    settings = native_settings() if settings is None else settings
    result = {}
    for key, maximum in (('retention_days', 3650), ('history_limit', 100000)):
        # Native migrations persist new-install defaults; absent legacy limits remain unlimited.
        value = settings.get(key, 0 if from_config else HISTORY_DEFAULTS[key])
        if not re.fullmatch(r'[0-9]+', str(value)) or not 0 <= int(value) <= maximum:
            raise ValueError(f'{key} must be between 0 and {maximum}; 0 keeps all history')
        result[key] = int(value)
    return result

def server_ids(value):
    if not isinstance(value, str) or not re.fullmatch(r'[1-9][0-9]{0,18}(?:,[1-9][0-9]{0,18}){0,9}', value):
        raise ValueError('Use one to ten unique configured server IDs, separated by commas')
    result = [int(item) for item in value.split(',')]
    if len(set(result)) != len(result) or any(item >= 2**63 for item in result):
        raise ValueError('Server IDs must be unique positive 64-bit integers')
    return result

def atomic_write(path, write, permissions=0o600):
    descriptor, temporary = tempfile.mkstemp(prefix='.speedtest-', dir=os.path.dirname(os.path.abspath(path)))
    try:
        with os.fdopen(descriptor, 'w', encoding='utf-8', newline='') as stream:
            os.fchmod(stream.fileno(), permissions)
            write(stream)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)

def update_state(**changes):
    if active_run is not None:
        if not os.path.isfile(__file__):
            raise FileNotFoundError('LibreSpeed was uninstalled before progress could be updated')
        active_run.update(changes, updated=time.time())
        atomic_write(state_file, lambda stream: json.dump(active_run, stream, allow_nan=False))

def lock_owner(run_id):
    history_id = hashlib.sha256(os.fsencode(os.path.abspath(state_file))).hexdigest()
    return run_id + ':' + history_id

def read_state():
    try:
        with open(state_file, encoding='utf-8') as stream:
            state = json.load(stream)
    except FileNotFoundError:
        state = {'status': 'idle'}
    if not isinstance(state, dict) or state.get('status') not in ('idle', 'running', 'completed', 'failed'):
        raise ValueError('Invalid measurement status file')
    return state

def run_status():
    try:
        descriptor = os.open(lockfile, os.O_RDWR | os.O_NOFOLLOW)
    except FileNotFoundError:
        state = read_state()
    else:
        with os.fdopen(descriptor, 'r+') as stream:
            try:
                fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except OSError as error:
                if error.errno not in (errno.EACCES, errno.EAGAIN):
                    raise
                owner = stream.read(128).strip()
                state = read_state()
                run_id = state.get('run_id')
                if (state['status'] != 'running' or not isinstance(run_id, str)
                        or not re.fullmatch(r'[a-f0-9]{32}', run_id) or owner != lock_owner(run_id)):
                    return {'status': 'busy'}
                return state
            state = read_state()
    if state.get('status') == 'running':
        state.update(status='failed', error='The measurement process stopped before completing')
    return state

def parsed_timestamp(value):
    value = re.sub(r'\.(\d{1,9})(?=[+-]\d{2}:\d{2}$)',
                   lambda match: '.' + match[1][:6].ljust(6, '0'), value.replace('Z', '+00:00'))
    parsed = datetime.fromisoformat(value)
    return parsed.replace(tzinfo=timezone.utc) if parsed.tzinfo is None else parsed

def history_records():
    seen = set()
    try:
        stream = open(history_file, encoding='utf-8')
    except FileNotFoundError:
        stream = None
    if stream is not None:
        with stream:
            fcntl.flock(stream, fcntl.LOCK_SH)
            for number, line in enumerate(stream, 1):
                if len(line) > 65536:
                    raise ValueError(f'Detailed history row {number} exceeds 64 KiB')
                record = json.loads(line)
                if (not isinstance(record, dict) or type(record.get('epoch')) not in (float, int)
                        or not math.isfinite(record['epoch']) or record.get('status') not in ('success', 'failed')):
                    raise ValueError(f'Invalid detailed history row {number}')
                if record['status'] == 'success' and record['mode'] == 'both':
                    seen.add((round(record['epoch'], 6), str(record['serverid'])))
                yield record
    try:
        stream = open(csvfile, encoding='utf-8', newline='')
    except FileNotFoundError:
        return
    with stream:
        for row in data_rows(csv.reader(stream)):
            epoch = float(row[0])
            if (round(epoch, 6), row[2]) in seen:
                continue
            yield {'id': 'legacy-' + row[0] + '-' + row[2], 'epoch': epoch,
                   'timestamp': datetime.fromtimestamp(epoch, timezone.utc).isoformat(),
                   'serverid': row[2], 'servername': row[3], 'provider': 'legacy', 'origin': 'legacy',
                   'mode': 'both', 'status': 'success', 'download': float(row[5]),
                   'upload': float(row[6]), 'latency': float(row[7]), '_csv': row}

def append_record(record):
    if not os.path.isfile(__file__):
        raise FileNotFoundError('LibreSpeed was uninstalled before history could be updated')
    record = dict(record, epoch=parsed_timestamp(record['timestamp']).timestamp(),
                  id=active_run['run_id'] + '-' + str(record.get('serverid', '0')),
                  origin=active_run['origin'], engine='librespeed-cli 1.2.1')
    descriptor = os.open(history_file, os.O_WRONLY | os.O_CREAT | os.O_APPEND | os.O_NOFOLLOW, 0o644)
    with os.fdopen(descriptor, 'a', encoding='utf-8') as stream:
        fcntl.flock(stream, fcntl.LOCK_EX)
        os.fchmod(stream.fileno(), 0o644)
        stream.write(json.dumps(record, allow_nan=False) + '\n')
        stream.flush()
        os.fsync(stream.fileno())

def prune_history():
    policy = history_policy()
    if not any(policy.values()):
        return
    cutoff = time.time() - policy['retention_days'] * 86400 if policy['retention_days'] else 0
    records = (record for record in history_records() if record['epoch'] >= cutoff)
    records = (heapq.nlargest(policy['history_limit'], records, key=lambda row: row['epoch'])
               if policy['history_limit'] else sorted(records, key=lambda row: row['epoch'], reverse=True))
    records.reverse()
    atomic_write(history_file, lambda stream: stream.writelines(json.dumps(row, allow_nan=False) + '\n' for row in records), 0o644)
    def write_csv(stream):
        writer = csv.writer(stream)
        writer.writerow(fields)
        for record in records:
            if record['mode'] == 'both' and record['status'] == 'success':
                writer.writerow(record.get('_csv') or result_row(record))
    atomic_write(csvfile, write_csv, 0o644)

def history_report(query):
    allowed = {'days', 'page', 'limit', 'server', 'mode', 'status', 'origin', 'family', 'source', 'provider'}
    if not isinstance(query, dict) or query.keys() - allowed:
        raise ValueError('Invalid history filters')
    for key, default, low, high in (('days', 0, 0, 3650), ('page', 1, 1, 200),
                                    ('limit', 50, 1, 200)):
        value = query.get(key, default)
        if not re.fullmatch(r'[0-9]+', str(value)) or not low <= int(value) <= high:
            raise ValueError(f'Invalid history {key}')
        query[key] = int(value)
    for key, values in (('mode', ('both', 'download', 'upload', 'latency')),
                        ('status', ('success', 'failed')), ('origin', ('manual', 'scheduled', 'cli', 'legacy')),
                        ('family', ('auto', 'ipv4', 'ipv6')), ('provider', ('librespeed', 'legacy'))):
        if query.get(key, '') not in ('', 'all', *values):
            raise ValueError('Invalid history ' + key)
    selected_servers = None
    if query.get('server', '') not in ('', 'all'):
        selected_servers = {0} if str(query['server']) == '0' else set(server_ids(str(query['server'])))
    source = query.get('source', '')
    if not isinstance(source, str):
        raise ValueError('Invalid history source')
    if source:
        ipaddress.ip_address(source)
    cutoff = time.time() - query['days'] * 86400 if query['days'] else 0
    metrics = {key: {'sum': 0, 'min': None, 'max': None, 'count': 0}
               for key in ('download', 'upload', 'latency', 'jitter')}
    buckets, servers, sources = {}, {}, set()
    matched, failures, received, sent = 0, 0, 0, 0
    def matching():
        nonlocal matched, failures, received, sent
        for record in history_records():
            servers[str(record['serverid'])] = record['servername']
            options = record.get('options', {})
            if options.get('source'):
                sources.add(options['source'])
            if record['epoch'] < cutoff:
                continue
            if any(query.get(key, '') not in ('', 'all', str(record.get(key, '')))
                   for key in ('mode', 'status', 'origin', 'provider')) or (
                   selected_servers is not None and int(record['serverid']) not in selected_servers):
                continue
            if any(query.get(key, '') not in ('', 'all', options.get(key, '')) for key in ('family', 'source')):
                continue
            matched += 1
            if record['status'] == 'failed':
                failures += 1
            else:
                received += record.get('bytes_received', 0)
                sent += record.get('bytes_sent', 0)
                day = int(record['epoch'] // 86400) * 86400
                bucket = buckets.setdefault(day, {key: [0, 0] for key in metrics})
                for key, metric in metrics.items():
                    if key not in record:
                        continue
                    value = record[key]
                    metric['count'] += 1
                    metric['sum'] += value
                    metric['min'] = value if metric['min'] is None else min(metric['min'], value)
                    metric['max'] = value if metric['max'] is None else max(metric['max'], value)
                    bucket[key][0] += value
                    bucket[key][1] += 1
            yield record
    size = query['page'] * query['limit']
    newest = heapq.nlargest(size, matching(), key=lambda row: row['epoch'])
    rows = [{key: value for key, value in row.items() if not key.startswith('_')}
            for row in newest[size - query['limit']:]]
    for metric in metrics.values():
        metric['avg'] = round(metric.pop('sum') / metric['count'], 2) if metric['count'] else None
    stride = max(1, math.ceil((max(buckets) - min(buckets) + 86400) / (499 * 86400))) if buckets else 1
    grouped = {}
    for day, bucket in buckets.items():
        target = grouped.setdefault(day // (stride * 86400) * stride * 86400,
                                    {key: [0, 0] for key in metrics})
        for key in metrics:
            target[key][0] += bucket[key][0]
            target[key][1] += bucket[key][1]
    series = [dict(epoch=day, **{key: round(value[0] / value[1], 2) if value[1] else None
                                for key, value in bucket.items()}) for day, bucket in sorted(grouped.items())]
    return {'rows': rows, 'total': matched, 'failed': failures, 'successful': matched - failures,
            'metrics': metrics, 'series': series, 'bucket_days': stride, 'servers': servers,
            'sources': sorted(sources), 'bytes_received': received, 'bytes_sent': sent,
            'page': query['page'], 'limit': query['limit']}

def data_rows(reader):
    next(reader, None)
    for row in reader:
        if row and row != fields:
            yield row

def run_command(command, timeout, **kwargs):
    return subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          check=True, timeout=timeout, **kwargs)

def streamed_command(command, timeout, content):
    reports = None
    buffers = {'out': b'', 'err': b''}
    deadline = time.monotonic() + timeout
    with subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE) as process:
        try:
            process.stdin.write(content)
            process.stdin.close()
            with selectors.DefaultSelector() as selector:
                selector.register(process.stdout, selectors.EVENT_READ, 'out')
                selector.register(process.stderr, selectors.EVENT_READ, 'err')
                while selector.get_map():
                    if time.monotonic() >= deadline:
                        raise subprocess.TimeoutExpired(command, timeout)
                    for key, _ in selector.select(min(1, max(0, deadline - time.monotonic()))):
                        chunk = os.read(key.fd, 4096)
                        if not chunk:
                            selector.unregister(key.fileobj)
                            continue
                        name = key.data
                        buffers[name] += chunk
                        if name == 'err':
                            buffers[name] = buffers[name][-8192:]
                            continue
                        if len(buffers[name]) > 65536:
                            raise ValueError('LibreSpeed streaming output exceeds 64 KiB per event')
                        while b'\n' in buffers[name]:
                            line, buffers[name] = buffers[name].split(b'\n', 1)
                            event = json.loads(line)
                            if not isinstance(event, dict):
                                raise ValueError('Invalid LibreSpeed streaming event')
                            if event.get('event') == 'result':
                                if reports is not None:
                                    raise ValueError('Duplicate LibreSpeed result event')
                                reports = event.get('reports')
                            elif event.get('event') in ('phase', 'progress'):
                                phase = event.get('phase')
                                if phase not in ('ping', 'download', 'upload'):
                                    raise ValueError('Invalid LibreSpeed measurement phase')
                                progress, mbps = event.get('progress', 0), event.get('mbps')
                                if type(progress) is not int or not 0 <= progress <= 100:
                                    raise ValueError('Invalid LibreSpeed progress')
                                if mbps is not None and (type(mbps) not in (int, float)
                                                         or not math.isfinite(mbps) or mbps < 0):
                                    raise ValueError('Invalid LibreSpeed progress rate')
                                if event['event'] == 'progress':
                                    seconds = event.get('seconds')
                                    if (phase not in ('download', 'upload') or mbps is None
                                            or type(seconds) not in (int, float)
                                            or not math.isfinite(seconds) or not 0 <= seconds <= timeout):
                                        raise ValueError('Invalid LibreSpeed progress sample')
                                    samples = active_run['samples'][phase]
                                    if samples and seconds < samples[-1]['seconds']:
                                        raise ValueError('LibreSpeed progress samples are out of order')
                                    point = {'seconds': seconds, 'mbps': mbps}
                                    if samples and seconds == samples[-1]['seconds']:
                                        samples[-1] = point
                                    else:
                                        samples.append(point)
                                        del samples[:-64]
                                update_state(phase=phase, progress=progress, mbps=mbps)
                returncode = process.wait(timeout=max(0.01, deadline - time.monotonic()))
            if returncode:
                raise subprocess.CalledProcessError(returncode, command, stderr=buffers['err'])
            if buffers['out'].strip() or reports is None:
                raise ValueError('LibreSpeed ended without a complete result event')
        except BaseException:
            process.kill()
            process.wait()
            raise
    return reports

class NoRegistryRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError('LibreSpeed public server list must not redirect')


def fetch_public_servers():
    try:
        opener = urllib.request.build_opener(NoRegistryRedirect())
        with opener.open(public_servers_url, timeout=20) as response:
            return response.read(65537)
    except OSError as error:
        raise ValueError('Unable to retrieve the official LibreSpeed.org server list: '
                         + str(error)) from error


def public_server_selection(settings):
    selection = settings.get('public_selection', 'all')
    if selection in ('all', 'none'):
        return selection
    if not isinstance(selection, str) or not re.fullmatch(r'[1-9][0-9]{0,18}(?:,[1-9][0-9]{0,18}){0,49}', selection):
        raise ValueError('Select all, none, or up to 50 official server IDs')
    ids = [int(value) for value in selection.split(',')]
    if len(set(ids)) != len(ids) or any(value >= 2**63 for value in ids):
        raise ValueError('Approved official server IDs must be unique positive integers below 2^63')
    return set(ids)


def load_librespeed_servers(content=None):
    if content is None:
        settings = native_settings()
        selection = public_server_selection(settings)
        local_content = None
        if not args.config and settings.get('servers', '').strip():
            local_content = settings['servers']
        else:
            try:
                with open(librespeed_servers, 'rb') as config:
                    local_content = config.read(65537)
            except FileNotFoundError:
                if args.config:
                    return None
        local = load_librespeed_servers(local_content) if local_content is not None else []
        if args.config or (local and settings.get('combine_servers', '0') != '1'):
            return local
        if settings.get('public_servers', '1') != '1':
            return local or None
        if selection == 'none':
            if local:
                return local
            raise ValueError('No servers are allowed. Allow an official server or add a custom server')
        public = load_librespeed_servers(fetch_public_servers())
        approved = public if selection == 'all' else [server for server in public if server['id'] in selection]
        if not approved and not local:
            raise ValueError('None of the allowed official servers are in the current catalog. Review the allowed list')
        if any(custom['id'] == official['id'] or custom['server'].rstrip('/') == official['server'].rstrip('/')
               for custom in local for official in approved):
            raise ValueError('Custom and allowed official servers share an ID or URL. '
                             'Edit the custom entry or remove the official server from the allowed list')
        merged = local + approved
        if not merged:
            return None
        # Reuse the same duplicate, size and endpoint validation for merged sources.
        return load_librespeed_servers(json.dumps(merged))
    if len(content.encode('utf-8') if isinstance(content, str) else content) > 65536:
        raise ValueError('LibreSpeed server list exceeds 64 KiB')
    servers = json.loads(content)
    if not isinstance(servers, list) or not 1 <= len(servers) <= 50:
        raise ValueError('LibreSpeed server list must contain one to 50 servers')
    ids, urls = set(), set()
    for server in servers:
        if not isinstance(server, dict):
            raise ValueError('Invalid LibreSpeed server entry')
        server_id, name, url = (server.get(key) for key in ('id', 'name', 'server'))
        if type(server_id) is not int or not 0 < server_id < 2**63 or server_id in ids:
            raise ValueError('LibreSpeed server IDs must be unique positive integers')
        if (not isinstance(name, str) or not name.strip() or len(name) > 200
                or any(ord(c) < 32 or ord(c) == 127 for c in name) or not isinstance(url, str)):
            raise ValueError('Each LibreSpeed server requires a name and HTTPS URL')
        endpoint = urlsplit(url)
        if (not url.startswith('https://') or not endpoint.hostname or endpoint.username is not None
                or endpoint.query or endpoint.fragment or url in urls
                or any(c.isspace() or ord(c) < 32 or ord(c) == 127 for c in url) or '\\' in url):
            raise ValueError('LibreSpeed servers require unique HTTPS URLs without credentials, queries or fragments')
        for key in ('dlURL', 'ulURL', 'pingURL', 'getIpURL'):
            value = server.get(key)
            if (not isinstance(value, str) or not re.fullmatch(r'[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*', value)
                    or any(part in ('.', '..') for part in value.split('/'))):
                raise ValueError(f'LibreSpeed {key} must be a relative endpoint path')
        ids.add(server_id)
        urls.add(url)
    return servers

def optional_display_text(value):
    if (not isinstance(value, str) or len(value) > 200
            or any(unicodedata.category(c).startswith('C') for c in value)):
        return ''
    return value.strip()

def run_librespeed(servers, server_id, mode, options):
    if server_id not in ('', '0'):
        servers = [server for server in servers if server['id'] == int(server_id)]
        if not servers:
            raise ValueError('Requested LibreSpeed server is not configured')
    if not os.access(librespeed, os.X_OK):
        raise ValueError(f'Install the LibreSpeed Rust CLI at {librespeed}')
    streaming = args.run_id is not None or args.origin == 'scheduled'
    command = [librespeed, '--local-json', '-', '--json-stream' if streaming else '--json', '--secure']
    for key in ('duration', 'timeout', 'concurrent', 'chunks', 'upload_size'):
        command.extend(['--' + key.replace('_', '-'), str(options[key])])
    if not options['icmp']:
        command.append('--no-icmp')
    for key in ('http2', 'no_pre_allocate'):
        if options[key]:
            command.append('--' + key.replace('_', '-'))
    if options['family'] != 'auto':
        command.append('--' + options['family'])
    if options['source']:
        command.extend(['--source', options['source']])
    if options['private_ca']:
        if not os.path.isfile(ca_bundle):
            raise ValueError(f'Install your private CA PEM bundle at {ca_bundle}')
        command.extend(['--ca-cert', ca_bundle])
    directions = []
    for direction, counter in (('download', 'bytes_received'), ('upload', 'bytes_sent')):
        if mode in ('both', direction):
            directions.append((direction, counter))
        else:
            command.append('--no-' + direction)
    deadline = max(RUN_TIMEOUT, len(directions) * options['duration'] + len(servers) * options['timeout'] + 30)
    content = json.dumps(servers).encode('utf-8')
    reports = (streamed_command(command, deadline, content) if streaming else
               json.loads(run_command(command, deadline, input=content).stdout))
    if not isinstance(reports, list) or len(reports) != 1:
        raise ValueError('LibreSpeed did not return exactly one result')
    result = reports[0]
    if (not isinstance(result, dict) or not isinstance(result.get('server'), dict)
            or not isinstance(result.get('timestamp'), str)):
        raise ValueError('Invalid LibreSpeed result')
    selected = next((server for server in servers if server['server'] == result['server'].get('url')), None)
    if selected is None:
        raise ValueError('LibreSpeed reported an unconfigured server')
    update_state(server=selected['name'])
    out = {'provider': 'librespeed', 'timestamp': result['timestamp'], 'clientip': '',
           'serverid': selected['id'], 'servername': selected['name'], 'country': '', 'link': ''}
    out['sponsor'] = optional_display_text(selected.get('sponsorName'))
    client = result.get('client')
    if isinstance(client, dict):
        address = client.get('ip')
        try:
            address = (str(ipaddress.ip_address(address))
                       if isinstance(address, str) and len(address) <= 45 and '%' not in address else '')
        except ValueError:
            address = ''
        out['connection'] = {'ip': address, 'isp': optional_display_text(client.get('org'))}
    for field, key in [('latency', 'ping'), ('jitter', 'jitter')] + [(d, d) for d, _ in directions]:
        value = result.get(key)
        if type(value) not in (int, float) or not math.isfinite(value) or value < 0:
            raise ValueError(f'Invalid LibreSpeed {field} measurement')
        out[field] = round(value, 2)
    for direction, counter in directions:
        if out[direction] <= 0 or type(result.get(counter)) is not int or result[counter] <= 0:
            raise ValueError(f'LibreSpeed did not complete the {direction} measurement on {selected["name"]}. '
                             'Try another server or check connectivity')
        out[counter] = result[counter]
    out['mode'] = mode
    out['options'] = options
    tls = result.get('tls')
    if isinstance(tls, dict):
        out['tls'] = {key: value for key, value in tls.items()
                      if isinstance(value, (str, bool, int))}
    return out

def result_row(out):
    parsed_time = parsed_timestamp(out['timestamp'])
    name = f"{out['servername']} (LibreSpeed)"
    if name.lstrip().startswith(('=', '+', '-', '@')):
        name = "'" + name
    return [parsed_time.timestamp(), out.get('clientip', ''), out['serverid'], name,
            out.get('country', ''), out['download'], out['upload'], out['latency'], out.get('link', '')]

def save_result(out):
    record = {key: value for key, value in out.items() if key != 'connection'}
    append_record(dict(record, status='success'))
    if out['mode'] != 'both':
        return
    with open(csvfile, 'a', encoding="utf-8", newline='') as f:
        csv.writer(f, dialect='excel').writerow(result_row(out))
        f.flush()
        os.fsync(f.fileno())

def error_message(error):
    if isinstance(error, subprocess.TimeoutExpired):
        return 'Speedtest timed out after ' + str(error.timeout) + ' seconds'
    if isinstance(error, subprocess.CalledProcessError):
        for stream in (error.stderr, error.output):
            if stream:
                lines = [line.strip() for line in stream.decode('utf-8', 'replace').splitlines() if line.strip()]
                if lines:
                    return 'Speedtest failed: ' + lines[-1]
        return 'Speedtest failed: exit code ' + str(error.returncode)
    return 'Speedtest failed: ' + type(error).__name__ + ': ' + str(error)

def failure_record(message, server_id='0', name='Automatic selection', options=None):
    record = {'timestamp': datetime.now(timezone.utc).isoformat(), 'provider': 'librespeed',
              'serverid': server_id if re.fullmatch(r'[1-9][0-9]{0,18}', str(server_id)) else '0',
              'selection': server_id, 'servername': name, 'mode': mode, 'status': 'failed',
              'error': message, 'options': options or {}}
    if not detection:
        append_record(record)
    return record

def report_error(error):
    message = error_message(error)
    if active_run is not None:
        try:
            failure_record(message, arg)
            update_state(status='failed', error=message)
            if not detection:
                prune_history()
        except (OSError, ValueError) as history_error:
            message += '; unable to update failure history: ' + str(history_error)
    if args.origin == 'scheduled':
        syslog.syslog(syslog.LOG_ERR, 'LibreSpeed scheduled measurement: ' + message)
    emit({'error': message})

def recent_result(row):
    if not row:
        return {'date': '', 'server': '', 'download': '', 'upload': '', 'latency': '', 'url': '',
                'error': 'No speedtest results yet'}
    return {
        'date': datetime.fromtimestamp(float(row[0])).isoformat(),
        'server': row[2] + " " + row[3],
        'download': row[5],
        'upload': row[6],
        'latency': row[7],
        'url': row[8] if len(row) > 8 else '',
    }

lock = None
try:
    if arg == 'check-settings':
        settings = json.loads(base64.b64decode(args.encoded_options or '', validate=True))
        if not isinstance(settings, dict):
            raise ValueError('Invalid LibreSpeed settings')
        measurement_options(settings)
        history_policy(settings)
        servers = settings.get('servers', '')
        if not isinstance(servers, str):
            raise ValueError('LibreSpeed server settings must be JSON text')
        if servers.strip():
            load_librespeed_servers(servers)
        emit({'result': 'ok'})
        quit()

    if arg == 'check-schedule':
        schedule = json.loads(base64.b64decode(args.encoded_options or '', validate=True))
        if not isinstance(schedule, dict) or schedule.get('mode') not in ('both', 'download', 'upload', 'latency'):
            raise ValueError('Invalid schedule mode')
        selection = schedule.get('server', '0')
        if selection not in ('0', '-1'):
            server_ids(selection)
        if schedule.get('enabled') == '1':
            options = measurement_options(native_settings())
            servers = load_librespeed_servers()
            if not servers:
                raise ValueError('Configure measurement servers before enabling a schedule')
            known = {server['id'] for server in servers}
            requested = server_ids(selection) if selection not in ('0', '-1') else []
            excluded = server_ids(options['exclude']) if options['exclude'] else []
            if set(requested + excluded) - known or not known - set(excluded):
                raise ValueError('Scheduled server selection or exclusions are not configured')
            if requested and excluded:
                raise ValueError('Clear saved exclusions before scheduling explicit servers')
            history_policy()
        emit({'result': 'ok'})
        quit()

    if arg in ('status', 'detection-status'):
        emit(run_status())
        quit()
    if arg == 'history':
        query = json.loads(base64.b64decode(args.legacy_mode, validate=True)) if args.legacy_mode else {
            'days': args.days, 'page': args.page
        }
        emit(history_report(query))
        quit()
    if arg == 'public-list':
        if native_settings().get('public_servers', '1') != '1':
            emit({'error': 'Public server discovery is disabled. Enable it and save settings to load the catalog.'})
        else:
            servers = load_librespeed_servers(fetch_public_servers())
            keys = ('name', 'server', 'dlURL', 'ulURL', 'pingURL', 'getIpURL')
            emit({'servers': [
                dict({key: server[key] for key in keys}, id=str(server['id']),
                     sponsorName=optional_display_text(server.get('sponsorName')))
                for server in servers
            ]})
        quit()
    if arg == 'scheduled':
        schedule = native_settings('schedule')
        if schedule.get('enabled', '0') != '1':
            raise ValueError('The built-in LibreSpeed schedule is disabled')
        arg, mode = schedule.get('server', '0'), schedule.get('mode', 'both')
        args.origin = 'scheduled'
    server_argument = arg in ('', '0', '-1') or re.fullmatch(r'[1-9][0-9]{0,18}(?:,[1-9][0-9]{0,18}){0,9}', arg) is not None
    hold_lock = server_argument or arg == 'clear'
    if hold_lock or not os.path.exists(csvfile):
        lock_fd = os.open(lockfile, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
        lock = os.fdopen(lock_fd, 'r+')
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as e:
            if e.errno not in (errno.EACCES, errno.EAGAIN):
                raise
            emit({'error': 'A speedtest is already running'})
            quit()

        lock.seek(0)
        lock.truncate()
        lock.flush()
        # A process started before package removal must not recreate its history.
        if not os.path.isfile(__file__):
            raise FileNotFoundError('LibreSpeed was uninstalled before history could be updated')
        if not detection:
            try:
                with open(csvfile, 'x', encoding="utf-8", newline='') as f:
                    os.fchmod(f.fileno(), 0o644)
                    csv.writer(f, dialect='excel').writerow(fields)
            except FileExistsError:
                pass
        if not hold_lock:
            lock.close()
            lock = None

    # parameter l or log - returning the last 50 entries from csv
    if arg=='l' or arg == 'log':
        with open(csvfile, 'r', encoding="utf-8", newline='') as f:
            rows = heapq.nlargest(50, data_rows(csv.reader(f, dialect='excel')),
                                 key=lambda row: float(row[0]))
        for row in rows:
            row[0] = datetime.fromtimestamp(float(row[0])).isoformat()
        emit(rows)
        quit()

    # parameter r or recent - returning the last 1 entries from csv
    if arg=='r' or arg == 'recent':
        row=[]
        with open(csvfile, 'r', encoding="utf-8", newline='') as f:
            row = max(data_rows(csv.reader(f, dialect='excel')), key=lambda row: float(row[0]), default=[])
        emit(recent_result(row))
        quit()


    # parameter s or stat - return statistics
    if arg=='s' or arg=='stat':
        count = 0
        last_row = None
        oldest = youngest = None
        values = {name: {'sum': 0.0, 'min': None, 'max': None}
                  for name in ('latency', 'download', 'upload')}
        with open(csvfile, 'r', encoding="utf-8", newline='') as f:
            for row in data_rows(csv.reader(f, dialect='excel')):
                if last_row is None or float(row[0]) > float(last_row[0]):
                    last_row = row
                timestamp = datetime.fromtimestamp(float(row[0]))
                oldest = timestamp if oldest is None else min(oldest, timestamp)
                youngest = timestamp if youngest is None else max(youngest, timestamp)
                for name, value in (('latency', float(row[7])), ('download', float(row[5])),
                                    ('upload', float(row[6]))):
                    metric = values[name]
                    metric['sum'] += value
                    metric['min'] = value if metric['min'] is None else min(metric['min'], value)
                    metric['max'] = value if metric['max'] is None else max(metric['max'], value)
                count += 1
        out = {
            'samples': count,
            'recent': recent_result(last_row),
            'period': {
                'oldest': str(oldest) if count else '0',
                'youngest': str(youngest) if count else '0',
            },
        }
        for name, metric in values.items():
            out[name] = {
                'avg': round(metric['sum'] / count, 2) if count else 0,
                'min': round(metric['min'], 2) if count else 0,
                'max': round(metric['max'], 2) if count else 0,
            }
        emit(out)
        quit()

    if arg == 'clear':
        for path in (history_file, state_file, csvfile + '.detect.json'):
            try:
                os.unlink(path)
            except FileNotFoundError:
                pass
        with open(csvfile, 'w', encoding="utf-8", newline='') as f:
            csv.writer(f, dialect='excel').writerow(fields)
        emit({'result': 'ok'})
        quit()

    if mode not in ('both', 'download', 'upload', 'latency'):
        raise ValueError('Invalid LibreSpeed test mode')
    if server_argument:
        if args.run_id is not None and not re.fullmatch(r'[a-f0-9]{32}', args.run_id):
            raise ValueError('Invalid measurement run ID')
        active_run = {'run_id': args.run_id or uuid.uuid4().hex, 'origin': args.origin, 'status': 'running',
                      'started': time.time(), 'mode': mode, 'results': [], 'phase': 'selecting',
                      'total': 1, 'completed': 0, 'progress': 0, 'deadline': time.time() + 250,
                      'samples': {'download': [], 'upload': []}}
        lock.write(lock_owner(active_run['run_id']))
        lock.flush()
        update_state()
    if arg in ('v', 'version'):
        if not os.access(librespeed, os.X_OK):
            raise ValueError(f'Install the LibreSpeed Rust CLI at {librespeed}')
        version = run_command([librespeed, '--version'], 10).stdout.decode('utf-8').strip()
        if not version.startswith('librespeed-cli '):
            raise ValueError('Unrecognized LibreSpeed client version output')
        emit({'version': 'librespeed', 'message': version.splitlines()[0]})
    else:
        options = measurement_options()
        servers = load_librespeed_servers()
        if servers is None:
            error = ValueError(f'Configure the LibreSpeed server list at {librespeed_servers}')
            if arg in ('t', 'list'):
                emit({'error': error_message(error), 'code': 'servers_unconfigured'})
            else:
                raise error
        elif arg in ('t', 'list'):
            emit([{'id': str(s['id']), 'name': s['name'], 'location': '', 'country': ''}
                  for s in servers])
        elif server_argument:
            excluded = server_ids(options['exclude']) if options['exclude'] else []
            if arg not in ('', '0', '-1') and excluded:
                raise ValueError('Explicit server selection cannot be combined with exclusions')
            known = {server['id'] for server in servers}
            requested = server_ids(arg) if arg not in ('', '0', '-1') else []
            if set(requested + excluded) - known:
                raise ValueError('Requested LibreSpeed server is not configured')
            servers = [server for server in servers if server['id'] not in excluded]
            if not servers:
                raise ValueError('At least one configured server must remain after exclusions')
            selections = ([str(server['id']) for server in servers] if arg == '-1' else
                          [str(item) for item in requested] if requested else ['0'])
            update_state(total=len(selections), deadline=time.time() + len(selections) * max(RUN_TIMEOUT,
                         2 * options['duration'] + len(servers) * options['timeout'] + 30) + 30)
            results, failed = [], 0
            for index, selection in enumerate(selections):
                selected = next((server for server in servers if str(server['id']) == selection), None)
                update_state(phase='selecting', progress=0, mbps=None, completed=index,
                             samples={'download': [], 'upload': []},
                             server=selected['name'] if selected else 'Automatic selection')
                try:
                    result = run_librespeed(servers, selection, mode, options)
                except (subprocess.SubprocessError, OSError, ValueError, OverflowError) as error:
                    message = error_message(error)
                    result = failure_record(message, selection, selected['name'] if selected else 'Automatic selection', options)
                    failed += 1
                    if args.origin == 'scheduled':
                        syslog.syslog(syslog.LOG_ERR, 'LibreSpeed scheduled measurement: ' + message)
                else:
                    if not detection:
                        save_result(result)
                results.append(result)
                update_state(results=results, completed=index + 1)
            if not detection:
                prune_history()
            error = (results[0]['error'] if len(results) == 1 else f'{failed} of {len(results)} servers failed') if failed else None
            update_state(status='failed' if failed else 'completed', phase='finished', progress=100, error=error)
            active_run = None
            if len(results) == 1:
                emit(results[0])
            else:
                emit(dict(results=results, **({'error': error} if failed else {})))
        else:
            raise ValueError('Invalid speedtest server ID')
except subprocess.TimeoutExpired as e:
    report_error(e)
except subprocess.CalledProcessError as e:
    report_error(e)
except (OSError, ValueError, OverflowError, csv.Error, IndexError, ET.ParseError) as e:
    report_error(e)
finally:
    if lock is not None:
        lock.close()