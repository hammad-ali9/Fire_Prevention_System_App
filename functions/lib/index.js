"use strict";
/**
 * Cloud Functions — Digital Matter (Device Manager) integration.
 *
 * Replaces the blocked Telematics Guru Open API. Two responsibilities:
 *
 *   1. dmConnectorIngest (HTTPS)  — receives the JSON records that a Device
 *      Manager "HTTP Connector" POSTs whenever device 1429272 reports, and
 *      writes the latest telemetry to Firestore `devices/{serial}`. The app
 *      reads that doc live (no API keys in the app binary).
 *
 *   2. dmSetOutput (callable)     — toggles the device's digital output (the
 *      sprinkler/valve relay) by calling the Device Manager async control API
 *      with the server-held DM API key.
 *
 * Secrets (set with `firebase functions:secrets:set <NAME>`):
 *   • CONNECTOR_SHARED_SECRET — value we put in the connector's custom auth
 *     header so only Device Manager can write to the ingest endpoint.
 *   • DM_API_KEY              — Device Manager API key (Bearer) for commands.
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.dmSetOutput = exports.dmConnectorIngest = void 0;
const https_1 = require("firebase-functions/v2/https");
const https_2 = require("firebase-functions/v2/https");
const params_1 = require("firebase-functions/params");
const logger = __importStar(require("firebase-functions/logger"));
const app_1 = require("firebase-admin/app");
const firestore_1 = require("firebase-admin/firestore");
(0, app_1.initializeApp)();
const db = (0, firestore_1.getFirestore)();
const CONNECTOR_SHARED_SECRET = (0, params_1.defineSecret)("CONNECTOR_SHARED_SECRET");
const DM_API_KEY = (0, params_1.defineSecret)("DM_API_KEY");
// Device Manager (OEM Server) API base — EU region.
const DM_API_BASE = "https://api-eu.oemserver.com";
// ── Device-specific I/O wiring ─────────────────────────────────────────────
// Digital Matter packs each record's I/O into a `Fields` array, where every
// field is tagged with an `FType`:
//   FType 0 = GPS     (Lat, Long, Spd, Head, GpsUTC, Alt …)
//   FType 2 = Digital (DIn / DOut bitmasks)
//   FType 6 = Analogue (AnalogueData: { "<index>": <value>, … })
//
// The three constants below describe how THIS specific device is wired and
// cannot be read from any generic spec — they depend on the device's firmware /
// Telematics Guru I/O template. Confirm them from a real connector sample or
// the device's I/O config, then adjust:
//   • VALVE_OUTPUT_BIT       — which bit of DOut drives the valve relay
//   • FLOW_ANALOGUE_INDEX    — which AnalogueData index carries the flow sensor
//   • BATTERY_ANALOGUE_INDEX — which AnalogueData index is the battery (mV)
// Confirmed against the device's portal page (serial 1429272, Arrow-Global-
// Bluetooth, Product 128.1):
//   • Valve is a DIGITAL OUTPUT ("Valve position: Closed"); it is NOT in the
//     digital-INPUT list (Ignition, DI 1-4), so it's a DOut bit — default bit 0.
//   • Battery is reported as analogue index 1 in millivolts (portal shows
//     3.654 V).
//   • This hardware has NO flow sensor. Its only analogues are Battery, External
//     Voltage, Inside Temperature, Cellular Signal — so waterFlowRate stays null
//     unless a flow analogue is added later. FLOW_ANALOGUE_INDEX is a
//     placeholder for that future case.
const VALVE_OUTPUT_BIT = 0; //        bit 0 of DOut = the valve relay.
const FLOW_ANALOGUE_INDEX = "4"; //   no flow sensor on this device (see above).
const BATTERY_ANALOGUE_INDEX = "1"; // internal battery, in mV (portal-confirmed).
/** First field in a record's `Fields` array matching a given `FType`. */
function fieldByType(rec, ftype) {
    const fields = rec?.Fields ?? rec?.fields ?? [];
    for (const f of fields) {
        if ((f?.FType ?? f?.ftype) === ftype)
            return f;
    }
    return {};
}
/** First field in `Fields` that actually carries a given key (FType-agnostic). */
function fieldWith(rec, key) {
    const fields = rec?.Fields ?? rec?.fields ?? [];
    for (const f of fields) {
        if (f && f[key] !== undefined && f[key] !== null)
            return f;
    }
    return {};
}
/**
 * Maps ONE Digital Matter JSON record → our normalized telemetry doc.
 *
 * Field names follow DM's "JSON device integration over HTTP/HTTPS" schema
 * (SerNo / Records / Fields[].FType). Robust to flat records too: if there's
 * no Fields array we fall back to reading the keys off the record itself.
 */
function mapRecord(serial, rec, assetName) {
    // Prefer the field that actually has the key; fall back to FType, then flat.
    const gps = fieldWith(rec, "Lat").Lat !== undefined
        ? fieldWith(rec, "Lat")
        : (fieldByType(rec, 0).Lat !== undefined ? fieldByType(rec, 0) : rec);
    const digital = fieldWith(rec, "DOut").DOut !== undefined
        ? fieldWith(rec, "DOut")
        : fieldByType(rec, 2);
    const analogueField = fieldWith(rec, "AnalogueData").AnalogueData !== undefined
        ? fieldWith(rec, "AnalogueData")
        : fieldByType(rec, 6);
    const ad = analogueField.AnalogueData ?? analogueField.analogueData ?? {};
    const lat = num(gps.Lat ?? gps.lat ?? gps.latitude);
    const lng = num(gps.Long ?? gps.long ?? gps.lng ?? gps.longitude);
    // DateUTC is the record timestamp; GPS fix time is the fallback. Both UTC.
    const lastSeen = toTimestamp(rec.DateUTC ?? rec.dateUtc ?? gps.GpsUTC ?? gps.gpsUTC);
    // Battery analogues are reported in millivolts → convert to volts.
    const battMv = num(ad[BATTERY_ANALOGUE_INDEX]);
    const batteryVoltage = battMv === null ? null : battMv / 1000;
    // Valve relay = one bit of the digital-output bitmask DOut.
    const dout = num(digital.DOut ?? digital.dOut ?? digital.DigitalOut);
    const sprinklerActive = dout === null ? null : ((dout >> VALVE_OUTPUT_BIT) & 0x1) === 0x1;
    // Flow sensor = one analogue input (raw sensor units; scale as needed).
    const waterFlowRate = num(ad[FLOW_ANALOGUE_INDEX]);
    return {
        serial,
        assetName,
        lastSeen,
        latitude: lat,
        longitude: lng,
        sprinklerActive,
        waterFlowRate,
        batteryVoltage,
        raw: rec,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    };
}
function num(v) {
    if (v === null || v === undefined)
        return null;
    const n = typeof v === "number" ? v : Number(v);
    return Number.isFinite(n) ? n : null;
}
function toTimestamp(v) {
    if (v === null || v === undefined)
        return null;
    let ms = null;
    if (typeof v === "number") {
        // Epoch seconds vs milliseconds heuristic.
        ms = v < 1e12 ? v * 1000 : v;
    }
    else {
        let s = `${v}`.trim();
        // DM sends "YYYY-MM-DD HH:MM:SS" in UTC with no zone — JS would parse that
        // as LOCAL time. Normalize to explicit ISO-8601 UTC before parsing.
        const m = /^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2}:\d{2})/.exec(s);
        if (m)
            s = `${m[1]}T${m[2]}Z`;
        const parsed = Date.parse(s);
        if (!Number.isNaN(parsed))
            ms = parsed;
    }
    if (ms === null)
        return null;
    return firestore_1.Timestamp.fromMillis(ms);
}
// ── 1. Ingest: Device Manager HTTP Connector → Firestore ───────────────────
exports.dmConnectorIngest = (0, https_1.onRequest)({ secrets: [CONNECTOR_SHARED_SECRET], region: "europe-west1", cors: false }, async (req, res) => {
    if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
    }
    // Auth: the connector sends our shared secret in a custom header.
    // ⚠️ If you configure the connector with the Cryptographic Key Pair
    //    instead of a shared secret, replace this with signature verification.
    const provided = req.get("X-Connector-Secret") ??
        (req.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    if (provided !== CONNECTOR_SHARED_SECRET.value()) {
        logger.warn("dmConnectorIngest: rejected — bad shared secret");
        res.status(401).send("Unauthorized");
        return;
    }
    try {
        const body = req.body ?? {};
        // Top-level identifiers — confirm exact keys against the payload sample.
        const serial = `${body.SerNo ?? body.serNo ?? body.SN ?? body.serial ?? ""}`;
        const assetName = body.assetName ?? body.AssetName ?? null;
        const records = body.Records ?? body.records ?? [];
        if (!serial || records.length === 0) {
            logger.warn("dmConnectorIngest: no serial or empty Records", { body });
            // Still 200 so the connector doesn't retry a structurally-empty msg.
            res.status(200).send("OK (no records)");
            return;
        }
        // Newest record wins for the live doc; keep history per record.
        const sorted = [...records].sort((a, b) => recordMs(a) - recordMs(b));
        const latest = sorted[sorted.length - 1];
        const doc = mapRecord(serial, latest, assetName);
        const batch = db.batch();
        batch.set(db.collection("devices").doc(serial), doc, { merge: true });
        for (const rec of sorted) {
            const histRef = db
                .collection("devices")
                .doc(serial)
                .collection("history")
                .doc();
            batch.set(histRef, {
                ...mapRecord(serial, rec, assetName),
                ingestedAt: firestore_1.FieldValue.serverTimestamp(),
            });
        }
        await batch.commit();
        logger.info(`dmConnectorIngest: ${serial} ← ${records.length} record(s)`);
        res.status(200).send("OK");
    }
    catch (err) {
        logger.error("dmConnectorIngest: error", err);
        // 500 lets the connector retry transient failures.
        res.status(500).send("Internal Error");
    }
});
function recordMs(rec) {
    const gps = fieldWith(rec, "GpsUTC");
    const t = toTimestamp(rec.DateUTC ?? rec.dateUtc ?? gps.GpsUTC ?? gps.gpsUTC);
    return t ? t.toMillis() : 0;
}
// ── 2. Command: app → Device Manager async "set output" ────────────────────
exports.dmSetOutput = (0, https_2.onCall)({ secrets: [DM_API_KEY], region: "europe-west1" }, async (request) => {
    if (!request.auth) {
        throw new https_2.HttpsError("unauthenticated", "Sign in required.");
    }
    const serial = `${request.data?.serial ?? ""}`;
    const active = request.data?.active === true;
    if (!serial) {
        throw new https_2.HttpsError("invalid-argument", "serial is required.");
    }
    const ok = await toggleDeviceOutput(serial, active, DM_API_KEY.value());
    if (!ok) {
        throw new https_2.HttpsError("internal", "Device Manager rejected the command.");
    }
    return { serial, active, queued: true };
});
/**
 * Sends an async "set digital output" command to a device via the Device
 * Manager API.
 *
 * ⚠️ FINALIZE the endpoint path + body against the swagger
 *    (api.oemserver.com/swagger) — look for the async output/immobiliser
 *    control endpoint. Fill PRODUCT_ID for Arrow-Global-Bluetooth and confirm
 *    the output index for the valve relay.
 */
async function toggleDeviceOutput(serial, active, apiKey) {
    const PRODUCT_ID = "128"; // Arrow-Global-Bluetooth (Product 128.1) per portal.
    const OUTPUT_INDEX = 1; // Valve = the single digital output. CONFIRM via swagger.
    // Placeholder shape — replace path/body with the real async-control endpoint.
    const url = `${DM_API_BASE}/v1/TrackingDevice/SetOutput` +
        `?product=${encodeURIComponent(PRODUCT_ID)}&id=${encodeURIComponent(serial)}`;
    const resp = await fetch(url, {
        method: "POST",
        headers: {
            "Authorization": `Bearer ${apiKey}`,
            "Content-Type": "application/json",
        },
        body: JSON.stringify({ output: OUTPUT_INDEX, value: active }),
    });
    if (!resp.ok) {
        logger.error(`toggleDeviceOutput: ${serial} → HTTP ${resp.status} ${await resp.text()}`);
        return false;
    }
    return true;
}
//# sourceMappingURL=index.js.map