import csv
import http.server
import io
import json
import os
from pathlib import Path
import ssl
import subprocess
import sys
import tempfile
import threading
import unittest


@unittest.skipUnless(os.environ.get('LIBRESPEED_TEST_BINARY'), 'Set LIBRESPEED_TEST_BINARY for real engine tests')
class LiveEngineTests(unittest.TestCase):
    def test_verified_https_modes_and_native_output_formats(self):
        binary = str(Path(os.environ['LIBRESPEED_TEST_BINARY']).resolve())
        script = Path(__file__).resolve().parents[1] / 'src/opnsense/scripts/OPNsense/speedtest/opn_speedtest.py'
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)

            def openssl(*args):
                subprocess.run(['openssl', *args], cwd=root, check=True, capture_output=True, timeout=30)

            openssl('req', '-new', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1',
                    '-subj', '/CN=Isolated LibreSpeed Test CA', '-addext', 'basicConstraints=critical,CA:TRUE',
                    '-keyout', 'ca.key', '-out', 'ca.pem')
            openssl('req', '-new', '-newkey', 'rsa:2048', '-nodes', '-subj', '/CN=localhost',
                    '-keyout', 'leaf.key', '-out', 'leaf.csr')
            (root / 'leaf.ext').write_text(
                'basicConstraints=critical,CA:FALSE\nkeyUsage=digitalSignature,keyEncipherment\n'
                'extendedKeyUsage=serverAuth\nsubjectAltName=DNS:localhost,IP:127.0.0.1\n')
            openssl('x509', '-req', '-in', 'leaf.csr', '-CA', 'ca.pem', '-CAkey', 'ca.key',
                    '-CAcreateserial', '-days', '1', '-extfile', 'leaf.ext', '-out', 'leaf.pem')

            class Handler(http.server.BaseHTTPRequestHandler):
                protocol_version = 'HTTP/1.1'

                def log_message(self, *args):
                    pass

                def handle(self):
                    try:
                        super().handle()
                    except (BrokenPipeError, ConnectionResetError, ssl.SSLError):
                        pass  # The engine closes transfers when their duration expires.

                def reply(self, body):
                    self.send_response(200)
                    self.send_header('Content-Length', str(len(body)))
                    self.end_headers()
                    self.wfile.write(body)

                def do_GET(self):
                    path = self.path.split('?')[0]
                    self.reply(b'0' * 1048576 if path == '/garbage' else
                               b'{"processedString":"127.0.0.1","rawIspInfo":""}' if path == '/ip' else b'')

                def do_POST(self):
                    if self.headers.get('Transfer-Encoding') == 'chunked':
                        while True:
                            line = self.rfile.readline()
                            if not line:
                                return
                            remaining = int(line.strip().split(b';')[0], 16)
                            if not remaining:
                                self.rfile.readline()
                                break
                            while remaining:
                                chunk = self.rfile.read(min(65536, remaining))
                                if not chunk:
                                    return
                                remaining -= len(chunk)
                            self.rfile.read(2)
                    else:
                        remaining = int(self.headers['Content-Length'])
                        while remaining:
                            chunk = self.rfile.read(min(65536, remaining))
                            if not chunk:
                                return
                            remaining -= len(chunk)
                    self.reply(b'')

            with http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler) as server:
                context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
                context.load_cert_chain(root / 'leaf.pem', root / 'leaf.key')
                server.socket = context.wrap_socket(server.socket, server_side=True)
                worker = threading.Thread(target=server.serve_forever, daemon=True)
                worker.start()
                try:
                    servers = root / 'servers.json'
                    history = root / 'history.csv'
                    servers.write_text(json.dumps([{
                        'id': 42, 'name': 'Verified HTTPS fixture',
                        'server': f'https://127.0.0.1:{server.server_port}/',
                        'dlURL': 'garbage', 'ulURL': 'empty', 'pingURL': 'empty', 'getIpURL': 'ip'
                    }]))
                    source = script.read_text().replace('"/usr/local/bin/librespeed-cli"', repr(binary)).replace(
                        '"/usr/local/etc/speedtest-community/ca.pem"', repr(str(root / 'ca.pem'))
                    ).replace('"/conf/config.xml"', repr(str(root / 'unused-config.xml')))
                    test_script = root / 'opn_speedtest.py'
                    test_script.write_text(source)

                    def run(*args, success=True):
                        response = subprocess.run(
                            [sys.executable, '-B', str(test_script), '--cli', '--format', 'json',
                             '--config', str(servers), '--history', str(history), *args],
                            capture_output=True, text=True, timeout=105)
                        self.assertEqual(response.returncode, 0 if success else 1, response.stdout + response.stderr)
                        return json.loads(response.stdout)

                    self.assertIn('error', run('run', '--mode', 'latency', success=False))
                    for mode in ('both', 'download', 'upload', 'latency'):
                        result = run('run', '--mode', mode, '--private-ca', '--duration',
                                     '2' if mode == 'both' else '1',
                                     '--concurrent', '1', '--family', 'ipv4', '--source', '127.0.0.1',
                                     '--no-pre-allocate', '--http2', '--run-id', 'a' * 32)
                        self.assertIn(result['tls']['version'], ('TLS 1.2', 'TLS 1.3'))
                        self.assertTrue(result['tls']['cipher'])
                        for direction in ('download', 'upload'):
                            if mode in ('both', direction):
                                self.assertGreater(result[direction], 0)
                            else:
                                self.assertNotIn(direction, result)
                        if mode == 'both':
                            samples = run('status')['samples']
                            for direction in ('download', 'upload'):
                                self.assertTrue(samples[direction], samples)
                                self.assertTrue(any(point['mbps'] > 0 and point['seconds'] > 0
                                                    for point in samples[direction]), samples)
                    self.assertEqual(run('stat')['samples'], 1)
                    detailed = run('history')
                    self.assertEqual((detailed['successful'], detailed['failed']), (4, 1))
                    self.assertEqual(detailed['metrics']['download']['count'], 2)
                    self.assertEqual(run('status')['status'], 'completed')
                    native = [binary, '--local-json', str(servers), '--ca-cert', str(root / 'ca.pem'),
                              '--secure', '--no-icmp', '--no-download', '--no-upload']
                    stream = subprocess.run([*native, '--json-stream'], check=True, capture_output=True,
                                            text=True, timeout=30)
                    events = [json.loads(line) for line in stream.stdout.splitlines()]
                    self.assertTrue(any(event.get('event') == 'result' for event in events), events)
                    header = subprocess.run([binary, '--csv-header'], check=True,
                                            capture_output=True, text=True, timeout=30)
                    report = subprocess.run([*native, '--csv'], check=True,
                                            capture_output=True, text=True, timeout=30)
                    rows = list(csv.reader(io.StringIO(header.stdout + report.stdout)))
                    self.assertEqual(len(rows), 2)
                    self.assertEqual(len(rows[0]), len(rows[1]))
                finally:
                    server.shutdown()
                    worker.join(timeout=5)


if __name__ == '__main__':
    unittest.main()
