const gplay = require('google-play-scraper').default || require('google-play-scraper');
const fs = require('fs');
const path = require('path');

const APPS_FILE = path.join(__dirname, '../apps.json');

async function checkUpdates() {
    if (!fs.existsSync(APPS_FILE)) {
        console.error('apps.json not found!');
        process.exit(1);
    }

    const appsConfig = JSON.parse(fs.readFileSync(APPS_FILE, 'utf8'));
    const apps = appsConfig.apps;
    let updatesFound = false;

    // We will output variables for GitHub Actions
    // If multiple updates, we might only handle one per run to save resources, 
    // or handle all. For now, let's handle the first one found to keep the pipeline simple.
    
    for (const app of apps) {
        try {
            console.log(`Checking ${app.id}...`);
            const details = await gplay.app({ appId: app.id, country: 'us' });
            const latestVersion = details.version;
            
            console.log(`  Current: ${app.current_version}`);
            console.log(`  Latest:  ${latestVersion}`);

            if (latestVersion !== app.current_version) {
                console.log(`  -> Update available!`);
                
                // Write to GitHub Output
                if (process.env.GITHUB_OUTPUT) {
                    fs.appendFileSync(process.env.GITHUB_OUTPUT, `update_available=true\n`);
                    fs.appendFileSync(process.env.GITHUB_OUTPUT, `app_id=${app.id}\n`);
                    fs.appendFileSync(process.env.GITHUB_OUTPUT, `version=${latestVersion}\n`);
                }
                
                // Update the local json object (to be saved later if successful)
                // We won't save it here, we'll let the workflow update it after success
                
                updatesFound = true;
                break; // Stop after finding one update to process
            }
        } catch (e) {
            console.error(`Error checking ${app.id}:`, e.message);
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