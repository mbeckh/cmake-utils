/*
MIT License, Copyright(c) 2021 Michael Beckh, see LICENSE
*/

'use strict';
const core = require('@actions/core');
const exec = require('@actions/exec');
const cache = require('@actions/cache');
const github = require('@actions/github');
const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const env = process.env;
const TEMP_PATH = '.mbeckh';
const COVERAGE_PATH = 'coverage';


// Normalize functions do not change separators, so add additional version
function forcePosix(filePath) {
  return path.posix.normalize(filePath).replace(/\\/g, '/');
}

function forceWin32(filePath) {
  return path.win32.normalize(filePath).replace(/\//, '\\');
}
const forceNative = path.sep === '/' ? forcePosix : forceWin32;

function escapeRegExp(str) {
    return str.replace(/[.*+\-?^${}()|[\]\\]/g, '\\$&');
}

async function saveCache(paths, key) {
  try {
    return await cache.saveCache(paths.map((e) => forcePosix(e)), key);
  } catch (error) {
    // failures in caching should not abort the job
    core.warning(error.message);
  }
  return null;
}

async function restoreCache(paths, key, altKeys) {
  try {
    return await cache.restoreCache(paths.map((e) => forcePosix(e)), key, altKeys);
  } catch (error) {
    // failures in caching should not abort the job
    core.warning(error.message);
  }
  return null;
}

async function setupOpenCppCoverage() {
  const toolPath = path.join(env.GITHUB_WORKSPACE, TEMP_PATH, 'OpenCppCoverage');
  
  core.startGroup('Installing OpenCppCoverage');
  // Install "by hand" because running choco on github is incredibly slow
  core.info('Getting latest release for OpenCppCoverage');

  const githubToken = core.getInput('github-token', { 'required': true });
  core.setSecret(githubToken);

  const octokit = github.getOctokit(githubToken);
  const { data: release } = await octokit.repos.getLatestRelease({ 'owner':'OpenCppCoverage', 'repo': 'OpenCppCoverage' });
  const asset = release.assets.filter((e) => /-x64-.*\.exe$/.test(e.name))[0];
  const key = `opencppcoverage-${asset.id}`;

  if (await restoreCache([ toolPath ], key)) {
    core.info(`Found ${release.name} in ${toolPath}`);
  } else {
    {
      core.info('Getting latest release for innoextract');
      const { data: release } = await octokit.repos.getLatestRelease({ 'owner':'dscharrer', 'repo': 'innoextract' });
      const asset = release.assets.filter((e) => /-windows\.zip$/.test(e.name))[0];
      core.info(`Downloading ${release.name} from ${asset.browser_download_url}`);
      
      const downloadPath = path.join(env.GITHUB_WORKSPACE, TEMP_PATH, asset.name);
      await exec.exec('curl', [ '-s', '-S', '-L', `-o${downloadPath}`, '--create-dirs', asset.browser_download_url ]);
      core.info('Unpacking innoextract');
      await exec.exec('7z', [ 'x', '-aos', `-o${path.join(env.GITHUB_WORKSPACE, TEMP_PATH)}`, downloadPath, 'innoextract.exe' ]);
    }

    core.info(`Downloading ${release.name} from ${asset.browser_download_url}`);

    const downloadPath = path.join(env.GITHUB_WORKSPACE, TEMP_PATH, asset.name);
    await exec.exec('curl', [ '-s', '-S', '-L', `-o${downloadPath}`, '--create-dirs', asset.browser_download_url ]);
    core.info('Unpacking OpenCppCoverage');
    await exec.exec(path.join(env.GITHUB_WORKSPACE, TEMP_PATH, 'innoextract'), [ '-e', '-m', '--output-dir', toolPath, downloadPath ]);

    await saveCache([ toolPath ], key);
    core.info(`Installed ${release.name} at ${toolPath}`);
  }
  core.endGroup();
  const binPath = path.resolve(toolPath, 'app');
  core.addPath(binPath);
  return path.join(binPath, 'OpenCppCoverage.exe');
}

async function setupCodacyClangTidy() {
  const toolPath = path.join(env.GITHUB_WORKSPACE, TEMP_PATH, 'codacy-clang-tidy');

  core.startGroup('Installing codacy-clang-tidy');
  core.info('Getting latest release for codacy-clang-tidy');

  const githubToken = core.getInput('github-token', { 'required': true });
  core.setSecret(githubToken);

  const octokit = github.getOctokit(githubToken);
  const { data: release } = await octokit.repos.getLatestRelease({ 'owner':'codacy', 'repo': 'codacy-clang-tidy' });
  const asset = release.assets.filter((e) => /\.jar$/.test(e.name))[0];
  const key = `codacy-clang-tidy-${asset.id}`;
  
  if (await restoreCache([ toolPath ], key)) {
    core.info(`Found codacy-clang-tidy ${release.tag_name} in cache at ${toolPath}`);
  } else {
    core.info(`Downloading codacy-clang-tidy ${release.tag_name} from ${asset.browser_download_url}`);

    await exec.exec('curl', [ '-s', '-S', '-L', `-o${path.join(toolPath, asset.name)}`, '--create-dirs', asset.browser_download_url ]);
    await saveCache([ toolPath ], key);
    core.info(`Downloaded codacy-clang-tidy ${release.tag_name} at ${toolPath}`);
  }
  core.endGroup();
  return path.join(toolPath, asset.name);
}

function getRepositoryName() {
  return env.GITHUB_REPOSITORY.substring(env.GITHUB_REPOSITORY.indexOf('/') + 1);
}

function parseCommandLine(str) {
  // This absolute beast of a regular expression parses a command line.
  // Kudos to https://stackoverflow.com/questions/13796594/how-to-split-string-into-arguments-and-options-in-javascript
  const regex = /((?:"[^"\\]*(?:\\[\S\s][^"\\]*)*"|'[^'\\]*(?:\\[\S\s][^'\\]*)*'|\/[^\/\\]*(?:\\[\S\s][^\/\\]*)*\/[gimy]*(?=\s|$)|(?:\\\s|\S))+)(?=\s|$)/g;
  return [...str.matchAll(regex)].map((e) => e[1]);
}

exports.coverage = async function() {
  try {
    await setupOpenCppCoverage();

    const command = parseCommandLine(core.getInput('command', { 'required': true }));
    const sourcePath = forceNative(core.getInput('source-dir', { 'required': true }));
    const binaryPath = forceNative(core.getInput('binary-dir', { 'required': true }));
    const codacyToken = core.getInput('codacy-token', { 'required': true });
    core.setSecret(codacyToken);

    core.startGroup('Loading codacy coverage reporter');
    const CODACY_SCRIPT = path.join(env.GITHUB_WORKSPACE, TEMP_PATH, '.codacy-coverage.sh');
    await exec.exec('curl', ['-s', '-S', '-L', `-o${CODACY_SCRIPT}`, 'https://coverage.codacy.com/get.sh' ]);
    const file = fs.readFileSync(CODACY_SCRIPT);
    const hash = crypto.createHash('sha256');
    hash.update(file);
    const hex = hash.digest('hex');
          
    const codacyCacheKey = `codacy-coverage-${hex}`;
    const codacyCoverageCacheId = await restoreCache([ path.join(env.GITHUB_WORKSPACE, TEMP_PATH, '.codacy-coverage') ], codacyCacheKey, [ 'codacy-coverage-' ]);
    if (codacyCoverageCacheId) {
      core.info('.codacy-coverage is found in cache');   
    }
    core.endGroup();
      
    const coveragePath = path.join(env.GITHUB_WORKSPACE, TEMP_PATH, COVERAGE_PATH);
    fs.mkdirSync(coveragePath, { 'recursive': true });

    const repositoryName = getRepositoryName();
    core.startGroup(`Getting code coverage for ${repositoryName}`);
      
    const coverageFile = path.join(coveragePath, `${repositoryName}.xml`);
    await exec.exec('OpenCppCoverage', [
                    `--modules=${path.join(binaryPath, path.sep)}`,
                    `--excluded_modules=${path.join(binaryPath, 'vcpkg_installed', path.sep)}`,
                    `--sources=${path.join(sourcePath, path.sep)}`,
                    `--excluded_sources=${path.join(sourcePath, 'test', path.sep)}`,
                    `--working_dir=${binaryPath}`,
                    '--cover_children',
                    `--export_type=cobertura:${coverageFile}`,
                    '--', ...command ], { 'cwd': binaryPath });
      
    // beautify file
    let data = fs.readFileSync(coverageFile, 'utf8');
    fs.writeFileSync(path.join(coveragePath, `${repositoryName}-original.xml`), data);
    const root = /(?<=<source>).+?(?=<\/source>)/.exec(data)[0];
    const workspaceWithoutRoot = env.GITHUB_WORKSPACE.substring(root.length).replace(/^[\\\/]/, ''); // remove leading (back-) slashes
    data = data.replace(/(?<=<source>).+?(?=<\/source>)/, path.join(env.GITHUB_WORKSPACE, repositoryName));
    data = data.replace(new RegExp(`(?<= name=")${escapeRegExp(path.join(binaryPath, path.sep))}`, 'g'), '');
    data = data.replace(new RegExp(`(?<= filename=")${escapeRegExp(path.join(workspaceWithoutRoot, repositoryName, path.sep))}`, 'g'), '');
    data = data.replace(/\\/g, '/');
    fs.writeFileSync(coverageFile, data);

    core.endGroup();

    core.startGroup('Sending coverage to codecov');
    await exec.exec('bash', [ '-c', `bash <(curl -sS https://codecov.io/bash) -Z -f "${forcePosix(path.relative(path.join(env.GITHUB_WORKSPACE, repositoryName), coverageFile))}"` ], { 'cwd': path.join(env.GITHUB_WORKSPACE, repositoryName) });
    core.endGroup();

    core.startGroup('Sending coverage to codacy');
    // Codacy requires language argument, else coverage is not detected
    await exec.exec('bash', [ '-c', `./${path.relative(path.join(env.GITHUB_WORKSPACE, TEMP_PATH), CODACY_SCRIPT)} report -r '${forcePosix(path.relative(path.join(env.GITHUB_WORKSPACE, TEMP_PATH), coverageFile))}' -l CPP -t ${codacyToken} --commit-uuid ${env.GITHUB_SHA}` ], { 'cwd': path.join(env.GITHUB_WORKSPACE, TEMP_PATH) });

    if (!codacyCoverageCacheId) {
      await saveCache([ path.join(env.GITHUB_WORKSPACE, TEMP_PATH, '.codacy-coverage') ], codacyCacheKey);
      core.info('Added .codacy-coverage to cache');
    }
    core.endGroup();
  } catch (error) {
    core.setFailed(error.message);
  }
};

exports.analyzeReport = async function() {
  try {
    const repositoryName = getRepositoryName();
    const workDir = path.join(env.GITHUB_WORKSPACE, repositoryName);
    const toolPath = forcePosix(path.relative(workDir, await setupCodacyClangTidy()));

    const binaryPath = forcePosix(path.relative(workDir, core.getInput('binary-dir', { 'required': true })));
    const codacyToken = core.getInput('codacy-token', { 'required': true });
    core.setSecret(codacyToken);

    core.startGroup('Sending code analysis to codacy');
    const logFile = forcePosix(path.relative(workDir, path.join(env.GITHUB_WORKSPACE, TEMP_PATH, 'clang-tidy.json')));
    await exec.exec('bash', [ '-c', `find ${binaryPath} -maxdepth 1 -name 'clang-tidy-*.log' -exec cat {} \\; | java -jar ${toolPath} | sed -r -e "s#[\\\\]{2}#/#g" > ${logFile}` ], { 'cwd': workDir });
    await exec.exec('bash', [ '-c', `curl -s -S -XPOST -L -H "project-token: ${codacyToken}" -H "Content-type: application/json" -w "\\n" -d @${logFile} "https://api.codacy.com/2.0/commit/${env.GITHUB_SHA}/issuesRemoteResults"` ], { 'cwd': workDir });
    await exec.exec('bash', [ '-c', `curl -s -S -XPOST -L -H "project-token: ${codacyToken}" -H "Content-type: application/json" -w "\\n" "https://api.codacy.com/2.0/commit/${env.GITHUB_SHA}/resultsFinal"` ], { 'cwd': workDir });
    core.endGroup();
  } catch (error) {
    core.setFailed(error.message);
  }
};
