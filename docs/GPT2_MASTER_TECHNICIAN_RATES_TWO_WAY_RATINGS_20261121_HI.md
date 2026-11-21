# SRK ELECTRONIC — Technician 85% Rate Lists and Two-Way Rating API
Date: 21 November 2026
Branch: `feature/master-gst-accounting-20261121`
Migration: `20261121250000_master_technician_rates_and_two_way_ratings.sql`

## Technician rate lists

- `srk_technician_list_my_85_percent_rates()`: returns only categories/skills from the Technician's approved application, and only the skill level assigned by Admin. It returns the 85% share for hourly 8-hour comparison and fixed-per-unit services. The 15% platform share is not returned.
- `srk_technician_list_all_85_percent_rates()`: returns the 85% reference share for every active category, skill, service and rate level. This is informational only and does not grant permission to accept work.
- `srk_admin_set_technician_skill_level(p_application_skill_id,p_level_code)`: Main Admin assigns a level only to an approved application and approved skill, and only when an active rate exists for that skill/level. The action is appended to application events.
- Existing rate history remains immutable; Admin rate changes continue through versioned service-rate records.

## Two-way booking ratings

- Customer: `srk_customer_rate_master_technician(p_booking_id,p_technician_id,p_stars,p_review_text)`.
- Technician: `srk_technician_rate_master_customer(p_booking_id,p_stars,p_review_text)`.
- Both sides must be actual participants in a customer-approved Completed booking.
- Customer may rate each completed assigned Technician once; each Technician may rate the customer once for that booking.
- Stars must be 1–5; optional review text is limited to 1,000 characters.
- Admin: `srk_admin_moderate_master_rating(p_rating_id,'hide'|'restore',p_reason)`. A reason is mandatory and moderation events are retained.
- Rating tables have RLS enabled and no direct client table access; users submit through scoped RPCs.

## Integration and validation boundary

This migration is Feature Branch source only. No database has been modified. Node contract tests cover source/API contracts; pgTAP source is included but still requires execution against a disposable PostgreSQL database. Customer and Technician UI integration, Admin level-assignment UI, rating display/aggregate UI, and full browser E2E remain follow-up integration work.
