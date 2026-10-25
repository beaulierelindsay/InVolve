const fs = require("fs");
const path = require("path");

const CACHE_PATH = path.join(__dirname, "geocode-cache.json");
const cache = fs.existsSync(CACHE_PATH)
   ? JSON.parse(fs.readFileSync(CACHE_PATH, "utf8"))
   : {};

const save = () => fs.writeFileSync(CACHE_PATH, JSON.stringify(cache, null, 2));
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Returns { latitude, longitude } or null.
async function geocode(text) {
   if (!text || !text.trim()) return null;
   const key = text.trim().toLowerCase();
   if (key in cache) return cache[key];

   const url =
      "https://geosearch.planninglabs.nyc/v2/search?size=1&text=" +
      encodeURIComponent(text);

   try {
      await sleep(100); // be polite to a free public service
      const res = await fetch(url);
      if (!res.ok) return null; // don't cache errors, retry next run

      const data = await res.json();
      const coords = data.features?.[0]?.geometry?.coordinates; // [longitude, latitude]
      let result = null;
      if (coords) {
         const [longitude, latitude] = coords;
         const inNyc =
            latitude > 40.4 &&
            latitude < 41.0 &&
            longitude > -74.4 &&
            longitude < -73.6;
         if (inNyc) result = { latitude, longitude };
      }
      cache[key] = result; // cache "not found" too
      save();
      return result;
   } catch {
      return null;
   }
}

module.exports = { geocode };
