// Approved user submissions (the app's Add tab) -> the `events` collection.
//
// Reviewers approve a submission by setting its `status` to "approved" in the
// Firebase console. Each sync copies every approved submission into `events`
// under the SAME document id, so the app's host features (RSVP button, guest
// list) can find it. Edit the submission, not the event: the next sync copies
// the submission's fields over the event again.
import { CATEGORY_IDS } from "../lib/collector.js";

// Submissions have no end time, so keep them in the feed for a while after
// they start: a few hours for timed events, the whole day for date-only ones.
const TIMED_GRACE_MS = 3 * 60 * 60 * 1000;
const DATE_ONLY_GRACE_MS = 24 * 60 * 60 * 1000;

const str = (v, max) => (typeof v === "string" ? v.trim().slice(0, max) : "");

/** Firestore Timestamp (has toDate) or Date -> Date, else null. */
function toDate(v) {
   const d = typeof v?.toDate === "function" ? v.toDate() : v;
   return d instanceof Date && !Number.isNaN(d.getTime()) ? d : null;
}

/**
 * Maps one approved submission to an `events` document.
 * @returns {{id: string, data: object} | {skip: string}}
 *   `data` never includes `rsvpCount`: the writer adds it only for new events,
 *   so syncing again never resets the number of people going.
 */
export function mapSubmission(id, s, now = new Date()) {
   if (s?.status !== "approved") return { skip: "not approved" };
   if (!CATEGORY_IDS.includes(s.categoryId)) return { skip: "bad category" };
   const title = str(s.title, 100);
   if (!title) return { skip: "missing title" };
   const startsAt = toDate(s.startsAt);
   if (!startsAt) return { skip: "missing/invalid start time" };

   const hasTime = s.hasTime !== false;
   const expiresAt = new Date(
      startsAt.getTime() + (hasTime ? TIMED_GRACE_MS : DATE_ONLY_GRACE_MS),
   );
   // Already over: skip, so cleanup can delete it and it isn't re-created.
   if (expiresAt < now) return { skip: "past event" };

   const data = {
      categoryId: s.categoryId,
      title,
      org: str(s.org, 150),
      location: str(s.location, 150),
      description: str(s.description, 1000),
      startsAt,
      endsAt: startsAt,
      expiresAt,
      hasTime,
      source: "submission",
   };
   const url = str(s.url, 300);
   if (url) data.url = url;

   // Hosted events: the submitter is the host who reads the guest list.
   if (s.submissionType === "hosted" && typeof s.submitterUid === "string") {
      data.hostUid = s.submitterUid;
      data.rsvpRequired = s.rsvpRequired === true;
      if (data.rsvpRequired) {
         if (Number.isInteger(s.capacity) && s.capacity > 0) {
            data.capacity = s.capacity;
         }
         data.rsvpQuestions = Array.isArray(s.rsvpQuestions)
            ? s.rsvpQuestions
                 .filter((q) => typeof q === "string" && q.trim())
                 .map((q) => q.trim().slice(0, 120))
                 .slice(0, 3)
            : [];
      }
   }
   return { id, data };
}
