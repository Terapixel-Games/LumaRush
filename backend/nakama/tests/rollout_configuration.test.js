const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '../../..');
const workflow = fs.readFileSync(path.join(root, '.github/workflows/cloudrun-nakama-deploy.yml'), 'utf8');
const template = fs.readFileSync(path.join(root, 'backend/nakama/cloudrun/service.template.yaml'), 'utf8');
const start = workflow.indexOf('      - name: Validate required configuration');
const finish = workflow.indexOf('      - name:', start + 10);
const section = workflow.slice(start, finish);
const script = section.slice(section.indexOf('        run: |\n') + '        run: |\n'.length).split('\n').map(line => line.replace(/^          /, '')).join('\n');
function validate(name, version) {
  const env = { PATH: process.env.PATH };
  for (const key of ['GCP_PROJECT_ID','GCP_WORKLOAD_IDENTITY_PROVIDER','GCP_SERVICE_ACCOUNT','CLOUDRUN_SERVICE','CLOUDRUN_RUNTIME_SERVICE_ACCOUNT','CLOUDSQL_INSTANCE_CONNECTION_NAME','TPX_PLATFORM_IDENTITY_NAKAMA_AUTH_URL','TPX_PLATFORM_USERNAME_VALIDATE_URL','TPX_PLATFORM_TELEMETRY_EVENTS_URL']) env[key] = 'local-metadata-fixture';
  env.CLOUDRUN_SERVICE_TEMPLATE = 'backend/nakama/cloudrun/service.template.yaml';
  env.TPX_NAKAMA_EXCHANGE_SECRET = name;
  env.TPX_NAKAMA_EXCHANGE_SECRET_VERSION = version;
  return spawnSync('bash', ['-c', script], { cwd: root, env, encoding: 'utf8' });
}
test('deployment preflight requires safe secret resource metadata and an immutable version', () => {
  assert.equal(validate('lumarush-nakama-exchange-staging', '3').status, 0);
  for (const [name,version] of [['','3'],['secret',''],['secret','latest'],['secret','0'],['secret','1.5'],['secret','1&bad'],['secret|sed','3'],['secret\nname','3'],['other/project','3']]) {
    assert.notEqual(validate(name,version).status, 0, `${JSON.stringify([name,version])} must fail before cloud auth`);
  }
});
test('rendered exchange credential uses secret reference, never a plaintext value', () => {
  const rendered = template.replaceAll('__TPX_NAKAMA_EXCHANGE_SECRET__','lumarush-nakama-exchange-staging').replaceAll('__TPX_NAKAMA_EXCHANGE_SECRET_VERSION__','3');
  const block = rendered.split('- name: TPX_NAKAMA_EXCHANGE_KEY')[1].split('- name:')[0];
  assert.match(block, /valueFrom:\s+secretKeyRef:\s+name: "lumarush-nakama-exchange-staging"\s+key: "3"/);
  assert.doesNotMatch(block, /\bvalue:/);
  assert.match(workflow, /s\|__TPX_NAKAMA_EXCHANGE_SECRET__\|\$\{TPX_NAKAMA_EXCHANGE_SECRET\}\|g/);
  assert.match(workflow, /s\|__TPX_NAKAMA_EXCHANGE_SECRET_VERSION__\|\$\{TPX_NAKAMA_EXCHANGE_SECRET_VERSION\}\|g/);
  assert.match(fs.readFileSync(path.join(root,'render.yaml'),'utf8'), /- key: TPX_NAKAMA_EXCHANGE_KEY\s+sync: false/);
});
