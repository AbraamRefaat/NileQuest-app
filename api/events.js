// Vercel Serverless Function for Tazkarti Events
const puppeteer = require('puppeteer-core');
const chromium = require('@sparticuz/chromium');

// In-memory cache (persists during function warm state)
let eventsCache = {
  data: null,
  timestamp: null,
  ttl: 30 * 60 * 1000 // 30 minutes
};

/**
 * Scrapes events from Tazkarti website
 */
async function scrapeEvents() {
  let browser;
  try {
    console.log('Launching browser...');
    
    // For Vercel deployment, use chromium
    browser = await puppeteer.launch({
      args: chromium.args,
      defaultViewport: chromium.defaultViewport,
      executablePath: await chromium.executablePath(),
      headless: chromium.headless,
    });

    const page = await browser.newPage();
    await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');

    const url = 'https://www.tazkarti.com/#/events/category/3';
    console.log(`Navigating to ${url}...`);
    
    await page.goto(url, { 
      waitUntil: 'networkidle2',
      timeout: 60000 
    });

    await page.waitForTimeout(5000);

    console.log('Extracting event data...');
    
    const events = await page.evaluate(() => {
      const eventElements = [];
      const eventCards = document.querySelectorAll('.event-card, .event-item, [class*="event"]');
      
      eventCards.forEach((card, index) => {
        try {
          const titleElement = card.querySelector('h1, h2, h3, h4, .title, [class*="title"]');
          const locationElement = card.querySelector('[class*="location"], [class*="venue"]');
          const dateElement = card.querySelector('[class*="date"]');
          const priceElement = card.querySelector('[class*="price"]');
          const linkElement = card.querySelector('a');

          const title = titleElement ? titleElement.innerText.trim() : '';
          const location = locationElement ? locationElement.innerText.trim() : '';
          const dateText = dateElement ? dateElement.innerText.trim() : '';
          const priceText = priceElement ? priceElement.innerText.trim() : '';
          const eventUrl = linkElement ? linkElement.href : '';

          let price = null;
          const priceMatch = priceText.match(/(\d+)/);
          if (priceMatch) {
            price = parseInt(priceMatch[1]);
          }

          if (title) {
            eventElements.push({
              id: `event_${index}`,
              title,
              location,
              dateText,
              price,
              priceText,
              eventUrl: eventUrl || 'https://www.tazkarti.com',
              category: 'Music'
            });
          }
        } catch (error) {
          console.error('Error parsing event card:', error);
        }
      });

      return eventElements;
    });

    console.log(`Found ${events.length} events`);
    
    const transformedEvents = events.map((event, index) => ({
      id: `tazkarti_${Date.now()}_${index}`,
      title: event.title,
      description: '',
      location: event.location || 'Cairo Opera House',
      startDate: parseEventDate(event.dateText),
      time: null,
      imageUrl: null,
      eventUrl: event.eventUrl,
      category: event.category,
      price: event.price,
      isBookmarked: false
    }));

    return transformedEvents;

  } catch (error) {
    console.error('Error during scraping:', error);
    throw error;
  } finally {
    if (browser) {
      await browser.close();
    }
  }
}

/**
 * Parse event date from text
 */
function parseEventDate(dateText) {
  try {
    const monthMap = {
      'january': 0, 'jan': 0, 'يناير': 0,
      'february': 1, 'feb': 1, 'فبراير': 1,
      'march': 2, 'mar': 2, 'مارس': 2,
      'april': 3, 'apr': 3, 'أبريل': 3,
      'may': 4, 'مايو': 4,
      'june': 5, 'jun': 5, 'يونيو': 5,
      'july': 6, 'jul': 6, 'يوليو': 6,
      'august': 7, 'aug': 7, 'أغسطس': 7,
      'september': 8, 'sep': 8, 'سبتمبر': 8,
      'october': 9, 'oct': 9, 'أكتوبر': 9,
      'november': 10, 'nov': 10, 'نوفمبر': 10,
      'december': 11, 'dec': 11, 'ديسمبر': 11
    };

    const text = (dateText || '').toLowerCase();
    const numbers = text.match(/\d+/g);
    
    if (!numbers || numbers.length < 2) {
      return new Date().toISOString();
    }

    const day = parseInt(numbers[0]);
    let month = 0;
    let year = parseInt(numbers[numbers.length - 1]);

    for (const [key, value] of Object.entries(monthMap)) {
      if (text.includes(key)) {
        month = value;
        break;
      }
    }

    const date = new Date(year, month, day);
    return date.toISOString();

  } catch (error) {
    console.error('Error parsing date:', error);
    return new Date().toISOString();
  }
}

/**
 * Vercel Serverless Function Handler
 */
module.exports = async (req, res) => {
  // Enable CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(204).end();
  }

  try {
    const now = Date.now();
    
    // Check cache
    if (eventsCache.data && eventsCache.timestamp) {
      const age = now - eventsCache.timestamp;
      if (age < eventsCache.ttl) {
        console.log('Returning cached events');
        return res.status(200).json({
          success: true,
          cached: true,
          count: eventsCache.data.length,
          events: eventsCache.data
        });
      }
    }

    console.log('Scraping fresh events...');
    const events = await scrapeEvents();
    
    // Update cache
    eventsCache.data = events;
    eventsCache.timestamp = now;
    
    return res.status(200).json({
      success: true,
      cached: false,
      count: events.length,
      events: events
    });

  } catch (error) {
    console.error('Error fetching events:', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to fetch events',
      message: error.message
    });
  }
};
