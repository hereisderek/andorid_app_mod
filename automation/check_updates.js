const gplay = require('google-play-scraper').default || require('google-play-scraper');
const fs = require('fs');
const path = require('path');

const APPS_FILE = path.join(__dirname, '../apps.json');

function normalizeVersion(v) {
    if (!v) return null;
    const m = String(v).match(/\d+(?:\.\d+)+/);
    return m ? m[0] : null;
}

function cmpVersions(a, b) {
    if (!a && !b) return 0;
    if (!a) return -1;
    if (!b) return 1;
    const as = a.split('.').map(n => parseInt(n, 10));
    const bs = b.split('.').map(n => parseInt(n, 10));
    const len = Math.max(as.length, bs.length);
    for (let i = 0; i < len; i++) {
        const av = as[i] || 0;
        const bv = bs[i] || 0;
        if (av > bv) return 1;
        if (av < bv) return -1;
    }
    return 0;
}

async function fetchJSON(url, token) {
    const headers = { 'Accept': 'application/vnd.github+json' };
    if (token) headers['Authorization'] = `Bearer ${token}`;
    const res = await fetch(url, { headers });
    if (!res.ok) {
        const text = await res.text();
        throw new Error(`GitHub API ${res.status}: ${text}`);
    }
    return res.json();
}

function escapeRegex(s){return s.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');}

async function getLatestProcessedVersion({ owner, repo, token, appId }) {
    // Pull first page of releases
    const releases = await fetchJSON(`https://api.github.com/repos/${owner}/${repo}/releases?per_page=50`, token);
    const tagRe = new RegExp(`^${escapeRegex(String(appId))}-v(\\d+(?:\\.\\d+)+)$`);

    let best = null;
    for (const r of releases) {
        let ver = null;
        // 1) Prefer tag pattern: <appId>-v<version>
        if (typeof r.tag_name === 'string') {
            const m = r.tag_name.match(tagRe);
            if (m) ver = m[1];
        }
        // 2) Fallback: if the appId appears in name/body, extract version
        if (!ver) {
            const fields = [r.name, r.body].filter(Boolean).join(' ');
            if (fields && fields.toLowerCase().includes(String(appId).toLowerCase())) {
                ver = normalizeVersion(fields);
            }
        }
        if (!ver) continue;
        if (!best || cmpVersions(ver, best) > 0) best = ver;
    }
    return best;
}

async function checkUpdates() {
    if (!fs.existsSync(APPS_FILE)) {
        console.error('apps.json not found!');
        process.exit(1);
    }

    const appsConfig = JSON.parse(fs.readFileSync(APPS_FILE, 'utf8'));
    const apps = appsConfig.apps || [];
    let updatesFound = false;

    const repoEnv = process.env.GITHUB_REPOSITORY || 'hereisderek/andorid_app_mod';
    const [owner, repo] = repoEnv.split('/');
    const token = process.env.GITHUB_TOKEN || process.env.GH_TOKEN || '';

    for (const app of apps) {
        try {
            const appId = app.id || app.app_id || app.package || app.packageName;
            if (!appId) {
                console.warn('Skipping entry without app id:', app);
                continue;
            }
            console.log(`Checking ${appId}...`);

            const details = await gplay.app({ appId, country: 'us' });
            const latestStoreVersion = normalizeVersion(details.version);

            const latestProcessedVersion = await getLatestProcessedVersion({ owner, repo, token, appId });

            console.log(`  Processed: ${latestProcessedVersion || '(none)'}`);
            console.log(`  Store:     ${latestStoreVersion || '(unknown)'}`);

            if (latestStoreVersion && cmpVersions(latestStoreVersion, latestProcessedVersion || '0.0.0') > 0) {
                console.log('  -> Update available!');
                if (process.env.GITHUB_OUTPUT) {
                    fs.appendFileSync(process.env.GITHUB_OUTPUT, `update_available=true\n`);
                    fs.appendFileSync(process.env.GITHUB_OUTPUT, `app_id=${appId}\n`);
                    fs.appendFileSync(process.env.GITHUB_OUTPUT, `version=${latestStoreVersion}\n`);
                }
                updatesFound = true;
                break; // handle one per run
            }
        } catch (e) {
            console.error(`Error checking ${app.id || app.app_id}:`, e.message);
        }
    }

    if (!updatesFound) {
        console.log('No updates found.');
        if (process.env.GITHUB_OUTPUT) {
            fs.appendFileSync(process.env.GITHUB_OUTPUT, `update_available=false\n`);
        }
    }
}

checkUpdates();