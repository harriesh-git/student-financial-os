# Student Financial OS

A comprehensive multi-currency personal finance platform purpose-built for international students — specifically modeling the reality of managing money across a home country and a study-abroad destination at the same time (e.g. an Indian student living in Ireland).

Originally built in Google AI Studio, later converted into an installable Progressive Web App.

## Why I built this

Managing money as an international student isn't a generic budgeting problem. It involves multiple currencies, a home-country safety net, country-specific rules (student work-hour limits, tax credits, transit fare caps), remittance/forex timing decisions, and — critically — needing to produce clean financial documentation for visa purposes. Generic budgeting apps model none of this. This does, end to end.

## Feature set

The app is organized into 16 views, all sharing state through a global finance context:

| View | Purpose |
|---|---|
| **Home** | Dashboard overview |
| **Money** | Transaction list and management |
| **Plan** | Monthly budget planning (income, expenses, savings, category-level tracking) |
| **Trends** | Spending trend analytics |
| **Recurring** | Automatic detection of recurring expenses from transaction history |
| **Categorizer** | Rule-based auto-categorization engine |
| **Student Tools** | Country-specific student guidance (work hours, tax credits, transit) |
| **Buckets** | Goal-based money "buckets" for earmarking funds |
| **Calendar** | Upcoming bills and financial events on a timeline |
| **UPI Payments** | India-specific UPI payment tracking hub |
| **Insights** | AI/rule-generated financial insights (trends, anomalies, budget pacing, savings opportunities, FX alerts) |
| **Accounts** | Multi-account management across account types |
| **Currency** | Multi-currency overview (46 currencies supported) |
| **Forex Advisor** | Guidance on when/how to transfer money between countries |
| **Visa Statement** | Generates a financial statement formatted for visa/immigration documentation |
| **Settings** | Preferences, theme, onboarding config |

Plus three modals layered on top: receipt scanning, quick transaction entry, and transaction detail inspection.

## Core financial model

- **Safe-to-spend engine** — nets total balance against committed money (bucket allocations, upcoming bills, goal contributions) and emergency buffer to produce a daily safe-spend figure, with a GREEN/AMBER/RED status and explicit stated assumptions
- **Spending velocity / burn-rate tracking** — compares actual spend-to-date against expected pace for the month, projecting month-end spend and flagging if you're burning through budget faster than planned
- **Multi-account model** — supports distinct account types (home-country bank, Irish/local bank, Revolut, Wise, forex card, credit card, cash) each with its own currency and balance
- **Historical FX-rate tracking per transaction** — every transaction records the FX rate and converted base-currency amount *at the time it happened*, not a rate looked up later — so historical reporting stays accurate even as rates move
- **Recurring expense detection** — analyzes transaction history to surface likely recurring charges (subscriptions, rent, etc.) with a confidence score and estimated next due date, and can link them to a tracked Bill
- **Rule-based categorization engine** — user-defined keyword-matching rules auto-categorize transactions by merchant/notes, tagging each as Need / Lifestyle / Want / Goal
- **AI-powered receipt OCR** — photograph or upload a receipt; Gemini extracts merchant, date, itemized line items, quantities, prices, and suggests categories, with per-field confidence scores
- **Visa financial statement generator** — formats account and transaction data into a statement structured for immigration/visa financial documentation requirements

## Stack

- **Frontend** — React 19, TypeScript, Tailwind CSS v4 (with dark mode via custom variant), Vite 6, `lucide-react`, `motion`, `recharts` for financial visualizations
- **Backend** — Express server (TypeScript), bundled with `esbuild`
- **AI** — Google Gemini, with automatic multi-model fallback and hard timeouts
- **PWA** — installable Progressive Web App

## Notable technical decisions

- **Multi-model fallback with hard timeouts.** Every Gemini call tries a primary model first and automatically retries against a secondary model if it errors or exceeds ~4.5 seconds — important for a finance app, where a stalled request is worse than a slightly-less-capable model responding quickly.
- **Graceful degradation without an API key.** If no `GEMINI_API_KEY` is configured, both the OCR endpoint and the conversational assistant fall back to deterministic, still-genuinely-useful responses rather than erroring out — a realistic mock receipt, and keyword-matched financial guidance covering rent safety, groceries, transit, and student tax rules. The app is fully demoable with zero API cost or setup.
- **Structured OCR extraction via response schema.** The receipt parser uses Gemini's structured `responseSchema` to guarantee a strict JSON shape rather than parsing free-form text, so the frontend never has to guess at the response format.
- **Financial-assistant guardrails baked into the prompt.** The assistant is explicitly instructed to only use figures from the provided financial context, never invent numbers, and clearly separate actual spend vs. committed obligations vs. forecasts — an important trust property for anything touching real money.
- **Historical (not live) FX rates on transactions.** Recording the exchange rate at transaction time, rather than converting at report time, means past months' totals don't silently shift when currency rates move later.

## Status

🚀 Built in Google AI Studio, converted to an installable PWA — functional prototype covering a genuinely complete personal finance feature set.

## Note on demo data

The deterministic fallback responses in `server.ts` (used when no API key is configured) reference illustrative example figures and account types to demonstrate the assistant's output. These are synthetic placeholder values for demo purposes, not real financial data.

## Setup

1. Install dependencies: `npm install`
2. Set `GEMINI_API_KEY` in `.env.local` (see `.env.example`) — optional; the app runs in demo/fallback mode without it
3. Run locally: `npm run dev`
4. Production build: `npm run build && npm run start`
