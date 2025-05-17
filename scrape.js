const { chromium } = require('playwright');

// Async function to set up everything
(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  console.log("<<<READY>>>");
  
  // Read lines from stdin
  const readline = require('readline');
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    terminal: false
  });

  rl.on('line', async (url) => {
    try {
        if (url.trim() === '') return;

        // console.log('Navigating to:', url);
        console.error("URL:", url)
        await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });

        // Wait for LCP event
        await page.evaluate(() => {
            return new Promise(resolve => {
                const po = new PerformanceObserver((entryList) => {
                    for (const entry of entryList.getEntries()) {
                        if (entry.entryType === "largest-contentful-paint") {
                            resolve();
                            po.disconnect();
                        }
                    }
                });
                po.observe({ type: "largest-contentful-paint", buffered: true });

                
                // Also timeout in case LCP never happens
                setTimeout(() => {
                    // console.log('Timeout waiting for LCP, continuing anyway.');
                    po.disconnect();
                    resolve();
                }, 50000); // 5 seconds max wait
            });
        });

        // console.log('LCP reached, extracting content.');
        const blocker = async route => route.abort();
        page.route("**/*", blocker);

        const content = await page.content();
        await page.goto('about:blank', { waitUntil: 'domcontentloaded', timeout: 1000 });
        page.unroute("**/*", blocker);

        await new Promise(resolve => setTimeout(resolve, 1000));
        console.log(content);
        console.log("<<<END>>>");
    } catch (e) {
        console.error('Error loading page:', e);
        console.log("<<<END>>>");
    }
  });

  rl.on('close', async () => {
    await browser.close();
    process.exit(0);
  });
})();