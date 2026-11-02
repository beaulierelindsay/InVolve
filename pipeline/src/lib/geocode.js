import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const CACHE_PATH = path.join(__dirname, "geocode-cache.json");

const cache = fs.existsSync(CACHE_PATH)
   ? JSON.parse(fs.readFileSync(CACHE_PATH, "utf8"))
   : {};

const save = () => fs.writeFileSync(CACHE_PATH, JSON.stringify(cache, null, 2));

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Returns { latitude, longitude } or null.
export default async function geocode(text) {
   if (!text || !text.trim()) return null;

   const key = text.trim().toLowerCase();

   if (key in cache) {
      return cache[key];
   }

   const url =
      "https://geosearch.planninglabs.nyc/v2/search?size=1&text=" +
      encodeURIComponent(text);

   try {
      await sleep(100);

      const res = await fetch(url);

      if (!res.ok) {
         return null;
      }

      const data = await res.json();

      const coords = data.features?.[0]?.geometry?.coordinates;

      let result = null;

      if (coords) {
         const [longitude, latitude] = coords;

         const inNyc =
            latitude > 40.4 &&
            latitude < 41.0 &&
            longitude > -74.4 &&
            longitude < -73.6;

         if (inNyc) {
            result = {
               latitude,
               longitude,
            };
         }
      }

      cache[key] = result;
      save();

      return result;
   } catch {
      return null;
   }
}
