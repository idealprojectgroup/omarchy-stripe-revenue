# Stripe Revenue for the Omarchy bar

Today's net Stripe income as a single number in the bar. Click it for the
details: today's payments as a live feed, the same day last month for
comparison, and daily totals for the recent days.

Income is **net**: direct charges, payments, and (for Connect platforms)
application fees, minus Stripe's processing fees and refunds, by calendar
day in your local timezone. Payouts, Stripe Capital repayments, and other
balance movements are excluded — the number tracks the dashboard's net
volume from sales.

## The panel

Left-clicking the bar number opens a popup with:

- **Today** — the net total, large, with the same calendar day last
  month in grey beneath it.
- **Payments** — today's income entries, newest first: time,
  description (application fees show who they came from), and amount.
- **Previous days** — net totals for the last week (configurable).
- A link to the Stripe dashboard and a last-updated stamp.

Right click refreshes immediately; middle click opens the Stripe
dashboard directly.

## Setup

1. Enable the widget:

   ```bash
   omarchy plugin enable io.github.idealprojectgroup.stripe-revenue right
   ```

2. Click the widget (it shows "Stripe: set key"). A floating terminal
   walks you through creating a **restricted** API key, verifies the key
   you paste against Stripe, and saves it to
   `~/.config/stripe-revenue/api_key` (0600).

Key permissions (everything read-only):

- **Balance: Read** — required; totals, history, and payout info.
- **Charges: Read** — recommended; payer names on direct charges.
- **Connect → Accounts: Read** — for Connect platforms; studio/business
  names on application fees.

With only Balance access the numbers all work; the payments feed just
shows less identity detail.

To set the key by hand instead:

```bash
mkdir -p ~/.config/stripe-revenue && chmod 700 ~/.config/stripe-revenue
printf '%s\n' 'rk_live_...' > ~/.config/stripe-revenue/api_key
chmod 600 ~/.config/stripe-revenue/api_key
```

The key stays in that file; the shell process only ever sees the JSON
summaries printed by `stripe-revenue-fetch`.

## Settings

Configured per bar entry in `~/.config/omarchy/shell.json`:

- `pollSeconds` (default `60`, minimum `15`) — how often to poll Stripe.
- `showCents` (default `false`) — show cents in the bar label.
- `days` (default `7`, 2–31) — days of history in the panel.

Finished days can't change, so their totals are cached in
`~/.cache/stripe-revenue/` and steady-state polling only asks Stripe
about today.

## Removal

```bash
omarchy plugin remove io.github.idealprojectgroup.stripe-revenue
```

Then delete the key and caches if you're done for good:

```bash
rm -rf ~/.config/stripe-revenue ~/.cache/stripe-revenue
```

## Dependencies

`bash`, `curl`, `jq` (all stock on Omarchy).
