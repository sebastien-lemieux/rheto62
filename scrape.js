const { chromium } = require('playwright');

// Async function to set up everything
(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  // Read lines from stdin
  const readline = require('readline');
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    terminal: false
  });

  rl.on('line', async (url) => {
    try {
      if (url.trim() === '') return;  // Skip empty lines
      await page.goto(url, { waitUntil: 'networkidle' });
      const content = await page.content();
      console.log(content);
      console.log("<<<END>>>");  // Marker to separate pages if needed
    } catch (e) {
      console.error('Error loading page:', e);
      console.log("<<<END>>>");  // Always mark end even on error
    }
  });

  rl.on('close', async () => {
    await browser.close();
    process.exit(0);
  });
})();